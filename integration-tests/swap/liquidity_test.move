//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000

//# faucet --addr swap_admin --amount 10000000000000

//# faucet --addr liquidier --amount 10000000000000000

//# publish
module swap_admin::CoinMock {
    struct WUSDT {}
}

//# run --signers swap_admin
script {
    use std::string;
    use starcoin_framework::managed_coin;
    use swap_admin::CoinMock::WUSDT;

    fun init_token(swap_admin: signer) {
        managed_coin::initialize<WUSDT>(
            &swap_admin,
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
    use std::string;
    use starcoin_std::debug;
    use starcoin_framework::starcoin_coin::STC;

    use swap_admin::TokenSwap;
    use swap_admin::CoinMock::WUSDT;

    fun check_token_pair_symbol_and_name(_swap_admin: &signer) {
        debug::print(&string::utf8(b"swap_admin::TokenSwap::check_token_pair_symbol_and_name"));

        let pair_name = TokenSwap::coin_pair_name<STC, WUSDT>();
        debug::print(&pair_name);
        assert!(pair_name == string::utf8(b"L<STC,WUSDT>"), 101);

        let pair_symbol = TokenSwap::coin_pair_symbol<STC, WUSDT>();
        debug::print(&pair_symbol);
        assert!(pair_symbol == string::utf8(b"STC::WUSDT"), 102);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use starcoin_framework::managed_coin;
    use swap_admin::CoinMock::WUSDT;

    fun alice_register_wusdt(alice: &signer) {
        managed_coin::register<WUSDT>(alice);
    }
}
// check: EXECUTED

//# run --signers swap_admin
script {
    use swap_admin::CoinMock::WUSDT;
    use swap_admin::CommonHelper;

    fun init_account(swap_admin: signer) {
        // let scaling_factor = math128::pow(10, (9 as u128));
        CommonHelper::safe_mint_to<WUSDT>(
            &swap_admin,
            @alice,
            CommonHelper::pow_amount<WUSDT>(50000),
        );
    }
}
// check: EXECUTED


//# run --signers swap_admin
script {
    use swap_admin::CoinMock::WUSDT;
    use swap_admin::TokenSwap;

    use starcoin_framework::starcoin_coin::STC;

    fun swap_admin_register_token_pair(swap_admin: &signer) {
        //token pair register must be swap admin account
        TokenSwap::register_swap_pair<STC, WUSDT>(swap_admin);
        assert!(TokenSwap::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use std::signer;
    use std::string;
    use swap_admin::CommonHelper;
    use starcoin_framework::coin;
    use starcoin_std::debug;
    use starcoin_framework::starcoin_coin::STC;

    use swap_admin::CoinMock::WUSDT;
    use swap_admin::TokenSwapRouter;

    fun add_liquidity_and_swap(signer: signer) {
        debug::print(&string::utf8(b"add_liquidity_and_swap | entered"));

        // let scaling_factor = math128::pow(10, 9);
        // STC/WUSDT = 1:5
        let stc_amount: u128 = CommonHelper::pow_amount<STC>(10000);
        let usdt_amount: u128 = CommonHelper::pow_amount<WUSDT>(50000);

        ////////////////////////////////////////////////////////////////////////////////////////////
        // Add liquidity, STC/WUSDT = 1:5
        let amount_stc_desired: u128 = CommonHelper::pow_amount<STC>(10);
        let amount_usdt_desired: u128 = CommonHelper::pow_amount<WUSDT>(50);
        let amount_stc_min: u128 = CommonHelper::pow_amount<STC>(1);
        let amount_usdt_min: u128 = CommonHelper::pow_amount<WUSDT>(1);
        TokenSwapRouter::add_liquidity<STC, WUSDT>(
            &signer,
            amount_stc_desired,
            amount_usdt_desired,
            amount_stc_min,
            amount_usdt_min
        );

        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity > amount_stc_min, 101);

        // Balance verify
        debug::print(&string::utf8(b"add_liquidity_and_swap | check total_liquidity"));
        debug::print(&total_liquidity);

        // Check STC balance
        let stc_balance = (coin::balance<STC>(signer::address_of(&signer)) as u128);
        debug::print(&stc_balance);
        debug::print(&stc_amount);
        debug::print(&amount_stc_desired);

        assert!(stc_balance <= (stc_amount - amount_stc_desired), 102);

        debug::print(&string::utf8(b"add_liquidity_and_swap | check usdt_balance: "));
        let usdt_balance = (coin::balance<WUSDT>(signer::address_of(&signer)) as u128);
        debug::print(&usdt_amount);
        debug::print(&amount_usdt_desired);
        debug::print(&usdt_balance);
        assert!(usdt_balance >= (usdt_amount - amount_usdt_desired), 103);

        ////////////////////////////////////////////////////////////////////////////////////////////
        // Swap token pair, put 1 STC, got 5 WUSDT
        let pledge_stc_amount: u128 = CommonHelper::pow_amount<STC>(1);
        let pledge_usdt_amount: u128 = CommonHelper::pow_amount<WUSDT>(5);
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(&signer, pledge_stc_amount, pledge_stc_amount);
        assert!(
            (coin::balance<STC>(
                signer::address_of(&signer)
            ) as u128) <= (stc_amount - amount_stc_desired - pledge_stc_amount),
            104
        );
        assert!(
            (coin::balance<WUSDT>(
                signer::address_of(&signer)
            ) as u128) <= (usdt_amount - amount_usdt_desired + pledge_usdt_amount),
            105
        );

        debug::print(&string::utf8(b"add_liquidity_and_swap | exited"));
    }
}
// check: EXECUTED