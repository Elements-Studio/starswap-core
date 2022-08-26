//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000


//# run --signers alice
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenMock::WETH;

    fun alice_accept_token(signer: signer) {
        Account::do_accept_token<WETH>(&signer);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;

    use SwapAdmin::TokenMock;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::STAR;

    fun admin_initialize(signer: signer) {
        TokenMock::register_token<STAR::STAR>(&signer, 9u8);
        TokenMock::register_token<TokenMock::WETH>(&signer, 9u8);
        TokenMock::register_token<TokenMock::WUSDT>(&signer, 9u8);

        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(100000000);

        // Initialize pool
        TokenSwapSyrup::initialize(&signer, TokenMock::mint_token<STAR::STAR>(powed_mint_aount));

        let release_per_second_amount = CommonHelper::pow_amount<TokenMock::WETH>(10);

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool<TokenMock::WETH>(&signer, release_per_second_amount, 0);
        TokenSwapSyrup::set_alive<TokenMock::WETH>(&signer, true);

        let release_per_second = TokenSwapSyrup::query_release_per_second<TokenMock::WETH>();
        assert!(release_per_second == release_per_second_amount, 10001);
        assert!(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == 0, 10002);

        // Initialize asset such as WETH to alice's account
        CommonHelper::safe_mint<TokenMock::WETH>(&signer, powed_mint_aount);
        Account::deposit<TokenMock::WETH>(@alice, TokenMock::mint_token<TokenMock::WETH>(powed_mint_aount));
        assert!(Account::balance<TokenMock::WETH>(@alice) == powed_mint_aount, 10003);

        // Initialize asset such as WETH to alice's account
        CommonHelper::safe_mint<TokenMock::WUSDT>(&signer, powed_mint_aount);
        Account::deposit<TokenMock::WUSDT>(@alice, TokenMock::mint_token<TokenMock::WUSDT>(powed_mint_aount));
        assert!(Account::balance<TokenMock::WUSDT>(@alice) == powed_mint_aount, 10004);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 1u64, 1u64);
        TokenSwapConfig::put_stepwise_multiplier(&signer, 2u64, 1u64);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenMock;

    fun admin_turned_on_alloc_mode_and_init_upgrade(signer: signer) {
        // open the upgrade switch
        TokenSwapConfig::set_alloc_mode_upgrade_switch(&signer, true);
        assert!(TokenSwapConfig::get_alloc_mode_upgrade_switch(), 100011);

        TokenSwapFarmBoost::initialize_boost_event(&signer);

        // upgrade for global init
        TokenSwapSyrupScript::initialize_global_syrup_info(&signer, CommonHelper::pow_amount<STAR::STAR>(10));

        // extend weth
        TokenSwapSyrup::extend_syrup_pool<TokenMock::WETH>(&signer, false);

        let (alloc_point, asset_total_amount, asset_total_weight, harvest_index) =
            TokenSwapSyrup::query_pool_info_v2<TokenMock::WETH>();

        assert!(alloc_point == 50, 100012);
        assert!(asset_total_weight == 0, 100013);
        assert!(asset_total_amount == 0, 100014);
        assert!(harvest_index == 0, 100015);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::CommonHelper;

    fun alice_stake(signer: signer) {
        TokenSwapSyrupScript::stake<TokenMock::WETH>(signer, 1, CommonHelper::pow_amount<TokenMock::WETH>(100));
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10001000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock;

    fun check_amount_after_1_second(signer: signer) {
        let except_amount = TokenSwapSyrup::query_expect_gain<TokenMock::WETH>(Signer::address_of(&signer), 1);
        Debug::print(&except_amount);
        assert!(except_amount == CommonHelper::pow_amount<STAR::STAR>(10), 100016);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10002000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrup;

    fun append_new_pool(signer: signer) {
        TokenSwapSyrup::add_pool_v2<TokenMock::WUSDT>(&signer, 50, 0);

        let (alloc_point, asset_total_amount, asset_total_weight, harvest_index) =
            TokenSwapSyrup::query_pool_info_v2<TokenMock::WUSDT>();

        assert!(alloc_point == 50, 100016);
        assert!(asset_total_weight == 0, 100017);
        assert!(asset_total_amount == 0, 100018);
        assert!(harvest_index == 0, 100019);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10004000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock;
    use SwapAdmin::STAR;

    fun check_amount_after_4_second(signer: signer) {
        let except_amount = TokenSwapSyrup::query_expect_gain<TokenMock::WETH>(Signer::address_of(&signer), 1);
        Debug::print(&except_amount);
        assert!(except_amount == CommonHelper::pow_amount<STAR::STAR>(20), 100020);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::CommonHelper;

    fun alice_stake(signer: signer) {
        TokenSwapSyrupScript::stake<TokenMock::WUSDT>(signer, 1, CommonHelper::pow_amount<TokenMock::WUSDT>(100));
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use StarcoinFramework::StdlibUpgradeScripts;

    fun upgrade_from_v11_to_v12() {
        StdlibUpgradeScripts::upgrade_from_v11_to_v12();
    }
}


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapDAO;

    fun dao_created(signer: signer) {
        TokenSwapDAO::create_dao(signer, 10, 10, 10, 10, 10);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::DAOSpace;

    use SwapAdmin::TokenSwapDAO;
    use SwapAdmin::VestarPlugin;

    fun dao_alice_check_is_member(signer: signer) {
        assert!(!DAOSpace::is_member<TokenSwapDAO::TokenSwapDao>(@alice), 10100);
        VestarPlugin::accept_sbt<TokenSwapDAO::TokenSwapDao>(&signer);
        VestarPlugin::join_member<TokenSwapDAO::TokenSwapDao>(@alice);
        assert!(DAOSpace::is_member<TokenSwapDAO::TokenSwapDao>(@alice), 10101);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::DAOSpace;

    use SwapAdmin::TokenSwapDAO;
    use SwapAdmin::VestarPlugin;
    use SwapAdmin::TokenSwapVestarMinter;
    use StarcoinFramework::Debug;

    fun dao_alice_claim_sbt_after_join_dao(signer: signer) {
        let sbt_amount_before_claim =
            DAOSpace::query_sbt<TokenSwapDAO::TokenSwapDao, VestarPlugin::VestarPlugin>(@alice);
        assert!(sbt_amount_before_claim <= 0, 10102);

        TokenSwapVestarMinter::claim_sbt(&signer);

        let sbt_amount_after_claim =
            DAOSpace::query_sbt<TokenSwapDAO::TokenSwapDao, VestarPlugin::VestarPlugin>(@alice);
        Debug::print(&sbt_amount_after_claim);
        assert!(sbt_amount_after_claim > 0, 10103);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::DAOSpace;

    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapDAO;
    use SwapAdmin::VestarPlugin;

    fun dao_alice_stake_after_claimed_sbt(signer: signer) {
        let sbt_before_stake =
            DAOSpace::query_sbt<TokenSwapDAO::TokenSwapDao, VestarPlugin::VestarPlugin>(@alice);
        assert!(sbt_before_stake > 0, 10104);

        TokenSwapSyrupScript::stake<TokenMock::WETH>(
            signer, 1, CommonHelper::pow_amount<TokenMock::WETH>(100));

        let sbt_after_stake =
            DAOSpace::query_sbt<TokenSwapDAO::TokenSwapDao, VestarPlugin::VestarPlugin>(@alice);
        assert!(sbt_after_stake > sbt_before_stake, 10105);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::DAOSpace;

    use SwapAdmin::TokenSwapDAO;
    use SwapAdmin::VestarPlugin;
    use SwapAdmin::TokenSwapVestarMinter;
    use StarcoinFramework::Debug;

    fun dao_alice_reclaim_no_change(signer: signer) {
        let sbt_amount_before_claim =
            DAOSpace::query_sbt<TokenSwapDAO::TokenSwapDao, VestarPlugin::VestarPlugin>(@alice);
        assert!(sbt_amount_before_claim > 0, 10106);

        TokenSwapVestarMinter::claim_sbt(&signer);

        let sbt_amount_after_claim =
            DAOSpace::query_sbt<TokenSwapDAO::TokenSwapDao, VestarPlugin::VestarPlugin>(@alice);
        Debug::print(&sbt_amount_after_claim);
        assert!(sbt_amount_before_claim == sbt_amount_before_claim, 10107);
    }
}
// check: EXECUTED

