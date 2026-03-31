//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr SwapAdmin --amount 10000000000000000

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr exchanger --amount 10000000000000000


// -- Setup: register token and pair, add liquidity --------------------

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WUSDT};

    fun init_token(signer: signer) {
        TokenMock::register_token<WUSDT>(&signer, 9);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapScripts;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun register_pair(signer: signer) {
        TokenSwapScripts::register_swap_pair<STC, WUSDT>(signer);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenMock::WUSDT;
    use SwapAdmin::CommonHelper;

    fun mint_usdt(signer: signer) {
        CommonHelper::safe_mint<WUSDT>(&signer, 100000000000000);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenSwapScripts;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun add_liquidity(signer: signer) {
        // Pool: 10_000 STC (9 dec) : 100 USDT (9 dec) => ratio 100:1
        TokenSwapScripts::add_liquidity<STC, WUSDT>(
            signer,
            10000000000000,   // 10000 STC
            100000000000,     // 100 USDT
            1,
            1,
        );
    }
}
// check: EXECUTED


// -- Test 1: Admin sets 30% output limit via entry function -----------

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapScripts;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun set_limit_via_entry(signer: signer) {
        // Set 30% limit via the new entry function
        TokenSwapScripts::set_swap_output_limit<STC, WUSDT>(signer, 30);
        // Verify it was set correctly
        assert!(TokenSwapConfig::get_swap_output_limit<STC, WUSDT>() == 30, 1001);
    }
}
// check: EXECUTED


// -- Test 2: Small swap (<30% of USDT reserve) -> succeeds -----------

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapScripts;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun small_swap_ok(signer: signer) {
        // Swap 100 STC -> output ~0.99 USDT, well under 30% of 100 USDT reserve
        TokenSwapScripts::swap_exact_token_for_token<STC, WUSDT>(signer, 100000000000, 0);
    }
}
// check: EXECUTED


// -- Test 3: Large swap (>30% of USDT reserve) -> ABORTED -------------

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapScripts;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun large_swap_blocked(signer: signer) {
        // Swap 90_000 STC -> output would be ~47 USDT out of ~99 reserve = ~47% > 30%
        TokenSwapScripts::swap_exact_token_for_token<STC, WUSDT>(signer, 90000000000000, 0);
    }
}
// check: ABORTED


// -- Test 4: swap_token_for_exact_token also blocked when >30% --------

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun exact_out_blocked(signer: signer) {
        // Request 50% of USDT reserve as exact output -> exceeds 30% limit
        let (_, usdt_reserve) = TokenSwapRouter::get_reserves<STC, WUSDT>();
        let requested = usdt_reserve / 2;
        TokenSwapRouter::swap_token_for_exact_token<STC, WUSDT>(&signer, 999999999999999, requested);
    }
}
// check: ABORTED


// -- Test 5: Admin updates limit to 80% via entry -> large swap OK ----

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapScripts;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun raise_limit(signer: signer) {
        TokenSwapScripts::set_swap_output_limit<STC, WUSDT>(signer, 80);
        assert!(TokenSwapConfig::get_swap_output_limit<STC, WUSDT>() == 80, 2001);
    }
}
// check: EXECUTED


//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapScripts;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun large_swap_now_ok(signer: signer) {
        // Swap 5000 STC -> output ~33 USDT, about 33% of ~99 USDT reserve, under 80% limit
        TokenSwapScripts::swap_exact_token_for_token<STC, WUSDT>(signer, 5000000000000, 0);
    }
}
// check: EXECUTED


// -- Test 6: Admin disables limit via entry -> any swap OK -----------

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapScripts;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun disable_limit(signer: signer) {
        TokenSwapScripts::set_swap_output_limit<STC, WUSDT>(signer, 0);
        assert!(TokenSwapConfig::get_swap_output_limit<STC, WUSDT>() == 0, 3001);
    }
}
// check: EXECUTED
