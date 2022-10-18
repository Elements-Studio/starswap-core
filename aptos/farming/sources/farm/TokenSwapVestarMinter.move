// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0


address SwapAdmin {

module TokenSwapVestarMinter {
    use aptos_framework::account;
    use aptos_std::event;
    
    use std::vector;
    use std::option;
    use std::signer;
    use std::error;

    use SwapAdmin::VToken;
    use SwapAdmin::Boost;
    use SwapAdmin::VESTAR;
    use SwapAdmin::WrapperUtil;

    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use SwapAdmin::STAR;

    const ERROR_TREASURY_NOT_EXISTS: u64 = 101;
    const ERROR_INSUFFICIENT_BURN_AMOUNT: u64 = 102;
    const ERROR_ADD_RECORD_ID_INVALID: u64 = 103;
    const ERROR_NOT_ADMIN: u64 = 104;
    const ERROR_FUNCTION_OBSOLETE: u64 = 105;

    struct Treasury has key, store {
        vtoken: VToken::VToken<VESTAR::VESTAR>,
    }

    struct VestarOwnerCapability has key, store {
        cap: VToken::OwnerCapability<VESTAR::VESTAR>,
    }

    /// TODO: Not satisified with multiple token type
    struct MintRecord has key, store, copy, drop {
        id: u64,
        minted_amount: u128,
        // Vestar amount
        staked_amount: u128,
        pledge_time_sec: u64,
    }

    /// TODO: Not satisified with multiple token type
    struct MintRecordList has key, store {
        items: vector<MintRecord>
    }

    struct MintRecordT<phantom StakeCoinT> has key, store, copy, drop {
        id: u64,
        minted_amount: u128,
        // Vestar amount
        staked_amount: u128,
        pledge_time_sec: u64,
    }

    struct MintRecordListT<phantom StakeCoinT> has key, store {
        items: vector<MintRecordT<StakeCoinT>>
    }

    struct MintEvent has store, drop {
        account: address,
        amount: u128,
    }

    struct BurnEvent has store, drop {
        account: address,
        amount: u128,
    }

    struct DepositEvent has store, drop {
        account: address,
        amount: u128,
    }

    struct WithdrawEvent has store, drop {
        account: address,
        amount: u128,
    }

    struct VestarEventHandler has key, store {
        mint_event_handler: event::EventHandle<MintEvent>,
        burn_event_handler: event::EventHandle<BurnEvent>,
        withdraw_event_handler: event::EventHandle<WithdrawEvent>,
        deposit_event_handler: event::EventHandle<DepositEvent>,
    }

    struct MintCapability has key, store {}

    struct TreasuryCapability has key, store {}

    /// Initialize function will called by upgrading procedure
    public fun init(signer: &signer): (MintCapability, TreasuryCapability) {
        assert!(signer::address_of(signer) == @SwapAdmin, error::invalid_state(ERROR_NOT_ADMIN));

        VToken::register_token<VESTAR::VESTAR>(signer, VESTAR::precision());
        move_to(signer, VestarOwnerCapability{
            cap: VToken::extract_cap<VESTAR::VESTAR>(signer)
        });

        move_to(signer, VestarEventHandler{
            mint_event_handler: account::new_event_handle<MintEvent>(signer),
            burn_event_handler: account::new_event_handle<BurnEvent>(signer),
            withdraw_event_handler: account::new_event_handle<WithdrawEvent>(signer),
            deposit_event_handler: account::new_event_handle<DepositEvent>(signer),
        });

        (MintCapability{}, TreasuryCapability{})
    }

    public fun mint_with_cap(_signer: &signer, _id: u64, _pledge_time_sec: u64, _staked_amount: u128, _cap: &MintCapability) {
        abort error::invalid_argument(ERROR_FUNCTION_OBSOLETE)
    }

    /// Mint Vestar with capability
    public fun mint_with_cap_T<CoinT: store>(signer: &signer, id: u64, pledge_time_sec: u64, staked_amount: u128, _cap: &MintCapability)
    acquires VestarOwnerCapability, Treasury, MintRecordListT, VestarEventHandler, MintRecordList {
        let broker = WrapperUtil::coin_address<VESTAR::VESTAR>();
        let cap = borrow_global<VestarOwnerCapability>(broker);
        let to_mint_amount = Boost::compute_mint_amount(pledge_time_sec, staked_amount);

        let vtoken = VToken::mint_with_cap<VESTAR::VESTAR>(&cap.cap, to_mint_amount);
        let event_handler = borrow_global_mut<VestarEventHandler>(broker);
        event::emit_event(&mut event_handler.mint_event_handler, MintEvent{
            account: signer::address_of(signer),
            amount: to_mint_amount
        });

        // Deposit VESTAR to treasury
        deposit(signer, vtoken);

        add_to_record<CoinT>(signer, id, pledge_time_sec, staked_amount, to_mint_amount);
    }

    public fun burn_with_cap(_signer: &signer, _id: u64, _pledge_time_sec: u64, _staked_amount: u128, _cap: &MintCapability) {
        abort error::invalid_argument(ERROR_FUNCTION_OBSOLETE)
    }

    /// Burn Vestar with capability
    public fun burn_with_cap_T<CoinT: store>(signer: &signer, id: u64, _cap: &MintCapability)
    acquires Treasury, VestarOwnerCapability, MintRecordListT, VestarEventHandler, MintRecordList {
        let user_addr = signer::address_of(signer);

        // Check user has treasury, if not then return
        if (!exists<Treasury>(user_addr)) {
            return
        };

        let broker = WrapperUtil::coin_address<VESTAR::VESTAR>();
        let cap = borrow_global<VestarOwnerCapability>(broker);
        let record = pop_from_record<CoinT>(signer, id);
        if (option::is_none(&record)) {
            // Doing nothing if this stake operation is old.
            return
        };

        let mint_record = option::destroy_some(record);
        let to_burn_amount = mint_record.minted_amount;
        let treasury_amount = value(user_addr);
        assert!(to_burn_amount <= treasury_amount, error::invalid_state(ERROR_INSUFFICIENT_BURN_AMOUNT));

        let treasury = borrow_global_mut<Treasury>(user_addr);
        VToken::burn_with_cap<VESTAR::VESTAR>(&cap.cap,
            VToken::withdraw<VESTAR::VESTAR>(&mut treasury.vtoken, to_burn_amount));

        let event_handler = borrow_global_mut<VestarEventHandler>(broker);
        event::emit_event(&mut event_handler.burn_event_handler, BurnEvent{
            account: user_addr,
            amount: to_burn_amount
        });
    }


    /// Amount of treasury
    public fun value(account: address): u128 acquires Treasury {
        if (!exists<Treasury>(account)) {
            return 0
        };
        let treasury = borrow_global_mut<Treasury>(account);
        VToken::value<VESTAR::VESTAR>(&treasury.vtoken)
    }

    /// Query amount in record by given id number
    public fun value_of_id(user_addr: address, id: u64): u128 acquires MintRecordList {
        if (!exists<MintRecordList>(user_addr)) {
            return 0
        };

        let list = borrow_global<MintRecordList>(user_addr);
        let idx = find_idx_by_id_old_list(&list.items, id);
        if (option::is_none(&idx)) {
            return 0
        };
        let record = vector::borrow(&list.items, option::destroy_some(idx));
        record.minted_amount
    }

    /// Query amount in record by given id number
    public fun value_of_id_by_token<CoinT: store>(user_addr: address, id: u64): u128 acquires MintRecordListT {
        if (!exists<MintRecordListT<CoinT>>(user_addr)) {
            return 0
        };

        let list = borrow_global<MintRecordListT<CoinT>>(user_addr);
        let idx = find_idx_by_id(&list.items, id);
        if (option::is_none(&idx)) {
            return 0
        };
        let record = vector::borrow(&list.items, option::destroy_some(idx));
        record.minted_amount
    }

    /// Withdraw from treasury
    public fun withdraw_with_cap(signer: &signer, amount: u128, _cap: &TreasuryCapability)
    : VToken::VToken<VESTAR::VESTAR> acquires Treasury, VestarEventHandler {
        withdraw(signer, amount)
    }

    /// Deposit to treasury
    public fun deposit_with_cap(signer: &signer,
                                t: VToken::VToken<VESTAR::VESTAR>,
                                _cap: &TreasuryCapability) acquires Treasury, VestarEventHandler {
        deposit(signer, t);
    }

    fun deposit(signer: &signer, t: VToken::VToken<VESTAR::VESTAR>) acquires Treasury, VestarEventHandler {
        let user_addr = signer::address_of(signer);

        let event_handler = borrow_global_mut<VestarEventHandler>(WrapperUtil::coin_address<VESTAR::VESTAR>());
        event::emit_event(&mut event_handler.deposit_event_handler, DepositEvent{
            account: user_addr,
            amount: VToken::value(&t),
        });

        if (exists<Treasury>(user_addr)) {
            let treasury = borrow_global_mut<Treasury>(user_addr);
            VToken::deposit<VESTAR::VESTAR>(&mut treasury.vtoken, t);
        } else {
            move_to(signer, Treasury{
                vtoken: t
            });
        };
    }

    fun withdraw(signer: &signer, amount: u128): VToken::VToken<VESTAR::VESTAR> acquires Treasury, VestarEventHandler {
        let user_addr = signer::address_of(signer);
        assert!(exists<Treasury>(user_addr), error::invalid_state(ERROR_TREASURY_NOT_EXISTS));

        let treasury = borrow_global_mut<Treasury>(user_addr);
        let vtoken = VToken::withdraw<VESTAR::VESTAR>(&mut treasury.vtoken, amount);

        let event_handler = borrow_global_mut<VestarEventHandler>(WrapperUtil::coin_address<VESTAR::VESTAR>());
        event::emit_event(&mut event_handler.withdraw_event_handler, WithdrawEvent{
            account: user_addr,
            amount
        });

        vtoken
    }

    /// Add vestar mint record
    fun add_to_record<CoinT: store>(signer: &signer, id: u64, pledge_time_sec: u64, staked_amount: u128, minted_amount: u128)
    acquires MintRecordListT, MintRecordList {
        let user_addr = signer::address_of(signer);

        if (!exists<MintRecordListT<CoinT>>(user_addr)) {
            move_to(signer, MintRecordListT<CoinT>{
                items: vector::empty<MintRecordT<CoinT>>()
            });
        };

        let lst = borrow_global_mut<MintRecordListT<CoinT>>(user_addr);
        maybe_upgrade_records(user_addr, &mut lst.items);

        let idx = find_idx_by_id(&lst.items, id);
        assert!(option::is_none(&idx), error::invalid_state(ERROR_ADD_RECORD_ID_INVALID));

        vector::push_back<MintRecordT<CoinT>>(&mut lst.items, MintRecordT<CoinT>{
            id,
            minted_amount,
            staked_amount,
            pledge_time_sec,
        });
    }

    /// Pop vestar mint record
    fun pop_from_record<CoinT: store>(signer: &signer, id: u64)
    : option::Option<MintRecordT<CoinT>> acquires MintRecordListT, MintRecordList {
        let user_addr = signer::address_of(signer);

        if (!exists<MintRecordListT<CoinT>>(user_addr)) {
            move_to(signer, MintRecordListT<CoinT>{
                items: vector::empty<MintRecordT<CoinT>>()
            });
        };

        let lst = borrow_global_mut<MintRecordListT<CoinT>>(user_addr);
        maybe_upgrade_records(user_addr, &mut lst.items);

        let idx = find_idx_by_id(&lst.items, id);
        if (option::is_some(&idx)) {
            option::some<MintRecordT<CoinT>>(vector::remove(&mut lst.items, option::destroy_some<u64>(idx)))
        } else {
            option::none<MintRecordT<CoinT>>()
        }
    }

    fun find_idx_by_id<CoinT: store>(c: &vector<MintRecordT<CoinT>>, id: u64): option::Option<u64> {
        let len = vector::length(c);
        if (len == 0) {
            return option::none()
        };

        let idx = len - 1;
        loop {
            let el = vector::borrow(c, idx);
            if (el.id == id) {
                return option::some(idx)
            };
            if (idx == 0) {
                return option::none()
            };
            idx = idx - 1;
        }
    }

    fun find_idx_by_id_old_list(c: &vector<MintRecord>, id: u64): option::Option<u64> {
        let len = vector::length(c);
        if (len == 0) {
            return option::none()
        };

        let idx = len - 1;
        loop {
            let el = vector::borrow(c, idx);
            if (el.id == id) {
                return option::some(idx)
            };
            if (idx == 0) {
                return option::none()
            };
            idx = idx - 1;
        }
    }

    /// Initialize handle
    public fun maybe_init_event_handler_barnard(signer: &signer) {
        assert!(signer::address_of(signer) == @SwapAdmin, error::invalid_state(ERROR_NOT_ADMIN));

        if (exists<VestarEventHandler>(signer::address_of(signer))) {
            return
        };

        move_to(signer, VestarEventHandler{
            mint_event_handler: account::new_event_handle<MintEvent>(signer),
            burn_event_handler: account::new_event_handle<BurnEvent>(signer),
            withdraw_event_handler: account::new_event_handle<WithdrawEvent>(signer),
            deposit_event_handler: account::new_event_handle<DepositEvent>(signer),
        });
    }

    /// Auto convert to new if exist old record list
    public fun maybe_upgrade_records<CoinT: store>(user_addr: address, items: &mut vector<MintRecordT<CoinT>>) acquires MintRecordList {
        if (!exists<MintRecordList>(user_addr)) {
            return
        };

        let MintRecordList{ items: old_record_list } = move_from<MintRecordList>(user_addr);
        update_record_to_recordT<CoinT>(&mut old_record_list, items);
    }

    public fun update_record_to_recordT<CoinT: store>(record_list: &mut vector<MintRecord>,
                                                       record_list_t: &mut vector<MintRecordT<CoinT>>) {
        let len = vector::length(record_list);
        if (len == 0) {
            return
        };

        loop {
            if (vector::is_empty(record_list)) {
                return
            };

            let MintRecord{
                id,
                minted_amount,
                staked_amount,
                pledge_time_sec
            } = vector::pop_back(record_list);

            vector::push_back(record_list_t, MintRecordT<CoinT>{
                id,
                minted_amount,
                staked_amount,
                pledge_time_sec
            });
        }
    }

    /// Check vestar record has exists
    public fun exists_record<CoinT: store>(user_addr: address, id: u64): bool acquires MintRecordListT {
        if (!exists<MintRecordListT<CoinT>>(user_addr)) {
            return false
        };

        let list = borrow_global<MintRecordListT<CoinT>>(user_addr);
        let idx = find_idx_by_id(&list.items, id);
        option::is_some(&idx)
    }

    #[test]
    fun test_convert_minter_record() {
        let old_record_list = vector::empty<MintRecord>();
        vector::push_back(&mut old_record_list, MintRecord{
            id: 1,
            minted_amount: 100,
            staked_amount: 100,
            pledge_time_sec: 100,
        });
        vector::push_back(&mut old_record_list, MintRecord{
            id: 2,
            minted_amount: 200,
            staked_amount: 200,
            pledge_time_sec: 200,
        });

        let old_length = vector::length(&old_record_list);
        let new_record_list_t = vector::empty<MintRecordT<VESTAR::VESTAR>>();
        update_record_to_recordT<VESTAR::VESTAR>(&mut old_record_list, &mut new_record_list_t);
        let new_length = vector::length(&new_record_list_t);
        debug::print(&new_length);
        debug::print(&old_length);
        assert!(new_length == old_length, 10001);

        let idx = find_idx_by_id(&new_record_list_t, 2);
        let r = vector::borrow(&new_record_list_t, option::destroy_some(idx));
        assert!(r.minted_amount == 200, 10002);
    }

    // #[test(a=@xxx, b=@xxx)]
    #[test(signer = @SwapAdmin)]
    fun test_add_new_record_for_compatibility(signer: signer) acquires MintRecordListT, MintRecordList {
        // Add old record
        let items = vector::empty<MintRecord>();
        vector::push_back(&mut items, MintRecord{
            id: 1,
            minted_amount: 100,
            staked_amount: 100,
            pledge_time_sec: 100,
        });
        move_to(&signer, MintRecordList{
            items,
        });

        // add new record
        add_to_record<STAR::STAR>(&signer, 2, 200, 200, 200);

        // Test repeat record id for other token type
        // TODO: create or use a new Coin to replace STC.
        // add_to_record<STC::STC>(&signer, 2, 200, 200, 200);

        let user_addr = signer::address_of(&signer);
        // query new record and old record in new record list
        assert!(value_of_id_by_token<STAR::STAR>(user_addr, 1) == 100, 10003);
        assert!(value_of_id_by_token<STAR::STAR>(user_addr, 2) == 200, 10004);
        // TODO: create or use a new Coin to replace STC.
        // assert!(value_of_id_by_token<STC::STC>(user_addr, 2) == 200, 10005);
    }

    // #[test(a=@xxx, b=@xxx)]
    #[test(signer = @SwapAdmin)]
    fun test_pop_record_for_compatibility(signer: signer) acquires MintRecordListT, MintRecordList {
        // Add old record
        let items = vector::empty<MintRecord>();
        vector::push_back(&mut items, MintRecord{
            id: 1,
            minted_amount: 100,
            staked_amount: 100,
            pledge_time_sec: 100,
        });
        vector::push_back(&mut items, MintRecord{
            id: 2,
            minted_amount: 200,
            staked_amount: 200,
            pledge_time_sec: 200,
        });
        move_to(&signer, MintRecordList{
            items,
        });

        // pop record from
        pop_from_record<STAR::STAR>(&signer, 2);

        let user_addr = signer::address_of(&signer);

        // query new record and old record in new record list
        assert!(value_of_id_by_token<STAR::STAR>(user_addr, 1) == 100, 10006);
        assert!(!exists_record<STAR::STAR>(user_addr, 2), 10007);
    }
}
}