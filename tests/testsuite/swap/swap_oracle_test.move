//! account: admin, 0x4783d08fb16990bd35d83f3e23bf93b8, 200000 0x1::STC::STC
//! account: feetokenholder, 0x2d81a0427d64ff61b11ede9085efa5ad, 400000 0x1::STC::STC
//! account: feeadmin, 0xd231d9da8e37fc3d9ff3f576cf978535
//! account: exchanger, 100000 0x1::STC::STC
//! account: lp_provider, 500000 0x1::STC::STC
//! account: alice, 500000 0x1::STC::STC


//! new-transaction
//! sender: admin
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{Self, WETH, WUSDT};

    fun token_init(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 18u8);
        TokenMock::register_token<WUSDT>(&signer, 18u8);
    }
}

// check: EXECUTED

//! new-transaction
//! sender: lp_provider
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;

    fun init_account(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 60000000000000000000000000u128); //e25
        CommonHelper::safe_mint<WUSDT>(&signer, 50000000000000000000000000000u128);//e28
    }
}
// check: EXECUTED


//! new-transaction
//! sender: feetokenholder
script {
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;
    use 0x1::Token;
    use 0x1::Account;

    fun fee_token_init(signer: signer) {
        Token::register_token<XUSDT>(&signer, 9);
        Account::do_accept_token<XUSDT>(&signer);
        let token = Token::mint<XUSDT>(&signer, 5000000000000u128);
        Account::deposit_to_self(&signer, token);
    }
}

// check: EXECUTED


//! new-transaction
//! sender: feeadmin
script {
    use 0x1::Account;
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    fun accept_token(signer: signer) {
        Account::do_accept_token<XUSDT>(&signer);
    }
}
// check: EXECUTED



//! new-transaction
//! sender: exchanger
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;

    fun mint(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 3900000000000000000000u128); //e21
    }
}

// check: EXECUTED


//! new-transaction
//! sender: admin
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<WETH, WUSDT>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<WETH, WUSDT>(), 111);
    }
}

// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 1638415200000

//! new-transaction
//! sender: alice
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapOracleLibrary;
    use 0x1::Debug;

    fun oralce_info(_: signer) {
        let block_timestamp = TokenSwapOracleLibrary::current_block_timestamp();
        Debug::print(&block_timestamp);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapOracleLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x1::Debug;

    fun oralce_info(_: signer) {
        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();

        Debug::print<u128>(&110500);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: lp_provider
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapOracleLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x1::Debug;

    fun add_liquidity(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<WETH, WUSDT>(&signer, 60000000000000000000000u128, 50000000000000000000000000u128, 100, 100); //e22, e25

        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();
        Debug::print<u128>(&110501);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
    }
}

// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 1638418200000

//! new-transaction
//! sender: exchanger
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapOracleLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x1::Debug;

    fun swap_exact_token_for_token(signer: signer) {
        let amount_x_in = 100000000000000000000u128; //e20
        let amount_y_out_min = 25000000000000000u128;
        TokenSwapRouter::swap_exact_token_for_token<WETH, WUSDT>(&signer, amount_x_in, amount_y_out_min);

        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();
        Debug::print<u128>(&110502);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: exchanger
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapOracleLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x1::Debug;

    fun swap_token_for_exact_token(signer: signer) {
        let amount_x_in_max = 500000000000000000000u128;
        let amount_y_out = 2500000000000000000000u128; //e21
        TokenSwapRouter::swap_token_for_exact_token<WETH, WUSDT>(&signer, amount_x_in_max, amount_y_out);

        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();
        Debug::print<u128>(&110503);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
    }
}
// check: EXECUTED


//! block-prologue
//! author: genesis
//! block-number: 3
//! block-time: 1639030000000

//! new-transaction
//! sender: exchanger
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapOracleLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x1::Debug;

    fun swap_token_for_exact_token(signer: signer) {
        let amount_x_in_max = 500000000000000000000u128;
        let amount_y_out = 2500000000000000000000u128; //e21
        TokenSwapRouter::swap_token_for_exact_token<WETH, WUSDT>(&signer, amount_x_in_max, amount_y_out);

        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();
        Debug::print<u128>(&110504);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
    }
}
// check: EXECUTED
