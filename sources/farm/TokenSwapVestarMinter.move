// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0


address SwapAdmin {

module TokenSwapVestarMinter {
    use StarcoinFramework::Token;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Option;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Event;

    use SwapAdmin::VToken;
    use SwapAdmin::Boost;
    use SwapAdmin::VESTAR;

    const ERROR_TREASURY_NOT_EXISTS: u64 = 101;
    const ERROR_INSUFFICIENT_BURN_AMOUNT: u64 = 102;
    const ERROR_ADD_RECORD_ID_INVALID: u64 = 103;
    const ERROR_NOT_ADMIN: u64 = 104;

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

    struct MintRecordT<phantom TokenT> has key, store, copy, drop {
        id: u64,
        minted_amount: u128,
        // Vestar amount
        staked_amount: u128,
        pledge_time_sec: u64,
    }

    struct MintRecordListT<phantom TokenT> has key, store {
        items: vector<MintRecordT<TokenT>>
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
        mint_event_handler: Event::EventHandle<MintEvent>,
        burn_event_handler: Event::EventHandle<BurnEvent>,
        withdraw_event_handler: Event::EventHandle<WithdrawEvent>,
        deposit_event_handler: Event::EventHandle<DepositEvent>,
    }

    struct MintCapability has key, store {}

    struct TreasuryCapability has key, store {}

    /// Initialize function will called by upgrading procedure
    public fun init(signer: &signer): (MintCapability, TreasuryCapability) {
        assert!(Signer::address_of(signer) == @SwapAdmin, Errors::invalid_state(ERROR_NOT_ADMIN));

        VToken::register_token<VESTAR::VESTAR>(signer, VESTAR::precision());
        move_to(signer, VestarOwnerCapability{
            cap: VToken::extract_cap<VESTAR::VESTAR>(signer)
        });

        move_to(signer, VestarEventHandler{
            mint_event_handler: Event::new_event_handle<MintEvent>(signer),
            burn_event_handler: Event::new_event_handle<BurnEvent>(signer),
            withdraw_event_handler: Event::new_event_handle<WithdrawEvent>(signer),
            deposit_event_handler: Event::new_event_handle<DepositEvent>(signer),
        });

        (MintCapability{}, TreasuryCapability{})
    }

    /// Mint Vestar with capability
    public fun mint_with_cap<TokenT: store>(signer: &signer, id: u64, pledge_time_sec: u64, staked_amount: u128, _cap: &MintCapability)
    acquires VestarOwnerCapability, Treasury, MintRecordListT, VestarEventHandler {
        let broker = Token::token_address<VESTAR::VESTAR>();
        let cap = borrow_global<VestarOwnerCapability>(broker);
        let to_mint_amount = Boost::compute_mint_amount(pledge_time_sec, staked_amount);

        let vtoken = VToken::mint_with_cap<VESTAR::VESTAR>(&cap.cap, to_mint_amount);
        let event_handler = borrow_global_mut<VestarEventHandler>(broker);
        Event::emit_event(&mut event_handler.mint_event_handler, MintEvent{
            account: Signer::address_of(signer),
            amount: to_mint_amount
        });

        // Deposit VESTAR to treasury
        deposit(signer, vtoken);

        add_to_record<TokenT>(signer, id, pledge_time_sec, staked_amount, to_mint_amount);
    }

    /// Burn Vestar with capability
    public fun burn_with_cap<TokenT: store>(signer: &signer, id: u64, _cap: &MintCapability)
    acquires Treasury, VestarOwnerCapability, MintRecordListT, VestarEventHandler {
        let user_addr = Signer::address_of(signer);

        // Check user has treasury, if not then return
        if (!exists<Treasury>(user_addr)) {
            return
        };

        let broker = Token::token_address<VESTAR::VESTAR>();
        let cap = borrow_global<VestarOwnerCapability>(broker);
        let record = pop_from_record<TokenT>(user_addr, id);
        if (Option::is_none(&record)) {
            // Doing nothing if this stake operation is old.
            return
        };

        let mint_record = Option::destroy_some(record);
        let to_burn_amount = mint_record.minted_amount;
        let treasury_amount = value(user_addr);
        assert!(to_burn_amount <= treasury_amount, Errors::invalid_state(ERROR_INSUFFICIENT_BURN_AMOUNT));

        let treasury = borrow_global_mut<Treasury>(user_addr);
        VToken::burn_with_cap<VESTAR::VESTAR>(&cap.cap,
            VToken::withdraw<VESTAR::VESTAR>(&mut treasury.vtoken, to_burn_amount));

        let event_handler = borrow_global_mut<VestarEventHandler>(broker);
        Event::emit_event(&mut event_handler.burn_event_handler, BurnEvent{
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
    public fun value_of_id<TokenT: store>(account: address, id: u64): u128 acquires MintRecordListT {
        if (!exists<MintRecordListT<TokenT>>(account)) {
            return 0
        };

        let list = borrow_global<MintRecordListT<TokenT>>(account);
        let idx = find_idx_by_id(&list.items, id);
        if (Option::is_none(&idx)) {
            return 0
        };
        let record = Vector::borrow(&list.items, Option::destroy_some(idx));
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
        let user_addr = Signer::address_of(signer);

        let event_handler = borrow_global_mut<VestarEventHandler>(Token::token_address<VESTAR::VESTAR>());
        Event::emit_event(&mut event_handler.deposit_event_handler, DepositEvent{
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
        let user_addr = Signer::address_of(signer);
        assert!(exists<Treasury>(user_addr), Errors::invalid_state(ERROR_TREASURY_NOT_EXISTS));

        let treasury = borrow_global_mut<Treasury>(user_addr);
        let vtoken = VToken::withdraw<VESTAR::VESTAR>(&mut treasury.vtoken, amount);

        let event_handler = borrow_global_mut<VestarEventHandler>(Token::token_address<VESTAR::VESTAR>());
        Event::emit_event(&mut event_handler.withdraw_event_handler, WithdrawEvent{
            account: user_addr,
            amount
        });

        vtoken
    }

    fun add_to_record<TokenT: store>(signer: &signer, id: u64, pledge_time_sec: u64, staked_amount: u128, minted_amount: u128)
    acquires MintRecordListT {
        let user_addr = Signer::address_of(signer);
        if (!exists<MintRecordListT<TokenT>>(user_addr)) {
            move_to(signer, MintRecordListT<TokenT>{
                items: Vector::empty<MintRecordT<TokenT>>()
            });
        };

        let lst = borrow_global_mut<MintRecordListT<TokenT>>(user_addr);
        let idx = find_idx_by_id(&lst.items, id);
        assert!(Option::is_none(&idx), Errors::invalid_state(ERROR_ADD_RECORD_ID_INVALID));

        Vector::push_back<MintRecordT<TokenT>>(&mut lst.items, MintRecordT<TokenT>{
            id,
            minted_amount,
            staked_amount,
            pledge_time_sec,
        });
    }

    fun pop_from_record<TokenT: store>(signer: &signer, id: u64)
    : Option::Option<MintRecordT<TokenT>> acquires MintRecordListT<TokenT> {
        let user_addr = Signer::address_of(signer);
        if (!exists<MintRecordListT<TokenT>>(user_addr)) {
            update_record_to_recordT<TokenT>(signer);
        };

        let lst = borrow_global_mut<MintRecordListT<TokenT>>(user_addr);
        let idx = find_idx_by_id(&lst.items, id);
        if (Option::is_some(&idx)) {
            Option::some<MintRecordT<TokenT>>(Vector::remove(&mut lst.items, Option::destroy_some<u64>(idx)))
        } else {
            Option::none<MintRecordT<TokenT>>()
        }
    }

    fun find_idx_by_id<TokenT: store>(c: &vector<MintRecordT<TokenT>>, id: u64): Option::Option<u64> {
        let len = Vector::length(c);
        if (len == 0) {
            return Option::none()
        };

        let idx = len - 1;
        loop {
            let el = Vector::borrow(c, idx);
            if (el.id == id) {
                return Option::some(idx)
            };
            if (idx == 0) {
                return Option::none()
            };
            idx = idx - 1;
        }
    }

    /// Initialize handle
    public fun maybe_init_event_handler_barnard(signer: &signer) {
        assert!(Signer::address_of(signer) == @SwapAdmin, Errors::invalid_state(ERROR_NOT_ADMIN));

        if (exists<VestarEventHandler>(Signer::address_of(signer))) {
            return
        };

        move_to(signer, VestarEventHandler{
            mint_event_handler: Event::new_event_handle<MintEvent>(signer),
            burn_event_handler: Event::new_event_handle<BurnEvent>(signer),
            withdraw_event_handler: Event::new_event_handle<WithdrawEvent>(signer),
            deposit_event_handler: Event::new_event_handle<DepositEvent>(signer),
        });
    }

    public fun maybe_update_record_to_recordT<TokenT: store>(signer: &signer,
                                                             record_list_t: &mut vector<MintRecordT<TokenT>>) acquires MintRecordList {
        let user_addr = Signer::address_of(signer);
        let MintRecordList{ items: c } = move_from<MintRecordList>(user_addr);

        let len = Vector::length(&c);
        if (len == 0) {
            return
        };

        loop {
            if (Vector::is_empty(&c)) {
                return
            };

            let MintRecord {
                id,
                minted_amount,
                staked_amount,
                pledge_time_sec
            } = Vector::pop_back(&mut c);

            Vector::push_back(record_list_t, MintRecordT<TokenT> {
                id,
                mint_amount,
                staked_amount,
                pledge_time_sec
            });
        }
    }
}
}