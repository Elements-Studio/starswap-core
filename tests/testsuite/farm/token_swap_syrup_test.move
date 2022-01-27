//! account: admin, 0x4783d08fb16990bd35d83f3e23bf93b8, 10000000000000 0x1::STC::STC
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
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::WETH;

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
    use 0x1::Math;
    use 0x1::Account;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrup;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;

    fun admin_initialize(signer: signer) {
        TokenMock::register_token<STAR::STAR>(&signer, 9u8);
        TokenMock::register_token<TokenMock::WETH>(&signer, 9u8);

        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));
        let total_mint = 100000000;
        let total_mint_factor = total_mint * scaling_factor;

        // Initialize pool
        TokenSwapSyrup::initialize(&signer, TokenMock::mint_token<STAR::STAR>(total_mint_factor));

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool<TokenMock::WETH>(&signer, 100 * scaling_factor, 1, 0);
        let (multiplier, _) = TokenSwapSyrup::query_info<TokenMock::WETH>();
        assert(multiplier == 1, 10001);
        assert(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == 0, 10002);

        // Initialize asset such as WETH to alice's account
        CommonHelper::safe_mint<TokenMock::WETH>(&signer, total_mint_factor);
        Account::deposit<TokenMock::WETH>(@alice, TokenMock::mint_token<TokenMock::WETH>(total_mint_factor));
        assert(Account::balance<TokenMock::WETH>(@alice) == total_mint_factor, 10003);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Math;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrup;

    fun alice_stake(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);

        TokenSwapSyrup::stake<TokenMock::WETH>(&signer, 1u64, 1000000 * scaling_factor);
        assert(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == (1000000u128 * scaling_factor), 10003);

        TokenSwapSyrup::stake<TokenMock::WETH>(&signer, 2u64, 1000000 * scaling_factor);
        assert(TokenSwapSyrup::query_total_stake<TokenMock::WETH>() == (2000000u128 * scaling_factor), 10004);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x1::Signer;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrup;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;

    fun alice_unstake_early(signer: signer) {
        let (unstaked_token, reward_token) = TokenSwapSyrup::unstake<TokenMock::WETH>(&signer, 1);
        Account::deposit<TokenMock::WETH>(Signer::address_of(&signer), unstaked_token);
        Account::deposit<STAR::STAR>(Signer::address_of(&signer), reward_token);
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
    use 0x1::Math;
    use 0x1::Token;
    use 0x1::Signer;
    use 0x1::Debug;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrup;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;

    fun alice_unstake_after_1_second(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);

        let (unstaked_token, reward_token) = TokenSwapSyrup::unstake<TokenMock::WETH>(&signer, 1);
        let unstake_token_amount = Token::value<TokenMock::WETH>(&unstaked_token);
        let reward_token_amount = Token::value<STAR::STAR>(&reward_token);

        Debug::print(&unstake_token_amount);
        Debug::print(&reward_token_amount);

        assert(unstake_token_amount == 1000000 * scaling_factor, 10005);

        // Check is half of amount from stakeing in two times
        assert(reward_token_amount == 50 * scaling_factor, 10006);

        let user_addr = Signer::address_of(&signer);
        Account::deposit<TokenMock::WETH>(user_addr, unstaked_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);
    }
}
// check: EXECUTED