// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0


address SwapAdmin {

module TokenSwapSyrupBoost {
    use StarcoinFramework::Token;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Signer;

    use SwapAdmin::VToken;
    use SwapAdmin::Boost;
    use SwapAdmin::VESTAR;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapSyrup;

    const ERROR_TREASURY_NOT_EXISTS: u64 = 101;

    struct BoostCapabilityWrapper has key, store {
        cap: Boost::BoostCapability,
    }

    struct BoostTokenTreasury has key, store {
        vtoken: VToken::VToken<VESTAR::VESTAR>,
    }

    /// Initialize function will called by upgrading procedure
    public fun init(signer: &signer) {
        let cap = Boost::register_boost(signer);
        move_to(signer, BoostCapabilityWrapper{
            cap
        });
    }

    /// Stake with boost token
    public fun stake_with_boost_token<TokenT: store>(signer: &signer, pledge_time_sec: u64, amount: u128)
    acquires BoostCapabilityWrapper, BoostTokenTreasury {
        // Release VESTAR
        let cap = borrow_global<BoostCapabilityWrapper>(Token::token_address<VESTAR::VESTAR>());
        let vtoken = Boost::release_with_cap(&cap.cap, amount, pledge_time_sec);

        // Deposit VESTAR to
        deposit(signer, vtoken);

        TokenSwapSyrup::stake<TokenT>(signer, pledge_time_sec, amount);
    }

    /// Unstake with boost token
    public fun unstake_with_boost_token<TokenT: store>(signer: &signer, id: u64): (
        Token::Token<TokenT>,
        Token::Token<STAR::STAR>
    ) acquires BoostTokenTreasury, BoostCapabilityWrapper {
        // Check the amount of recalled tokens
        let (start_time, end_time, _, token_amount) =
            TokenSwapSyrup::get_stake_info<TokenT>(Signer::address_of(signer), id);

        // Redeem from treasury
        let cap = borrow_global<BoostCapabilityWrapper>(Token::token_address<VESTAR::VESTAR>());
        let vestar_amount = compute_vestar_amount_from_info(token_amount, end_time - start_time);
        Boost::redeem_with_cap<TokenT>(&cap.cap, withdraw(signer, vestar_amount));

        // Do unstake
        TokenSwapSyrup::unstake<TokenT>(signer, id)
    }

    fun compute_vestar_amount_from_info(amount: u128, _time: u64): u128 {
        // TODO(ElementX): Compute boost token amount from staking amount and time
        amount
    }

    // Withdraw from treasury
    public fun withdraw(signer: &signer, amount: u128): VToken::VToken<VESTAR::VESTAR> acquires BoostTokenTreasury {
        let account = Signer::address_of(signer);
        assert!(exists<BoostTokenTreasury>(account), Errors::invalid_state(ERROR_TREASURY_NOT_EXISTS));
        let account = Signer::address_of(signer);
        let treasury = borrow_global_mut<BoostTokenTreasury>(account);
        VToken::withdraw<VESTAR::VESTAR>(&mut treasury.vtoken, amount)
    }

    /// Deposit to treasury
    public fun deposit(signer: &signer, t: VToken::VToken<VESTAR::VESTAR>) acquires BoostTokenTreasury {
        let account = Signer::address_of(signer);
        if (exists<BoostTokenTreasury>(account)) {
            let treasury = borrow_global_mut<BoostTokenTreasury>(account);
            VToken::deposit<VESTAR::VESTAR>(&mut treasury.vtoken, t);
        } else {
            move_to(signer, BoostTokenTreasury{
                vtoken: t
            });
        };
    }
}

}