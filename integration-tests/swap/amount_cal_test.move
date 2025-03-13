//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr swap_admin --amount 10000000000000000

//# publish
module swap_admin::CoinMock {
    struct WUSDT {}
}

//# run --signers swap_admin
script {
    use std::string;
    use swap_admin::CoinMock::WUSDT;
    use starcoin_framework::managed_coin;

    fun init_token(swap_admin: &signer) {
        managed_coin::initialize<WUSDT>(
            swap_admin,
            *string::bytes(&string::utf8(b"WUSDT")),
            *string::bytes(&string::utf8(b"WUSDT")),
            9,
            true,
        );
    }
}
// check: EXECUTED

//# run --signers swap_admin
script {
    use swap_admin::TokenSwapRouter;
    use swap_admin::CoinMock::WUSDT;
    use swap_admin::TokenSwap;
    use starcoin_framework::starcoin_coin::STC;

    fun register_token_pair(swap_admin: &signer) {
        // token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<STC, WUSDT>(swap_admin);
        assert!(TokenSwapRouter::swap_pair_exists<STC, WUSDT>(), 111);
    }
}

//# run --signers alice
script {
    use starcoin_framework::coin;
    use swap_admin::CoinMock::WUSDT;

    fun alice_register_wusdt(alice: &signer) {
        coin::register<WUSDT>(alice);
    }
}


//# run --signers swap_admin
script {
    use swap_admin::CommonHelper::{safe_mint_to, pow_amount};
    use swap_admin::CoinMock::WUSDT;

    fun swap_admin_mint_usdt_to_alice(swap_admin: &signer) {
        safe_mint_to<WUSDT>(swap_admin, @alice, pow_amount<WUSDT>(1000));
    }
}



//# run --signers alice
script {
    use std::string;
    use starcoin_std::debug;
    use starcoin_framework::starcoin_coin::STC;

    use swap_admin::CommonHelper::pow_amount;
    use swap_admin::CoinMock::WUSDT;
    use swap_admin::TokenSwapRouter;
    use swap_admin::TokenSwapLibrary;
    use swap_admin::TokenSwapConfig;

    fun add_liquidity_and_check_cal_output_test(alice: &signer) {
        //let scaling_factor = math128::pow(10, 9);// STC/WUSDT = 1:5
        // let stc_amount: u128 = 1000 * scaling_factor;
        // let usdt_amount: u128 = 1000 * scaling_factor;

        ////////////////////////////////////////////////////////////////////////////////////////////
        // Add liquidity, STC/WUSDT = 1:1
        let amount_stc_desired: u128 = pow_amount<STC>(1);
        let amount_usdt_desired: u128 = pow_amount<WUSDT>(1);
        let amount_stc_min: u128 = pow_amount<STC>(1000);
        let amount_usdt_min: u128 = pow_amount<WUSDT>(1000);

        TokenSwapRouter::add_liquidity<STC, WUSDT>(
            alice,
            amount_stc_desired,
            amount_usdt_desired,
            amount_stc_min,
            amount_usdt_min
        );
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity > 0, 100);

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, WUSDT>();
        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WUSDT>();
        //debug::print<u128>(&reserve_x);
        //debug::print<u128>(&reserve_y);
        assert!(reserve_x >= amount_stc_desired, 101);
        // assert!(reserve_y >=, 10002);

        let amount_out_1 = TokenSwapLibrary::get_amount_out(
            pow_amount<STC>(10),
            reserve_x,
            reserve_y,
            fee_numberator,
            fee_denumerator
        );
        debug::print<u128>(&amount_out_1);
        // assert!(1 * scaling_factor >= (1 * scaling_factor * reserve_y) / reserve_x * (997 / 1000), 1003);

        let amount_out_2 = TokenSwapLibrary::quote(amount_stc_desired, reserve_x, reserve_y);
        debug::print<u128>(&amount_out_2);
        assert!(amount_out_2 <= amount_usdt_desired, 104);

        let amount_out_3 = TokenSwapLibrary::get_amount_in(
            100,
            100000000,
            10000000000,
            3,
            1000
        );
        debug::print(&string::utf8(b"add_liquidity_and_check_cal_output_test | "));
        debug::print<u128>(&amount_out_3);
        debug::print<u128>(&amount_stc_desired);
        // assert!(amount_out_3 >= amount_stc_desired, 105);
    }
}