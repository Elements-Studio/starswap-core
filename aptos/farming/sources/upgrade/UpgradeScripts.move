module SwapAdmin::UpgradeScripts {
    use aptos_framework::aptos_coin::AptosCoin as APT;

    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::STAR::STAR;

    use bridge::asset::USDT;

    const DEFAULT_MIN_TIME_LIMIT: u64 = 86400000;// one day

    const ERR_DEPRECATED: u64 = 1;
    const ERROR_INVALID_PARAMETER: u64 = 101;

    /// this will config yield farming global pool info
    public entry fun initialize_global_pool_info(signer: &signer, pool_release_per_second: u128) {
        TokenSwapConfig::assert_admin(signer);
        TokenSwapFarm::initialize_global_pool_info(signer, pool_release_per_second);
    }

    /// This will initialize syrup
    public entry fun initialize_global_syrup_info(signer: &signer, pool_release_per_second: u128) {
        TokenSwapConfig::assert_admin(signer);
        TokenSwapSyrupScript::initialize_global_syrup_info(signer, pool_release_per_second);
    }

    /// This function initializes all structures for the latest version,
    public entry fun genesis_initialize_for_latest_version(
        account: &signer,
        farm_pool_release_per_second: u128,
        syrup_pool_release_per_second: u128,
    ) {
        TokenSwapConfig::assert_admin(account);

        TokenSwapGov::genesis_initialize(account);
        TokenSwapGov::linear_initialize(account);

        TokenSwapFarmBoost::initialize_boost_event(account);
        TokenSwapFee::initialize_token_swap_fee(account);

        // Farm and syrup global
        TokenSwapFarm::initialize_global_pool_info(account, farm_pool_release_per_second);
        TokenSwapSyrupScript::initialize_global_syrup_info(account, syrup_pool_release_per_second);

        // Token swap init swap fee rate
        TokenSwapRouter::set_swap_fee_operation_rate(account, 10, 60);
    }

    public entry fun genesis_initialize_for_setup(
        account: &signer,
    ) {
        TokenSwapConfig::assert_admin(account);

        TokenSwapRouter::register_swap_pair<STAR, APT>(account);
        TokenSwapRouter::register_swap_pair<APT, USDT>(account);

        TokenSwapFarmRouter::add_farm_pool_v2<STAR, APT>(account, 30);
        TokenSwapFarmRouter::add_farm_pool_v2<APT, USDT>(account, 10);

        TokenSwapSyrup::add_pool_v2<STAR>(account, 30, 0);

        TokenSwapSyrup::put_stepwise_multiplier<STAR>(account, 604800, 1);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(account, 1209600, 2);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(account, 2592000 , 6);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(account, 5184000, 9);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(account, 7776000, 12);
    }

}