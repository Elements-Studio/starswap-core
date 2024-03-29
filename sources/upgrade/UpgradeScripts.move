address SwapAdmin {
module UpgradeScripts {
    use Bridge::XUSDT::XUSDT;
    use FAI::FAI::FAI;
    use WEN::WEN::WEN;

    use StarcoinFramework::Config;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Option;
    use StarcoinFramework::PackageTxnManager;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Version;

    use SwapAdmin::MultiChain::{genesis_aptos_burn, genesis_aptos_burn_community};
    use SwapAdmin::STAR;
    use SwapAdmin::STAR::STAR;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;

    const DEFAULT_MIN_TIME_LIMIT: u64 = 86400000;// one day

    const ERR_DEPRECATED: u64 = 1;
    const ERROR_INVALID_PARAMETER: u64 = 101;

    // Update `signer`'s module upgrade strategy to `strategy` with min time
    public entry fun update_module_upgrade_strategy_with_min_time(
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
    public entry fun initialize_token_swap_fee(_signer: signer) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // TokenSwapConfig::assert_admin(&signer);
        // TokenSwapFee::initialize_token_swap_fee(&signer);
    }

    /// this will config yield farming global pool info
    public entry fun initialize_global_pool_info(_signer: signer, _pool_release_per_second: u128) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // TokenSwapConfig::assert_admin(&signer);
        // TokenSwapFarm::initialize_global_pool_info(&signer, pool_release_per_second);
    }

    /// extend farm pool
    public entry fun extend_farm_pool<
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
    public entry fun initialize_global_syrup_info(_signer: signer, _pool_release_per_second: u128) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // TokenSwapConfig::assert_admin(&signer);
        // TokenSwapSyrupScript::initialize_global_syrup_info(&signer, pool_release_per_second);
    }

    /// Extend syrup pool
    public entry fun extend_syrup_pool<TokenT: copy + drop + store>(_signer: signer, _override_update: bool) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // TokenSwapConfig::assert_admin(&signer);
        // TokenSwapSyrup::extend_syrup_pool<TokenT>(&signer, override_update);
    }

    // Must called by buyback account
    public entry fun upgrade_from_v1_0_10_to_v1_0_11(
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


    public entry fun upgrade_from_v1_0_11_to_v1_0_12(account: signer) {
        TokenSwapConfig::assert_admin(&account);
        TokenSwapSyrup::upgrade_from_v1_0_11_to_v1_0_12<STAR>(&account);
        TokenSwapSyrup::set_pool_release_per_second(&account, 23000000);
        TokenSwapSyrup::update_token_pool_index<STAR::STAR>(&account);
    }

    public entry fun upgrade_from_v1_0_12_to_v2_0_0(account: signer) {
        TokenSwapConfig::assert_admin(&account);

        TokenSwapGov::linear_withdraw_farm(&account, 0);
        TokenSwapGov::linear_withdraw_syrup(&account, 0);

        TokenSwapFarm::update_token_pool_index<STC, XUSDT>(&account);
        TokenSwapFarm::update_token_pool_index<STC, WEN>(&account);
        TokenSwapFarm::update_token_pool_index<STC, STAR>(&account);
        TokenSwapFarm::update_token_pool_index<STC, FAI>(&account);


        TokenSwapFarm::set_pool_release_per_second(&account, (800000000 * 2) / 3);

        TokenSwapSyrup::update_token_pool_index<STAR::STAR>(&account);
        TokenSwapSyrup::set_pool_release_per_second(&account, (23000000 * 2) / 3);

        genesis_aptos_burn(&account);
    }

    public entry fun upgrade_from_v2_0_0_to_v2_0_1(account: signer) {
        genesis_aptos_burn_community(&account);
    }

    public entry fun upgrade_from_v2_0_1_to_v2_0_2(_account: signer) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    public entry fun upgrade_from_v2_0_2_to_v2_0_3(_account: signer) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    public entry fun set_farm_pool_release_per_second(account: signer, pool_release_per_second: u128) {
        TokenSwapFarmRouter::update_token_pool_index<STC, XUSDT>(&account);
        TokenSwapFarmRouter::update_token_pool_index<STC, WEN>(&account);
        TokenSwapFarmRouter::update_token_pool_index<STC, STAR>(&account);
        TokenSwapFarmRouter::update_token_pool_index<STC, FAI>(&account);

        TokenSwapFarm::set_pool_release_per_second(&account, pool_release_per_second);
    }

    public entry fun set_stake_pool_release_per_second(account: signer, pool_release_per_second: u128) {
        TokenSwapSyrup::update_token_pool_index<STAR::STAR>(&account);
        TokenSwapSyrup::set_pool_release_per_second(&account, pool_release_per_second);
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
}