//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice

//# faucet --addr SwapAdmin


//# publish
module alice::TokenMock {
    // mock MyToken token
    struct MyToken has copy, drop, store {}

    // mock Usdx token
    struct WUSDT has copy, drop, store {}

    const U64_MAX:u64 = 18446744073709551615;  //length(U64_MAX)==20
    const U128_MAX:u128 = 340282366920938463463374607431768211455;  //length(U128_MAX)==39
}

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenMock::{Self, WUSDT};

    fun init_token(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        TokenMock::register_token<WUSDT>(&signer, precision);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::CommonHelper;
    use StarcoinFramework::Math;

    fun init_account(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        let usdt_amount: u128 = 50000 * scaling_factor;
        CommonHelper::safe_mint<WUSDT>(&signer, usdt_amount);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::TokenSwap;
    use StarcoinFramework::STC::STC;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);
        assert!(TokenSwap::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTED


//# run --signers alice

script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC;
    use SwapAdmin::TokenMock;

    fun add_liquidity_overflow(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC::STC, TokenMock::WUSDT>(&signer, 10, 4000, 10, 10);
        let total_liquidity = TokenSwapRouter::total_liquidity<STC::STC, TokenMock::WUSDT>();
        assert!(total_liquidity == 200 - 1000, 3001);
        TokenSwapRouter::add_liquidity<STC::STC, TokenMock::WUSDT>(&signer, 10, 4000, 10, 10);
        let total_liquidity = TokenSwapRouter::total_liquidity<STC::STC, TokenMock::WUSDT>();
        assert!(total_liquidity == (200 - 1000) * 2, 3002);
    }
}
// check: ARITHMETIC_ERROR


//# run --signers alice


script {
//    use SwapAdmin::TokenSwapLibrary;
    use StarcoinFramework::Math;
    use StarcoinFramework::Debug;

    // case : x*y/z overflow
    fun token_overflow(_: signer) {
        let precision: u8 = 18;
        let scaling_factor = Math::pow(10, (precision as u64));
        let amount_x: u128 = 110000 * scaling_factor;
        let reserve_y: u128 = 8000000 * scaling_factor;
        let reserve_x: u128 = 2000000 * scaling_factor;

//        let amount_y = TokenSwapLibrary::quote(amount_x, reserve_x, reserve_y);
//        assert!(amount_y == 400000, 3003);

        let amount_y_new = Math::mul_div(amount_x, reserve_y, reserve_x);
        Debug::print<u128>(&amount_y_new);
        assert!(amount_y_new == 440000 * scaling_factor, 3003);
    }
}
// check: EXECUTED