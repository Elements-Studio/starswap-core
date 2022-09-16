address SwapAdmin {
module UpgradeScripts {
    use StarcoinFramework::PackageTxnManager;
    use StarcoinFramework::Config;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Version;
    use StarcoinFramework::Option;

    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapConfig;

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



}
}