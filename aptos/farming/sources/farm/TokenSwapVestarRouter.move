address SwapAdmin {

module TokenSwapVestarRouter {
    use std::signer;

    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapVestarMinter;

    const ERROR_ALLOC_MODEL_NOT_OPEN: u64 = 101;

    struct VestarRouterCapability has key, store {
        cap: TokenSwapVestarMinter::MintCapability,
    }

    public fun stake_hook<CoinT>(signer: &signer,
                                 pledge_time_sec: u64,
                                 amount: u128,
                                 cap: &VestarRouterCapability) {
        let id = TokenSwapSyrup::get_global_stake_id<CoinT>(signer::address_of(signer));
        TokenSwapVestarMinter::mint_with_cap_T<CoinT>(signer,
            id,
            pledge_time_sec,
            amount,
            &cap.cap);
    }

    public fun stake_hook_with_id<CoinT>(signer: &signer,
                                         id: u64,
                                         pledge_time_sec: u64,
                                         amount: u128,
                                         cap: &VestarRouterCapability) {
        TokenSwapVestarMinter::mint_with_cap_T<CoinT>(signer,
            id,
            pledge_time_sec,
            amount,
            &cap.cap);
    }

    public fun unstake_hook<CoinT>(signer: &signer, id: u64, cap: &VestarRouterCapability) {
        TokenSwapVestarMinter::burn_with_cap_T<CoinT>(signer, id, &cap.cap);
    }

    public fun exists_record<CoinT>(user_addr: address, id: u64): bool {
        TokenSwapVestarMinter::exists_record<CoinT>(user_addr, id)
    }

    public fun initialize_global_syrup_info(signer: &signer, _pool_release_per_second: u128): VestarRouterCapability {
        STAR::assert_genesis_address(signer);

        // DEPRECATED
        // TokenSwapSyrup::upgrade_syrup_global(signer, pool_release_per_second);

        let (
            issuer_cap,
            treasury_cap
        ) = TokenSwapVestarMinter::init(signer);

        // Set mint treasury capability to farm boost
        TokenSwapFarmBoost::set_treasury_cap(signer, treasury_cap);
        VestarRouterCapability {
            cap: issuer_cap,
        }
    }

    ///TODO: Turn over capability from script to syrup boost on barnard
    public fun turnover_vestar_mintcap_for_barnard(cap: TokenSwapVestarMinter::MintCapability): VestarRouterCapability {
        VestarRouterCapability {
            cap
        }
    }
}
}
