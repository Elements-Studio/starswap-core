//! account: admin, 0x8c109349c6bd91411d6bc962e080c4a3, 10000 0x1::STC::STC
////! account: exchanger, 10000000000000 0x1::STC::STC
//! account: alice, 10000000000000 0x1::STC::STC

//! sender: alice
address alice = {{alice}};
module alice::TokenMock {
    // mock MyToken token
    struct MyToken has copy, drop, store {}

    // mock Usdx token
    struct WUSDT has copy, drop, store {}

    const U64_MAX:u64 = 18446744073709551615;  //length(U64_MAX)==20
    const U128_MAX:u128 = 340282366920938463463374607431768211455;  //length(U128_MAX)==39
}

//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenMock::{Self, WUSDT};

    fun init_token(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        TokenMock::register_token<WUSDT>(&signer, precision);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenMock::{WUSDT};
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;
    use 0x1::Math;

    fun init_account(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        let usdt_amount: u128 = 50000 * scaling_factor;
        CommonHelper::safe_mint<WUSDT>(&signer, usdt_amount);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenMock::{WUSDT};
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwap;
    use 0x1::STC::STC;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);
        assert(TokenSwap::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapRouter;
    use 0x1::STC;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenMock;

    fun add_liquidity_overflow(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC::STC, TokenMock::WUSDT>(&signer, 10, 4000, 10, 10);
        let total_liquidity = TokenSwapRouter::total_liquidity<STC::STC, TokenMock::WUSDT>();
        assert(total_liquidity == 200 - 1000, 3001);
        TokenSwapRouter::add_liquidity<STC::STC, TokenMock::WUSDT>(&signer, 10, 4000, 10, 10);
        let total_liquidity = TokenSwapRouter::total_liquidity<STC::STC, TokenMock::WUSDT>();
        assert(total_liquidity == (200 - 1000) * 2, 3002);
    }
}
// check: ARITHMETIC_ERROR


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
//    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapLibrary;
    use 0x1::Math;
    use 0x1::Debug;

    // case : x*y/z overflow
    fun token_overflow(_: signer) {
        let precision: u8 = 18;
        let scaling_factor = Math::pow(10, (precision as u64));
        let amount_x: u128 = 110000 * scaling_factor;
        let reserve_y: u128 = 8000000 * scaling_factor;
        let reserve_x: u128 = 2000000 * scaling_factor;

//        let amount_y = TokenSwapLibrary::quote(amount_x, reserve_x, reserve_y);
//        assert(amount_y == 400000, 3003);

        let amount_y_new = Math::mul_div(amount_x, reserve_y, reserve_x);
        Debug::print<u128>(&amount_y_new);
        assert(amount_y_new == 440000 * scaling_factor, 3003);
    }
}
// check: EXECUTED