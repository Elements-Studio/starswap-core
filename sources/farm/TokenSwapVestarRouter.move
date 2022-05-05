address SwapAdmin {

module TokenSwapVestarRouter {
    use StarcoinFramework::Signer;

    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::STAR;

    struct VestarRouterCapability has key, store {
        cap: TokenSwapVestarMinter::MintCapability,
    }

    public fun stake_hook<TokenT: store>(signer: &signer,
                                         pledge_time_sec: u64,
                                         amount: u128,
                                         cap: &VestarRouterCapability) {
        if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            return
        };

        let id = TokenSwapSyrup::get_global_stake_id<TokenT>(Signer::address_of(signer));
        TokenSwapVestarMinter::mint_with_cap<TokenT>(signer,
            id,
            pledge_time_sec,
            amount,
            &cap.cap);
    }

    public fun unstake_hook<TokenT: store>(signer: &signer, id: u64, cap: &VestarRouterCapability) {
        if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            return
        };
        TokenSwapVestarMinter::burn_with_cap<TokenT>(signer, id, &cap.cap);
    }

    public fun exists_record<TokenT: store>(user_addr: address, id: u64): bool {
        TokenSwapVestarMinter::exists_record<TokenT>(user_addr, id)
    }

    public fun initialize_global_syrup_info(signer: &signer, pool_release_per_second: u128): VestarRouterCapability {
        STAR::assert_genesis_address(signer);

        TokenSwapSyrup::upgrade_syrup_global(signer, pool_release_per_second);

        let (
            issuer_cap,
            treasury_cap
        ) = TokenSwapVestarMinter::init(signer);

        // Set mint treasury capability to farm boost
        TokenSwapFarmBoost::set_treasury_cap(signer, treasury_cap);
        VestarRouterCapability{
            cap: issuer_cap,
        }
    }

    ///TODO: Turn over capability from script to syrup boost on barnard
    public fun turnover_vestar_mintcap_for_barnard(cap: TokenSwapVestarMinter::MintCapability): VestarRouterCapability {
        VestarRouterCapability{
            cap
        }
    }
}
}
