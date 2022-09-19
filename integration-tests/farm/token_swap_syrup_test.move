//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# run --signers SwapAdmin
script {
    use SwapAdmin::UpgradeScripts;

    fun UpgradeScript_genesis_initialize_for_latest_version(signer: signer) {
        UpgradeScripts::genesis_initialize_for_latest_version(
            &signer,
            100000000,
            100000000000,
        );
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenMock::{WETH};

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
    use SwapAdmin::STAR;
    use SwapAdmin::TokenMock::{WETH};
    use StarcoinFramework::Debug;

    fun admin_add_pool(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 9u8);

        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(100000000);

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool_v2<WETH>(&signer, 100, 0);

        let (total_alloc_point, pool_release_per_second) = TokenSwapSyrup::query_syrup_info();
        Debug::print(&pool_release_per_second);
        assert!(pool_release_per_second == CommonHelper::pow_amount<WETH>(100), 10010);
        assert!(total_alloc_point == 100, 10011);
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == 0, 10012);

        // Initialize asset such as WETH to alice's account
        Account::deposit<WETH>(@alice, TokenMock::mint_token<WETH>(powed_mint_aount));
        assert!(Account::balance<WETH>(@alice) == powed_mint_aount, 10013);

        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 1u64, 1u64);
        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 2u64, 1u64);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;

    fun alice_stake(signer: signer) {
        TokenSwapSyrup::stake<WETH>(&signer, 1u64, CommonHelper::pow_amount<WETH>(1000000));
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == CommonHelper::pow_amount<WETH>(1000000), 10020);

        TokenSwapSyrup::stake<WETH>(&signer, 2u64, CommonHelper::pow_amount<WETH>(1000000));
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == CommonHelper::pow_amount<WETH>(2000000), 10021);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::STAR;

    fun alice_unstake_early(signer: signer) {
        let (unstaked_token, reward_token) = TokenSwapSyrup::unstake<WETH>(&signer, 1);

        let user_addr = Signer::address_of(&signer);
        Account::deposit<WETH>(user_addr, unstaked_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);

        let except_gain = TokenSwapSyrup::query_expect_gain<WETH>(user_addr, 1);
        Debug::print(&except_gain);
    }
}
// check: "Keep(ABORTED { code: 26625"

//# block --author 0x1 --timestamp 10002000

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::STAR;
    use SwapAdmin::CommonHelper;

    fun alice_unstake_after_1_second(signer: signer) {
        let (unstaked_token, reward_token) = TokenSwapSyrup::unstake<WETH>(&signer, 1);
        let unstake_token_amount = Token::value<WETH>(&unstaked_token);
        let reward_token_amount = Token::value<STAR::STAR>(&reward_token);

        Debug::print(&unstake_token_amount);
        Debug::print(&reward_token_amount);

        assert!(unstake_token_amount == CommonHelper::pow_amount<WETH>(1000000), 10030);
        assert!(reward_token_amount == CommonHelper::pow_amount<WETH>(100), 10031);

        let user_addr = Signer::address_of(&signer);
        Account::deposit<WETH>(user_addr, unstaked_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;

    fun admin_stepwise_config(signer: signer) {
        TokenSwapConfig::put_stepwise_multiplier(&signer, 1000, 1);
        let multiplier = TokenSwapConfig::get_stepwise_multiplier(1000);
        assert!(multiplier == 1, 10040);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 2000, 2);
        multiplier = TokenSwapConfig::get_stepwise_multiplier(2000);
        assert!(multiplier == 2, 10041);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 3000, 3);
        multiplier = TokenSwapConfig::get_stepwise_multiplier(3000);
        assert!(multiplier == 3, 10042);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 1000, 5);
        multiplier = TokenSwapConfig::get_stepwise_multiplier(1000);
        assert!(multiplier == 5, 10043);

        multiplier = TokenSwapConfig::get_stepwise_multiplier(6000);
        assert!(multiplier == 1, 10044);

        multiplier = TokenSwapConfig::get_stepwise_multiplier(2000);
        assert!(multiplier == 2, 10045);

        multiplier = TokenSwapConfig::get_stepwise_multiplier(3000);
        assert!(multiplier == 3, 10046);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenMock::WETH;

    fun admin_upgrade_multiplier_pool_config(account: signer) {
        TokenSwapSyrup::upgrade_from_v1_0_11_to_v1_0_12<WETH>(&account);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenMock::WETH;

    fun admin_test_param_in_upgrade_multiplier_pool_config(account: signer) {
        assert!(TokenSwapSyrup::pledge_time_to_mulitplier<WETH>(1000) == 5, 10050);
        assert!(TokenSwapSyrup::pledge_time_to_mulitplier<WETH>(2000) == 2, 10051);
        assert!(TokenSwapSyrup::pledge_time_to_mulitplier<WETH>(3000) == 3, 10052);

        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&account, 4000, 10);
        assert!(TokenSwapSyrup::pledge_time_to_mulitplier<WETH>(4000) == 10, 10053);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;
    use StarcoinFramework::Debug;

    fun admin_test_param_in_addtion_pool_amount(account: signer) {
        let pledge_time = 1000;
        let amount = CommonHelper::pow_amount<WETH>(2000);
        TokenSwapSyrup::addtion_pool_amount<WETH>(
            &account,
            pledge_time,
            CommonHelper::pow_amount<WETH>(2000),
        );
        let (
            multiplier,
            asset_weight,
            asset_amount,
        ) = TokenSwapSyrup::query_multiplier_pool_info<WETH>(pledge_time);
        assert!(multiplier == 5, 10070);
        Debug::print(&asset_weight);
        assert!(asset_weight == amount * (multiplier as u128), 10071);
        assert!(asset_amount == amount, 10072);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;

    fun admin_test_param_in_set_release_per_second(account: signer) {
        TokenSwapSyrup::set_release_per_second<WETH>(
            &account,
            CommonHelper::pow_amount<WETH>(20)
        );
        let (_, pool_release_per_second) = TokenSwapSyrup::query_syrup_info();
        assert!(pool_release_per_second == CommonHelper::pow_amount<WETH>(20), 10060);
    }
}
// check: EXECUTED