//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr bob --amount 10000000000000000

//# faucet --addr swap_admin --amount 10000000000000000


//# publish
module swap_admin::coin_mock {
    // mock MyToken token
    struct MyToken has copy, drop, store {}

    // mock Usdx token
    struct WUSDT has copy, drop, store {}
}

//# run --signers swap_admin
script {
    use std::signer;
    use starcoin_std::type_info::{struct_name, type_of};
    use starcoin_framework::managed_coin;
    use starcoin_framework::starcoin_coin::STC;

    use swap_admin::CommonHelper::pow_amount;
    use swap_admin::TokenSwapRouter;
    use swap_admin::coin_mock::WUSDT;

    fun init_token(swap_admin: &signer) {
        // coin_mock::register_token<WUSDT>(&signer, precision);
        let name = struct_name(&type_of<WUSDT>());
        managed_coin::initialize<WUSDT>(
            swap_admin,
            name,
            name,
            9,
            true
        );
        managed_coin::register<WUSDT>(swap_admin);
        managed_coin::mint<WUSDT>(
            swap_admin,
            signer::address_of(swap_admin),
            (pow_amount<WUSDT>(50000) as u64)
        );

        // token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<STC, WUSDT>(swap_admin);
        assert!(TokenSwapRouter::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use starcoin_framework::coin;
    use swap_admin::coin_mock::WUSDT;

    fun alice_accept_wusdt(alice: &signer) {
        coin::register<WUSDT>(alice);
    }
}
// check: EXECUTED

//# run --signers swap_admin
script {
    use swap_admin::TokenSwapRouter;
    use swap_admin::CommonHelper::pow_amount;
    use swap_admin::coin_mock::WUSDT;
    use swap_admin::CommonHelper;
    use starcoin_framework::starcoin_coin::STC;

    // Deposit to swap pool
    fun check_reverse(swap_admin: &signer) {
        let stc_amount: u128 = pow_amount<WUSDT>(1_000_000);
        let usdt_amount: u128 = pow_amount<WUSDT>(1_000_000);

        CommonHelper::safe_mint<WUSDT>(swap_admin, usdt_amount);

        ////////////////////////////////////////////////////////////////////////////////////////////
        // Add liquidity, STC/WUSDT = 1:1
        let amount_stc_desired: u128 = pow_amount<STC>(10000);
        let amount_usdt_desired: u128 = pow_amount<WUSDT>(10000);
        let amount_stc_min: u128 = stc_amount;
        let amount_usdt_min: u128 = usdt_amount;
        TokenSwapRouter::add_liquidity<STC, WUSDT>(
            swap_admin,
            amount_stc_desired,
            amount_usdt_desired,
            amount_stc_min,
            amount_usdt_min
        );

        // check liquidity
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity > 0, 10000);

        // check reverse
        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WUSDT>();
        assert!(reserve_x >= amount_stc_desired, 10001);
        assert!(reserve_y >= amount_usdt_desired, 10001);
    }
}
// check: EXECUTED

//# run --signers bob
script {
    use std::signer;
    use starcoin_std::debug;
    use starcoin_framework::starcoin_coin::STC;
    use starcoin_framework::coin;
    use swap_admin::coin_mock::WUSDT;
    use swap_admin::TokenSwapRouter;
    use swap_admin::TokenSwap;

    fun bob_test_do_swap(bob: &signer) {
        let bob_addr = signer::address_of(bob);

        let (reserve_x, reserve_y) = TokenSwap::get_reserves<STC, WUSDT>();
        debug::print<u128>(&reserve_x);
        debug::print<u128>(&reserve_y);

        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(
            bob,
            100,
            0
        );
        let balance = coin::balance<WUSDT>(bob_addr);
        assert!(balance > 0, 10002);

        TokenSwapRouter::swap_token_for_exact_token<STC, WUSDT>(bob, 10000000, 10000);
        let balance = coin::balance<STC>(bob_addr);
        assert!(balance > 0, 10003);
    }
}
// check: EXECUTED