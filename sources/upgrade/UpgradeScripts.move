address SwapAdmin {
module UpgradeScripts {
    use StarcoinFramework::PackageTxnManager;
    use StarcoinFramework::Config;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Version;
    use StarcoinFramework::Option;

    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;

    const DEFAULT_MIN_TIME_LIMIT: u64 = 86400000;// one day

    // Update `signer`'s module upgrade strategy to `strategy` with min time
    public(script) fun update_module_upgrade_strategy_with_min_time(
        signer: signer,
        strategy: u8,
        min_time_limit: u64,
    ) {
        TokenSwapConfig::assert_admin(&signer);

        // 1. check version
        if (strategy == PackageTxnManager::get_strategy_two_phase()) {
            if (!Config::config_exist_by_address<Version::Version>(Signer::address_of(&signer))) {
                Config::publish_new_config<Version::Version>(&signer, Version::new_version(1));
            }
        };

        // 2. update strategy
        PackageTxnManager::update_module_upgrade_strategy(
            &signer,
            strategy,
            Option::some<u64>(min_time_limit),
        );
    }

    //two phase upgrade compatible
    public(script) fun initialize_token_swap_fee(signer: signer) {
        TokenSwapConfig::assert_admin(&signer);
        TokenSwapFee::initialize_token_swap_fee(&signer);
    }

    /// this will config yield farming global pool info
    public(script) fun initialize_global_pool_info(signer: signer, pool_release_per_second: u128) {
        TokenSwapConfig::assert_admin(&signer);
        TokenSwapFarm::initialize_global_pool_info(&signer, pool_release_per_second);
    }

    /// extend farm pool
    public(script) fun extend_farm_pool<X: copy + drop + store,
                                        Y: copy + drop + store>(signer: signer, override_update: bool) {
        TokenSwapConfig::assert_admin(&signer);
        TokenSwapFarm::extend_farm_pool<X, Y>(&signer, override_update);
    }

    /// This will initialize syrup
    public(script) fun initialize_global_syrup_info(signer: signer, pool_release_per_second: u128) {
        TokenSwapConfig::assert_admin(&signer);
        TokenSwapSyrupScript::upgrade_for_init(&signer, pool_release_per_second);
    }

    /// Extend syrup pool
    public(script) fun extend_syrup_pool<TokenT: copy + drop + store>(signer: signer,
                                                                      alloco_point: u128,
                                                                      override_update: bool) {
        TokenSwapConfig::assert_admin(&signer);
        TokenSwapSyrup::upgrade_pool_for_token_type<TokenT>(&signer, alloco_point, override_update);
    }
}
}