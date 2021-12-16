//! account: admin, 0x4783d08fb16990bd35d83f3e23bf93b8, 200000 0x1::STC::STC
//! account: feetokenholder, 0x2d81a0427d64ff61b11ede9085efa5ad, 400000 0x1::STC::STC
//! account: feeadmin, 0x0a4183ac9335a9f5804014eab01c0abc
//! account: exchanger, 100000 0x1::STC::STC
//! account: alice, 500000 0x1::STC::STC


//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{Self, WETH, WUSDT, WDAI, WBTC};

    fun init_token(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 18u8);
        TokenMock::register_token<WUSDT>(&signer, 18u8);
        TokenMock::register_token<WDAI>(&signer, 18u8);
        TokenMock::register_token<WBTC>(&signer, 9u8);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT, WDAI, WBTC};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;

    fun init_account(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 600000u128);
        CommonHelper::safe_mint<WUSDT>(&signer, 500000u128);
        CommonHelper::safe_mint<WDAI>(&signer, 200000u128);
        CommonHelper::safe_mint<WBTC>(&signer, 100000u128);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: feetokenholder
address alice = {{alice}};
script {
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;
    use 0x1::Token;
    use 0x1::Account;

    fun fee_token_init(signer: signer) {
        Token::register_token<XUSDT>(&signer, 9);
        Account::do_accept_token<XUSDT>(&signer);
        let token = Token::mint<XUSDT>(&signer, 500000u128);
        Account::deposit_to_self(&signer, token);
    }
}

// check: EXECUTED

//! new-transaction
//! sender: exchanger
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};
    use 0x1::Account;

    fun accept_token(signer: signer) {
        Account::do_accept_token<WETH>(&signer);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: feeadmin
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    fun accept_token(signer: signer) {
        Account::do_accept_token<XUSDT>(&signer);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
address exchanger = {{exchanger}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;

    fun transfer(signer: signer) {
        CommonHelper::transfer<WETH>(&signer, @exchanger, 100000u128);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT, WDAI, WBTC};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x1::STC::STC;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<WETH, WUSDT>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<WETH, WUSDT>(), 111);

        TokenSwapRouter::register_swap_pair<WUSDT, WDAI>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<WUSDT, WDAI>(), 112);

        TokenSwapRouter::register_swap_pair<WDAI, WBTC>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<WDAI, WBTC>(), 113);

        TokenSwapRouter::register_swap_pair<STC, WETH>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<STC, WETH>(), 114);

        TokenSwapRouter::register_swap_pair<WBTC, WETH>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<WBTC, WETH>(), 115);
    }
}

// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x1::STC::STC;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT, WDAI, WBTC};

    fun add_liquidity(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<WETH, WUSDT>(&signer, 5000, 100000, 100, 100);
        TokenSwapRouter::add_liquidity<WUSDT, WDAI>(&signer, 20000, 30000, 100, 100);
        TokenSwapRouter::add_liquidity<WDAI, WBTC>(&signer, 100000, 4000, 100, 100);
        TokenSwapRouter::add_liquidity<STC, WETH>(&signer, 200000, 10000, 100, 100);
        TokenSwapRouter::add_liquidity<WETH, WBTC>(&signer, 60000, 5000, 100, 100);
    }
}

// check: EXECUTED


//! new-transaction
//! sender: exchanger
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter3;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WDOT, WBTC, WDAI};

    fun swap_pair_not_exist(signer: signer) {
        let amount_x_in = 200;
        let amount_y_out_min = 500;
        TokenSwapRouter3::swap_exact_token_for_token<WETH, WBTC, WDOT, WDAI>(&signer, amount_x_in, amount_y_out_min);
    }
}
// when swap router dost not exist, swap encounter failure
// check: EXECUTION_FAILURE
// check: MISSING_DATA


//! new-transaction
//! sender: exchanger
address alice = {{alice}};
script {
    // use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    // use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};

    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter3;
    use 0x1::STC::STC;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT, WDAI};

    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;
    use 0x1::Signer;
    use 0x1::Debug;

    fun swap_exact_token_for_token(signer: signer) {
        let amount_x_in = 15000;
        let amount_y_out_min = 10;
        let token_balance = CommonHelper::get_safe_balance<WDAI>(Signer::address_of(&signer));
        assert(token_balance == 0, 201);

        let (r_out, t_out, expected_token_balance) = TokenSwapRouter3::get_amount_out<STC, WETH, WUSDT, WDAI>(amount_x_in);
        TokenSwapRouter3::swap_exact_token_for_token<STC, WETH, WUSDT, WDAI>(&signer, amount_x_in, amount_y_out_min);

        // TokenSwapRouter::swap_exact_token_for_token<STC, WETH>(&signer, amount_x_in, r_out);
        // TokenSwapRouter::swap_exact_token_for_token<WETH, WUSDT>(&signer, r_out, t_out);
        // TokenSwapRouter::swap_exact_token_for_token<WUSDT, WDAI>(&signer, t_out, amount_y_out_min);

        let token_balance = CommonHelper::get_safe_balance<WDAI>(Signer::address_of(&signer));
        Debug::print<u128>(&r_out);
        Debug::print<u128>(&t_out);
        Debug::print<u128>(&token_balance);

        Debug::print<u128>(&amount_y_out_min);
        Debug::print<u128>(&expected_token_balance);
        assert(token_balance == expected_token_balance, (token_balance as u64));
        assert(token_balance >= amount_y_out_min, (token_balance as u64));
    }
}

// check: EXECUTED


//! new-transaction
//! sender: exchanger
address alice = {{alice}};
script {
//    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    // use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};

    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter3;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT, WDAI, WBTC};

    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;
    use 0x1::Signer;
    use 0x1::Debug;

    fun swap_token_for_exact_token(signer: signer) {
        let amount_x_in_max = 30000;
        let amount_y_out = 200;
        let token_balance = CommonHelper::get_safe_balance<WBTC>(Signer::address_of(&signer));
        assert(token_balance == 0, 201);

        let (t_in, r_in, x_in) = TokenSwapRouter3::get_amount_in<WETH, WUSDT, WDAI, WBTC>(amount_y_out);
        TokenSwapRouter3::swap_token_for_exact_token<WETH, WUSDT, WDAI, WBTC>(&signer, amount_x_in_max, amount_y_out);

        // TokenSwapRouter::swap_token_for_exact_token<WETH, WUSDT>(&signer, amount_x_in_max, r_in);
        // TokenSwapRouter::swap_token_for_exact_token<WUSDT, WDAI>(&signer, r_in, t_in);
        // TokenSwapRouter::swap_token_for_exact_token<WDAI, WBTC>(&signer, t_in, amount_y_out);

        let token_balance = CommonHelper::get_safe_balance<WBTC>(Signer::address_of(&signer));
        Debug::print<u128>(&x_in);
        Debug::print<u128>(&r_in);
        Debug::print<u128>(&t_in);
        Debug::print<u128>(&token_balance);
        Debug::print<u128>(&amount_x_in_max);
        assert(token_balance == amount_y_out, (token_balance as u64));
        assert(x_in <= amount_x_in_max, (token_balance as u64));
    }
}

// check: EXECUTED