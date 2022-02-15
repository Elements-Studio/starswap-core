//! account: alice, 10000000000000 0x1::STC::STC
//! account: admin, 0x2b3d5bd6d0f8a957e6a4abe986056ba7, 10000000000000 0x1::STC::STC


//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x1::PackageTxnManager::{Self};
    use 0x1::Signer;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::UpgradeScripts;

    fun update_module_upgrade_strategy_with_min_time(signer: signer) {
        let signer_address = Signer::address_of(&signer);
        UpgradeScripts::update_module_upgrade_strategy_with_min_time(signer, PackageTxnManager::get_strategy_two_phase(), 600000);
        assert(PackageTxnManager::get_strategy_two_phase() == PackageTxnManager::get_module_upgrade_strategy(signer_address), 2001);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x1::PackageTxnManager::{Self, UpgradePlanV2};
    use 0x1::ModuleUpgradeScripts;
    use 0x1::Signer;
    use 0x1::Option;
    use 0x1::Debug;

    /// can't get Struct field value outside UpgradePlanV2 and TwoPhaseUpgradeConfig
    fun submit_upgrade_plan(signer: signer) {
        let signer_address = Signer::address_of(&signer);
        let package_hash = x"25c6f65017ce187f884459971afe525838dd4b697ad4a1c7d40932ec2a8ad2f8";
        ModuleUpgradeScripts::submit_upgrade_plan(signer, package_hash, 1, true);

//        let min_time_limit = 600000;
        let plan_opt = PackageTxnManager::get_upgrade_plan_v2(signer_address);
        if (Option::is_some<UpgradePlanV2>(&plan_opt)) {
            Debug::print(&100100);
            let plan = Option::borrow(&plan_opt);
            Debug::print<UpgradePlanV2>(plan);
//            assert(plan.active_after_time <= min_time_limit, 2002);
        } else {
            assert(false, 2003);
        };
    }
}
// check: EXECUTED
