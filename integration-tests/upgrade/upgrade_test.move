//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000


//# run --signers SwapAdmin
script {
    use StarcoinFramework::PackageTxnManager::{Self};
    use StarcoinFramework::Signer;
    use SwapAdmin::UpgradeScripts;

    fun update_module_upgrade_strategy_with_min_time(signer: signer) {
        let signer_address = Signer::address_of(&signer);
        UpgradeScripts::update_module_upgrade_strategy_with_min_time(signer, PackageTxnManager::get_strategy_two_phase(), 600000);
        assert!(PackageTxnManager::get_strategy_two_phase() == PackageTxnManager::get_module_upgrade_strategy(signer_address), 2001);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use StarcoinFramework::PackageTxnManager::{Self, UpgradePlanV2};
    use StarcoinFramework::ModuleUpgradeScripts;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Option;
    use StarcoinFramework::Debug;

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
//            assert!(plan.active_after_time <= min_time_limit, 2002);
        } else {
            assert!(false, 2003);
        };
    }
}
// check: EXECUTED
