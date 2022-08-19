address SwapAdmin {
module UpgradeScripts {
    use StarcoinFramework::PackageTxnManager;
    use StarcoinFramework::Config;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Version;
    use StarcoinFramework::Option;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Errors;
    use StarcoinFramework::STC;

    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::BuyBackSTAR;
    use SwapAdmin::CommonHelper;

    const DEFAULT_MIN_TIME_LIMIT: u64 = 86400000;// one day

    const ERROR_INVALID_PARAMETER: u64 = 101;

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
        TokenSwapSyrupScript::initialize_global_syrup_info(&signer, pool_release_per_second);
    }

    /// Extend syrup pool
    public(script) fun extend_syrup_pool<TokenT: copy + drop + store>(signer: signer, override_update: bool) {
        TokenSwapConfig::assert_admin(&signer);
        TokenSwapSyrup::extend_syrup_pool<TokenT>(&signer, override_update);
    }

    // Must called by buyback account
    public(script) fun upgrade_from_v1_0_10_to_v1_11(buyback_account: signer) {
        assert!(Signer::address_of(&buyback_account) == @BuyBackAccount, Errors::invalid_argument(ERROR_INVALID_PARAMETER));

        BuyBackSTAR::init(
            buyback_account,
            CommonHelper::pow_amount<STC::STC>(942460),
            Timestamp::now_seconds(),
            300,
            128500000);
    }
}
}