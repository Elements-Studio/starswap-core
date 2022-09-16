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
    use SwapAdmin::STAR;
    use SwapAdmin::TokenMock::WETH;
    use StarcoinFramework::Debug;

    fun admin_add_pool(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 9u8);

        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(100000000);

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool_v2<WETH>(&signer, 100, 0);

        let (total_alloc_point, pool_release_per_second) = TokenSwapSyrup::query_syrup_info();
        Debug::print(&pool_release_per_second);
        assert!(pool_release_per_second == CommonHelper::pow_amount<WETH>(100), 10001);
        assert!(total_alloc_point == 100, 10002);
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == 0, 10003);

        // Initialize asset such as WETH to alice's account
        Account::deposit<WETH>(@alice, TokenMock::mint_token<WETH>(powed_mint_aount));
        assert!(Account::balance<WETH>(@alice) == powed_mint_aount, 10003);

        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 1u64, 1u64);
        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 2u64, 1u64);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;

    fun alice_stake(signer: signer) {
        TokenSwapSyrup::stake<TokenMock::WETH>(&signer, 1u64, CommonHelper::pow_amount<TokenMock::WETH>(1000000));
        assert!(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == CommonHelper::pow_amount<TokenMock::WETH>(1000000), 10004);

        TokenSwapSyrup::stake<TokenMock::WETH>(&signer, 2u64, CommonHelper::pow_amount<TokenMock::WETH>(1000000));
        assert!(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == CommonHelper::pow_amount<TokenMock::WETH>(2000000), 10005);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::STAR;

    fun alice_unstake_early(signer: signer) {
        let (unstaked_token, reward_token) = TokenSwapSyrup::unstake<TokenMock::WETH>(&signer, 1);

        let user_addr = Signer::address_of(&signer);
        Account::deposit<TokenMock::WETH>(user_addr, unstaked_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);

        let except_gain = TokenSwapSyrup::query_expect_gain<TokenMock::WETH>(user_addr, 1);
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

    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::STAR;
    use SwapAdmin::CommonHelper;

    fun alice_unstake_after_1_second(signer: signer) {
        let (unstaked_token, reward_token) = TokenSwapSyrup::unstake<TokenMock::WETH>(&signer, 1);
        let unstake_token_amount = Token::value<TokenMock::WETH>(&unstaked_token);
        let reward_token_amount = Token::value<STAR::STAR>(&reward_token);

        Debug::print(&unstake_token_amount);
        Debug::print(&reward_token_amount);

        assert!(unstake_token_amount == CommonHelper::pow_amount<TokenMock::WETH>(1000000), 10006);
        assert!(reward_token_amount == CommonHelper::pow_amount<TokenMock::WETH>(100), 10007);

        let user_addr = Signer::address_of(&signer);
        Account::deposit<TokenMock::WETH>(user_addr, unstaked_token);
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
        assert!(multiplier == 1, 10008);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 2000, 2);
        multiplier = TokenSwapConfig::get_stepwise_multiplier(2000);
        assert!(multiplier == 2, 10009);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 3000, 3);
        multiplier = TokenSwapConfig::get_stepwise_multiplier(3000);
        assert!(multiplier == 3, 10010);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 1000, 5);
        multiplier = TokenSwapConfig::get_stepwise_multiplier(1000);
        assert!(multiplier == 5, 10011);

        multiplier = TokenSwapConfig::get_stepwise_multiplier(6000);
        assert!(multiplier == 1, 10012);

        multiplier = TokenSwapConfig::get_stepwise_multiplier(2000);
        assert!(multiplier == 2, 10013);

        multiplier = TokenSwapConfig::get_stepwise_multiplier(3000);
        assert!(multiplier == 3, 10014);
    }
}
// check: EXECUTED