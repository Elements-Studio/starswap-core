// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0


address SwapAdmin {

module TokenSwapVestarMinter {
    use StarcoinFramework::Token;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Option;
    use StarcoinFramework::Vector;

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

    struct MintRecord has key, store, copy, drop {
        id: u64,
        minted_amount: u128, // Vestar amoun
        staked_amount: u128,
        pledge_time_sec: u64,
    }

    struct MintRecordList has key, store {
        items: vector<MintRecord>
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
        (MintCapability{}, TreasuryCapability{})
    }

    /// Mint Vestar with capability
    public fun mint_with_cap(signer: &signer, id: u64, pledge_time_sec: u64, staked_amount: u128, _cap: &MintCapability)
    acquires VestarOwnerCapability, Treasury, MintRecordList {
        let cap = borrow_global<VestarOwnerCapability>(Token::token_address<VESTAR::VESTAR>());
        let to_mint_amount = Boost::compute_mint_amount(pledge_time_sec, staked_amount);

        // Deposit VESTAR to treasury
        deposit(signer, VToken::mint_with_cap<VESTAR::VESTAR>(&cap.cap, to_mint_amount));

        add_to_record(signer, id, pledge_time_sec, staked_amount, to_mint_amount);
    }

    /// Burn Vestar with capability
    public fun burn_with_cap(signer: &signer, id: u64, pledge_time_sec: u64, staked_amount: u128, _cap: &MintCapability)
    acquires Treasury, VestarOwnerCapability, MintRecordList {
        let user_addr = Signer::address_of(signer);

        // Check user has treasury, if not then return
        if (!exists<Treasury>(user_addr)) {
            return
        };

        let cap = borrow_global<VestarOwnerCapability>(Token::token_address<VESTAR::VESTAR>());
        let record = pop_from_record(user_addr, id);
        let to_burn_amount = if (Option::is_some(&record)) {
            let mint_record = Option::destroy_some(record);
            mint_record.minted_amount
        } else {
            Boost::compute_mint_amount(pledge_time_sec, staked_amount)
        };

        let treasury_amount = value(user_addr);
        assert!(to_burn_amount <= treasury_amount, Errors::invalid_state(ERROR_INSUFFICIENT_BURN_AMOUNT));

        let treasury = borrow_global_mut<Treasury>(user_addr);
        VToken::burn_with_cap<VESTAR::VESTAR>(&cap.cap,
            VToken::withdraw<VESTAR::VESTAR>(&mut treasury.vtoken, to_burn_amount));
    }

    /// Amount of treasury
    public fun value(account: address): u128 acquires Treasury {
        if (!exists<Treasury>(account)) {
            return 0
        };
        let treasury = borrow_global_mut<Treasury>(account);
        VToken::value<VESTAR::VESTAR>(&treasury.vtoken)
    }

    /// Withdraw from treasury
    public fun withdraw_with_cap(signer: &signer, amount: u128, _cap: &TreasuryCapability)
    : VToken::VToken<VESTAR::VESTAR> acquires Treasury {
        withdraw(signer, amount)
    }

    /// Deposit to treasury
    public fun deposit_with_cap(signer: &signer,
                                t: VToken::VToken<VESTAR::VESTAR>,
                                _cap: &TreasuryCapability) acquires Treasury {
        deposit(signer, t);
    }

    fun deposit(signer: &signer, t: VToken::VToken<VESTAR::VESTAR>) acquires Treasury {
        let account = Signer::address_of(signer);
        if (exists<Treasury>(account)) {
            let treasury = borrow_global_mut<Treasury>(account);
            VToken::deposit<VESTAR::VESTAR>(&mut treasury.vtoken, t);
        } else {
            move_to(signer, Treasury{
                vtoken: t
            });
        };
    }

    fun withdraw(signer: &signer, amount: u128): VToken::VToken<VESTAR::VESTAR> acquires Treasury {
        let account = Signer::address_of(signer);
        assert!(exists<Treasury>(account), Errors::invalid_state(ERROR_TREASURY_NOT_EXISTS));
        let account = Signer::address_of(signer);
        let treasury = borrow_global_mut<Treasury>(account);
        VToken::withdraw<VESTAR::VESTAR>(&mut treasury.vtoken, amount)
    }

    fun add_to_record(signer: &signer, id: u64, pledge_time_sec: u64, staked_amount: u128, minted_amount: u128)
    acquires MintRecordList {
        let user_addr = Signer::address_of(signer);
        if (!exists<MintRecordList>(user_addr)) {
            move_to(signer, MintRecordList{
                items: Vector::empty<MintRecord>()
            });
        };

        let lst = borrow_global_mut<MintRecordList>(user_addr);
        let idx = find_idx_by_id(&lst.items, id);
        assert!(Option::is_none(&idx), Errors::invalid_state(ERROR_ADD_RECORD_ID_INVALID));

        Vector::push_back<MintRecord>(&mut lst.items, MintRecord{
            id,
            minted_amount,
            staked_amount,
            pledge_time_sec,
        });
    }

    fun pop_from_record(user_addr: address, id: u64): Option::Option<MintRecord> acquires MintRecordList {
        let lst = borrow_global_mut<MintRecordList>(user_addr);
        let idx = find_idx_by_id(&lst.items, id);
        if (Option::is_some(&idx)) {
            Option::some<MintRecord>(Vector::remove(&mut lst.items, Option::destroy_some<u64>(idx)))
        } else {
            Option::none<MintRecord>()
        }
    }

    fun find_idx_by_id(c: &vector<MintRecord>, id: u64): Option::Option<u64> {
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
}
}