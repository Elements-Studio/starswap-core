module SwapAdmin::UpgradeScripts {
    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;

    const DEFAULT_MIN_TIME_LIMIT: u64 = 86400000;// one day

    const ERROR_INVALID_PARAMETER: u64 = 101;

    //two phase upgrade compatible
    public entry fun initialize_token_swap_fee(signer: &signer) {
        TokenSwapConfig::assert_admin(signer);
        TokenSwapFee::initialize_token_swap_fee(signer);
    }

    /// this will config yield farming global pool info
    public entry fun initialize_global_pool_info(signer: &signer, pool_release_per_second: u128) {
        TokenSwapConfig::assert_admin(signer);
        TokenSwapFarm::initialize_global_pool_info(signer, pool_release_per_second);
    }

    /// extend farm pool
    public entry fun extend_farm_pool<X: copy + drop + store,
                                        Y: copy + drop + store>(signer: &signer, override_update: bool) {
        TokenSwapConfig::assert_admin(signer);
        TokenSwapFarm::extend_farm_pool<X, Y>(signer, override_update);
    }

    /// This will initialize syrup
    public entry fun initialize_global_syrup_info(signer: &signer, pool_release_per_second: u128) {
        TokenSwapConfig::assert_admin(signer);
        TokenSwapSyrupScript::initialize_global_syrup_info(signer, pool_release_per_second);
    }

    /// Extend syrup pool
    public entry fun extend_syrup_pool<TokenT: copy + drop + store>(signer: &signer, override_update: bool) {
        TokenSwapConfig::assert_admin(signer);
        TokenSwapSyrup::extend_syrup_pool<TokenT>(signer, override_update);
    }
}