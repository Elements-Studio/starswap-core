// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0


address SwapAdmin {

module TokenSwapVestarIssuer {
    use StarcoinFramework::Token;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Signer;

    use SwapAdmin::VToken;
    use SwapAdmin::Boost;
    use SwapAdmin::VESTAR;

    const ERROR_TREASURY_NOT_EXISTS: u64 = 101;
    const ERROR_INSUFFICIENT_BURN_AMOUNT: u64 = 102;

    struct Treasury has key, store {
        vtoken: VToken::VToken<VESTAR::VESTAR>,
    }

    struct VestarOwnerCapability has key, store {
        cap: VToken::OwnerCapability<VESTAR::VESTAR>,
    }

    struct IssueCapability has key, store {}

    struct TreasuryCapability has key, store {}

    /// Initialize function will called by upgrading procedure
    public fun init(signer: &signer): (IssueCapability, TreasuryCapability) {
        VToken::register_token<VESTAR::VESTAR>(signer, VESTAR::precision());
        move_to(signer, VestarOwnerCapability{
            cap: VToken::extract_cap<VESTAR::VESTAR>(signer)
        });
        (IssueCapability{}, TreasuryCapability{})
    }

    /// Issue with token
    public fun issue_with_cap(signer: &signer, pledge_time_sec: u64, amount: u128, _cap: &IssueCapability)
    acquires VestarOwnerCapability, Treasury {
        let cap = borrow_global<VestarOwnerCapability>(Token::token_address<VESTAR::VESTAR>());
        let issue_amount = Boost::compute_issue_amount(pledge_time_sec, amount);

        // Deposit VESTAR to
        deposit(signer, VToken::mint_with_cap<VESTAR::VESTAR>(&cap.cap, issue_amount));
    }

    /// Recover Vestar token
    public fun recovery_with_cap(signer: &signer, pledge_time_sec: u64, amount: u128,  _cap: &IssueCapability)
    acquires Treasury, VestarOwnerCapability {
        let user_addr = Signer::address_of(signer);

        let cap = borrow_global<VestarOwnerCapability>(Token::token_address<VESTAR::VESTAR>());
        let to_burn_amount = Boost::compute_issue_amount(pledge_time_sec, amount);

        let treasury_amount = value(user_addr);
        assert!(to_burn_amount <= treasury_amount, Errors::invalid_state(ERROR_INSUFFICIENT_BURN_AMOUNT));

        let treasury = borrow_global_mut<Treasury>(user_addr);
        VToken::burn_with_cap<VESTAR::VESTAR>(&cap.cap,
            VToken::withdraw<VESTAR::VESTAR>(&mut treasury.vtoken, to_burn_amount));
    }

    /// Amount of treasury
    public fun value(account: address): u128 acquires Treasury {
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
}
}