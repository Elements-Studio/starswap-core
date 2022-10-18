module SwapAdmin::UpgradeScripts {
    use std::error;

    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::STAR;
    use SwapAdmin::STAR::STAR;


    const DEFAULT_MIN_TIME_LIMIT: u64 = 86400000;// one day

    const ERR_DEPRECATED: u64 = 1;
    const ERROR_INVALID_PARAMETER: u64 = 101;

    /// this will config yield farming global pool info
    public entry fun initialize_global_pool_info(signer: &signer, pool_release_per_second: u128) {
        TokenSwapConfig::assert_admin(signer);
        TokenSwapFarm::initialize_global_pool_info(signer, pool_release_per_second);
    }

    /// extend farm pool
    public entry fun extend_farm_pool<X: copy + drop + store,
                                      Y: copy + drop + store>(
        _signer: &signer,
        _override_update: bool
    ) {
        // TokenSwapConfig::assert_admin(signer);
        // TokenSwapFarm::extend_farm_pool<X, Y>(signer, override_update);
        abort error::aborted(ERR_DEPRECATED)
    }

    /// This will initialize syrup
    public entry fun initialize_global_syrup_info(_signer: &signer, _pool_release_per_second: u128) {
        // TokenSwapConfig::assert_admin(signer);
        // TokenSwapSyrupScript::initialize_global_syrup_info(signer, pool_release_per_second);
        abort error::aborted(ERR_DEPRECATED)
    }

    /// Extend syrup pool
    public entry fun extend_syrup_pool<TokenT: copy + drop + store>(_signer: &signer, _override_update: bool) {
        //TokenSwapConfig::assert_admin(signer);
        //TokenSwapSyrup::extend_syrup_pool<TokenT>(signer, override_update);
        abort error::aborted(ERR_DEPRECATED)
    }

    // Must called by buyback account
    public entry fun upgrade_from_v1_0_10_to_v1_0_11(
        _buyback_account: signer,
        _deposit_amount: u128,
        _begin_time: u64,
        _interval: u64,
        _release_per_time: u128
    ) {
        abort error::aborted(ERR_DEPRECATED)
        // assert!(Signer::address_of(&buyback_account) == @BuyBackAccount, Errors::invalid_argument(ERROR_INVALID_PARAMETER));
        // BuyBackSTAR::init(buyback_account, deposit_amount, begin_time, interval, release_per_time);
    }


    public entry fun upgrade_from_v1_0_11_to_v1_0_12(account: signer) {
        TokenSwapConfig::assert_admin(&account);
        TokenSwapSyrup::upgrade_from_v1_0_11_to_v1_0_12<STAR>(&account);

        TokenSwapSyrup::update_token_pool_index<STAR::STAR>(&account);
        TokenSwapSyrup::set_pool_release_per_second(&account, 23000000);
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

    public entry fun genesis_initialize_for_latest_version_entry(
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