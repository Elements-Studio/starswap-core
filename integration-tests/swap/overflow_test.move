//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr swap_admin --amount 10000000000000000

//# publish
module alice::coin_mock {
    // mock MyToken token
    struct MyToken has copy, drop, store {}

    // mock Usdx token
    struct WUSDT has copy, drop, store {}

    //length(U64_MAX)==20
    const U64_MAX: u64 = 18446744073709551615;

    //length(U128_MAX)==39
    const U128_MAX: u128 = 340282366920938463463374607431768211455;
}

//# run --signers alice
script {
    use std::signer;
    use alice::coin_mock::WUSDT;
    use starcoin_framework::coin;
    use starcoin_framework::managed_coin;
    use starcoin_std::type_info::{struct_name, type_of};
    use swap_admin::CommonHelper::pow_amount;

    fun init_token(alice: &signer) {
        let alice_addr = signer::address_of(alice);
        let name = struct_name(&type_of<WUSDT>());
        managed_coin::initialize<WUSDT>(
            alice,
            name,
            name,
            9,
            true
        );
        managed_coin::register<WUSDT>(alice);
        managed_coin::mint<WUSDT>(alice, alice_addr, (pow_amount<WUSDT>(50000) as u64));
        assert!(coin::balance<WUSDT>(alice_addr) == (pow_amount<WUSDT>(50000) as u64), 101);
    }
}
// check: EXECUTED

// //# run --signers alice
// script {
//     use starcoin_std::math128;
//     use alice::coin_mock::{WUSDT};
//     use swap_admin::CommonHelper;
//
//     fun init_account(signer: signer) {
//         let precision: u8 = 9; //STC precision is also 9.
//         let scaling_factor = math128::pow(10, (precision as u128));
//         let usdt_amount: u128 = 50000 * scaling_factor;
//         CommonHelper::safe_mint<WUSDT>(&signer, usdt_amount);
//     }
// }
// // check: EXECUTED

//# run --signers swap_admin
script {
    use alice::coin_mock::WUSDT;
    use swap_admin::TokenSwapRouter;
    use swap_admin::TokenSwap;
    use starcoin_framework::starcoin_coin::STC;

    fun register_token_pair(swap_admin: &signer) {
        //token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<STC, WUSDT>(swap_admin);
        assert!(TokenSwap::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use swap_admin::TokenSwapRouter;
    use alice::coin_mock::WUSDT;
    use starcoin_framework::starcoin_coin::STC;

    fun add_liquidity_overflow(alice: &signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC, WUSDT>(
            alice,
            10,
            4000,
            10,
            10
        );
        let total_liquidity = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity == 200 - 1000, 3001);

        TokenSwapRouter::add_liquidity<STC, WUSDT>(
            alice,
            10,
            4000,
            10,
            10
        );
        let total_liquidity = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity == (200 - 1000) * 2, 3002);
    }
}
// check: ARITHMETIC_ERROR


//# run --signers alice
script {
    use starcoin_std::math128;
    use starcoin_std::debug;

    // case : x*y/z overflow
    fun token_overflow(_: signer) {
        let precision: u8 = 18;
        let scaling_factor = math128::pow(10, (precision as u128));
        let amount_x: u128 = 110000 * scaling_factor;
        let reserve_y: u128 = 8000000 * scaling_factor;
        let reserve_x: u128 = 2000000 * scaling_factor;

        //        let amount_y = TokenSwapLibrary::quote(amount_x, reserve_x, reserve_y);
        //        assert!(amount_y == 400000, 3003);

        let amount_y_new = math128::mul_div(amount_x, reserve_y, reserve_x);
        debug::print<u128>(&amount_y_new);
        assert!(amount_y_new == 440000 * scaling_factor, 3003);
    }
}
// check: EXECUTED