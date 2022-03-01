//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice

//# faucet --addr SwapAdmin

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

        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(100000000);

        // Initialize pool
        TokenSwapSyrup::initialize(&signer, TokenMock::mint_token<STAR::STAR>(powed_mint_aount));

        let release_per_second_amount = CommonHelper::pow_amount<TokenMock::WETH>(100);

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

        TokenSwapConfig::put_stepwise_multiplier(&signer, 1u64, 1u64);
        TokenSwapConfig::put_stepwise_multiplier(&signer, 2u64, 1u64);
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