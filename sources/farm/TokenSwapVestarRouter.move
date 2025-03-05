module swap_admin::TokenSwapVestarRouter {

    use std::signer;

    use swap_admin::TokenSwapSyrup;
    use swap_admin::TokenSwapFarmBoost;
    use swap_admin::TokenSwapVestarMinter;
    use swap_admin::STAR;

    const ERROR_ALLOC_MODEL_NOT_OPEN: u64 = 101;

    struct VestarRouterCapability has key, store {
        cap: TokenSwapVestarMinter::MintCapability,
    }

    public fun stake_hook<T>(
        signer: &signer,
        pledge_time_sec: u64,
        amount: u128,
        cap: &VestarRouterCapability
    ) {
        // if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
        //     return
        // };

        let id = TokenSwapSyrup::get_global_stake_id<T>(signer::address_of(signer));
        TokenSwapVestarMinter::mint_with_cap_T<T>(
            signer,
            id,
            pledge_time_sec,
            amount,
            &cap.cap
        );
    }

    public fun stake_hook_with_id<T>(
        signer: &signer,
        id: u64,
        pledge_time_sec: u64,
        amount: u128,
        cap: &VestarRouterCapability
    ) {
        TokenSwapVestarMinter::mint_with_cap_T<T>(signer,
            id,
            pledge_time_sec,
            amount,
            &cap.cap);
    }

    public fun unstake_hook<T>(signer: &signer, id: u64, cap: &VestarRouterCapability) {
        TokenSwapVestarMinter::burn_with_cap_T<T>(signer, id, &cap.cap);
    }

    public fun exists_record<T>(user_addr: address, id: u64): bool {
        TokenSwapVestarMinter::exists_record<T>(user_addr, id)
    }

    public fun initialize_global_syrup_info(signer: &signer, _pool_release_per_second: u128): VestarRouterCapability {
        STAR::assert_genesis_address(signer);


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
}
