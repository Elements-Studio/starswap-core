address SwapAdmin {
module UpgradeScripts {
    use StarcoinFramework::PackageTxnManager;
    use StarcoinFramework::Config;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Version;
    use StarcoinFramework::Option;
    use StarcoinFramework::Errors;

    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::STAR::STAR;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::STAR;

    const DEFAULT_MIN_TIME_LIMIT: u64 = 86400000;// one day

    const ERR_DEPRECATED: u64 = 1;
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
    public(script) fun initialize_token_swap_fee(_signer: signer) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // TokenSwapConfig::assert_admin(&signer);
        // TokenSwapFee::initialize_token_swap_fee(&signer);
    }

    /// this will config yield farming global pool info
    public(script) fun initialize_global_pool_info(_signer: signer, _pool_release_per_second: u128) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // TokenSwapConfig::assert_admin(&signer);
        // TokenSwapFarm::initialize_global_pool_info(&signer, pool_release_per_second);
    }

    /// extend farm pool
    public(script) fun extend_farm_pool<
        X: copy + drop + store,
        Y: copy + drop + store
    >(
        _signer: signer,
        _override_update: bool
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // TokenSwapConfig::assert_admin(&signer);
        // TokenSwapFarm::extend_farm_pool<X, Y>(&signer, override_update);
    }

    /// This will initialize syrup
    public(script) fun initialize_global_syrup_info(_signer: signer, _pool_release_per_second: u128) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // TokenSwapConfig::assert_admin(&signer);
        // TokenSwapSyrupScript::initialize_global_syrup_info(&signer, pool_release_per_second);
    }

    /// Extend syrup pool
    public(script) fun extend_syrup_pool<TokenT: copy + drop + store>(_signer: signer, _override_update: bool) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // TokenSwapConfig::assert_admin(&signer);
        // TokenSwapSyrup::extend_syrup_pool<TokenT>(&signer, override_update);
    }

    // Must called by buyback account
    public(script) fun upgrade_from_v1_0_10_to_v1_0_11(
        _buyback_account: signer,
        _deposit_amount: u128,
        _begin_time: u64,
        _interval: u64,
        _release_per_time: u128
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // assert!(Signer::address_of(&buyback_account) == @BuyBackAccount, Errors::invalid_argument(ERROR_INVALID_PARAMETER));
        // BuyBackSTAR::init(buyback_account, deposit_amount, begin_time, interval, release_per_time);
    }


    public(script) fun upgrade_from_v1_0_11_to_v1_0_12(account: signer) {
        TokenSwapConfig::assert_admin(&account);
        TokenSwapSyrup::upgrade_from_v1_0_11_to_v1_0_12<STAR>(&account);
        TokenSwapSyrup::set_pool_release_per_second(&account, 23000000);
        TokenSwapSyrup::update_token_pool_index<STAR::STAR>(&account);
    }

    /// This function initializes all structures for the latest version,
    /// And is only used for integration tests
    public fun genesis_initialize_for_latest_version(
        account: &signer,
        farm_pool_release_per_second: u128,
        syrup_pool_release_per_second: u128,
    ) {
        TokenSwapConfig::assert_admin(account);
        TokenSwapConfig::set_alloc_mode_upgrade_switch(account, true);

        TokenSwapGov::genesis_initialize(account);
        TokenSwapGov::upgrade_dao_treasury_genesis_func(account);
        TokenSwapGov::linear_initialize(account);

        TokenSwapFarmBoost::initialize_boost_event(account);
        TokenSwapFee::initialize_token_swap_fee(account);

        // Farm and syrup global
        TokenSwapFarm::initialize_global_pool_info(account, farm_pool_release_per_second);
        TokenSwapSyrupScript::initialize_global_syrup_info(account, syrup_pool_release_per_second);

        // Token swap init swap fee rate
        TokenSwapRouter::set_swap_fee_operation_rate(account, 10, 60);
    }

    public(script) fun genesis_initialize_for_latest_version_entry(
        account: signer,
        farm_pool_release_per_second: u128,
        syrup_pool_release_per_second: u128,
    ) {
        genesis_initialize_for_latest_version(
            &account,
            farm_pool_release_per_second,
            syrup_pool_release_per_second
        );
    }
}
}