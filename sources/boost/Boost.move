address SwapAdmin {

module Boost {
    use SwapAdmin::VToken;
    use SwapAdmin::VESTAR;

    struct BoostCapability has key, store {
        cap: VToken::OwnerCapability<VESTAR::VESTAR>,
    }

    /// Register boost capability for contract
    public fun register_boost(signer: &signer): BoostCapability {
        VToken::register_token<VESTAR::VESTAR>(signer, VESTAR::precision());
        BoostCapability{
            cap: VToken::extract_cap<VESTAR::VESTAR>(signer)
        }
    }

    /// Release VToken to user which specificated by LockedTokenT
    public fun release_with_cap(boost_cap: &BoostCapability,
                                locked_amount: u128,
                                locked_time_sec: u64): VToken::VToken<VESTAR::VESTAR> {
        let amount = compute_reward_amount(locked_amount, locked_time_sec);
        VToken::mint_with_cap<VESTAR::VESTAR>(&boost_cap.cap, amount)
    }

    public fun redeem_with_cap<TokenT: store>(boost_cap: &BoostCapability, token: VToken::VToken<VESTAR::VESTAR>) {
        VToken::burn_with_cap<VESTAR::VESTAR>(&boost_cap.cap, token);
    }

    /// The release amount follow the formular
    /// @param locked_time per seconds
    ///
    /// `veSTAR reward = UserLockedSTARAmount * UserLockedSTARDay / 365`
    fun compute_reward_amount(locked_amount: u128, locked_time_sec: u64): u128 {
        let locked_day = locked_time_sec / 60 * 60 * 24;
        locked_amount * (locked_day as u128) / 365u128
    }
}
}
