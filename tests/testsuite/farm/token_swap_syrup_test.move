//! account: admin, 0x2b3d5bd6d0f8a957e6a4abe986056ba7, 10000000000000 0x1::STC::STC
//! account: alice, 0x49156896A605F092ba1862C50a9036c9, 10000000000000 0x1::STC::STC

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 86400000

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::WETH;

    fun alice_accept_token(signer: signer) {
        Account::do_accept_token<WETH>(&signer);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: admin
address admin = {{admin}};
address alice = {{alice}};
script {
    use 0x1::Account;

    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::CommonHelper;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrup;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR;

    fun admin_initialize(signer: signer) {
        TokenMock::register_token<STAR::STAR>(&signer, 9u8);
        TokenMock::register_token<TokenMock::WETH>(&signer, 9u8);

        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(100000000);

        // Initialize pool
        TokenSwapSyrup::initialize(&signer, TokenMock::mint_token<STAR::STAR>(powed_mint_aount));

        let release_per_second_amount = CommonHelper::pow_amount<TokenMock::WETH>(100);

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool<TokenMock::WETH>(&signer, release_per_second_amount, 0);

        let release_per_second = TokenSwapSyrup::query_release_per_second<TokenMock::WETH>();
        assert(release_per_second == release_per_second_amount, 10001);
        assert(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == 0, 10002);

        // Initialize asset such as WETH to alice's account
        CommonHelper::safe_mint<TokenMock::WETH>(&signer, powed_mint_aount);
        Account::deposit<TokenMock::WETH>(@alice, TokenMock::mint_token<TokenMock::WETH>(powed_mint_aount));
        assert(Account::balance<TokenMock::WETH>(@alice) == powed_mint_aount, 10003);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrup;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::CommonHelper;

    fun alice_stake(signer: signer) {
        TokenSwapSyrup::stake<TokenMock::WETH>(&signer, 1u64, CommonHelper::pow_amount<TokenMock::WETH>(1000000));
        assert(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == CommonHelper::pow_amount<TokenMock::WETH>(1000000), 10004);

        TokenSwapSyrup::stake<TokenMock::WETH>(&signer, 2u64, CommonHelper::pow_amount<TokenMock::WETH>(1000000));
        assert(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == CommonHelper::pow_amount<TokenMock::WETH>(2000000), 10005);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Debug;

    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrup;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR;

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

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 86402000

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x1::Token;
    use 0x1::Signer;
    use 0x1::Debug;

    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrup;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::CommonHelper;

    fun alice_unstake_after_1_second(signer: signer) {
        let (unstaked_token, reward_token) = TokenSwapSyrup::unstake<TokenMock::WETH>(&signer, 1);
        let unstake_token_amount = Token::value<TokenMock::WETH>(&unstaked_token);
        let reward_token_amount = Token::value<STAR::STAR>(&reward_token);

        Debug::print(&unstake_token_amount);
        Debug::print(&reward_token_amount);

        assert(unstake_token_amount == CommonHelper::pow_amount<TokenMock::WETH>(1000000), 10006);
        assert(reward_token_amount == CommonHelper::pow_amount<TokenMock::WETH>(100), 10007);

        let user_addr = Signer::address_of(&signer);
        Account::deposit<TokenMock::WETH>(user_addr, unstaked_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapConfig;

    fun admin_stepwise_config(signer: signer) {
        TokenSwapConfig::put_stepwise_multiplier(&signer, 1000, 1);
        let multiplier = TokenSwapConfig::get_stepwise_multiplier(1000);
        assert(multiplier == 1, 10008);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 2000, 2);
        multiplier = TokenSwapConfig::get_stepwise_multiplier(2000);
        assert(multiplier == 2, 10009);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 3000, 3);
        multiplier = TokenSwapConfig::get_stepwise_multiplier(3000);
        assert(multiplier == 3, 10010);

        TokenSwapConfig::put_stepwise_multiplier(&signer, 1000, 5);
        multiplier = TokenSwapConfig::get_stepwise_multiplier(1000);
        assert(multiplier == 5, 10011);

        multiplier = TokenSwapConfig::get_stepwise_multiplier(6000);
        assert(multiplier == 1, 10012);

        multiplier = TokenSwapConfig::get_stepwise_multiplier(2000);
        assert(multiplier == 2, 10013);

        multiplier = TokenSwapConfig::get_stepwise_multiplier(3000);
        assert(multiplier == 3, 10014);
    }
}
// check: EXECUTED