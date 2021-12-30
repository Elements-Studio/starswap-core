address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module UpgradeLibrary {
    use 0x1::PackageTxnManager;
    use 0x1::Config;
    use 0x1::Signer;
    use 0x1::Version;
    use 0x1::Option;

    const DEFAULT_MIN_TIME_LIMIT: u64 = 86400000;// one day

    ///Update `sender`'s module upgrade strategy to `strategy`
    public(script) fun update_module_upgrade_strategy(
        sender: signer,
        strategy: u8,
    ) {
        // 1. check version
        if (strategy == PackageTxnManager::get_strategy_two_phase()) {
            if (!Config::config_exist_by_address<Version::Version>(Signer::address_of(&sender))) {
                Config::publish_new_config<Version::Version>(&sender, Version::new_version(1));
            }
        };

        // 2. update strategy
        PackageTxnManager::update_module_upgrade_strategy(
            &sender,
            strategy,
            Option::none<u64>(),
        );
    }


    // Add a new script function
    public(script) fun update_module_upgrade_strategy_with_min_time(
        sender: signer,
        strategy: u8,
        min_time_limit: u64,
    ){
        // 1. check version
        if (strategy == PackageTxnManager::get_strategy_two_phase()) {
            if (!Config::config_exist_by_address<Version::Version>(Signer::address_of(&sender))) {
                Config::publish_new_config<Version::Version>(&sender, Version::new_version(1));
            }
        };

        // 2. update strategy
        PackageTxnManager::update_module_upgrade_strategy(
            &sender,
            strategy,
            Option::some<u64>(min_time_limit),
        );
    }

}
}