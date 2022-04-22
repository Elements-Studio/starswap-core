address SwapAdmin {
module TokenSwapSyrupBoost {
    use StarcoinFramework::Signer;

    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::STAR;
    use SwapAdmin::VESTAR;

    struct VestarMintCapabilityWrapper has key, store {
        cap: TokenSwapVestarMinter::MintCapability,
    }

    public fun stake<TokenT: store>(signer: &signer,
                                    pledge_time_sec: u64,
                                    amount: u128) acquires VestarMintCapabilityWrapper {
        if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            return
        };

        let cap = borrow_global<VestarMintCapabilityWrapper>(VESTAR::token_address());
        TokenSwapVestarMinter::mint_with_cap(signer,
            TokenSwapSyrup::get_global_stake_id<TokenT>(Signer::address_of(signer)),
            pledge_time_sec,
            amount,
            &cap.cap);
    }

    public fun unstake<TokenT: store>(signer: &signer, id: u64) acquires VestarMintCapabilityWrapper {
        if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            return
        };

        let cap = borrow_global<VestarMintCapabilityWrapper>(VESTAR::token_address());
        TokenSwapVestarMinter::burn_with_cap(signer, id, &cap.cap);
    }

    public fun initialize_global_syrup_info(signer: &signer, pool_release_per_second: u128) {
        STAR::assert_genesis_address(signer);

        TokenSwapSyrup::upgrade_syrup_global(signer, pool_release_per_second);

        let (
            issuer_cap,
            treasury_cap
        ) = TokenSwapVestarMinter::init(signer);

        // Set issue capability to local wrapper
        move_to(signer, VestarMintCapabilityWrapper{
            cap: issuer_cap,
        });

        // Set mint treasury capability to farm boost
        TokenSwapFarmBoost::set_treasury_cap(signer, treasury_cap);
    }

    ///TODO: Turn over capability from script to syrup boost on barnard
    public fun turnover_vestar_mintcap_for_barnard(signer: &signer, cap: TokenSwapVestarMinter::MintCapability) {
        STAR::assert_genesis_address(signer);

        move_to(signer, VestarMintCapabilityWrapper{
            cap
        });
    }
}
}
