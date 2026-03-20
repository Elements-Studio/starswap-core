//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr SwapAdmin --amount 10000000000000000

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr exchanger --amount 10000000000000000


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
    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun register_pair(signer: signer) {
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);
        assert!(TokenSwap::swap_pair_exists<STC, WUSDT>(), 1001);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenMock::WUSDT;
    use SwapAdmin::CommonHelper;

    fun mint_usdt(signer: signer) {
        // Mint 100_000 USDT (9 decimals)
        CommonHelper::safe_mint<WUSDT>(&signer, 100000000000000);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun add_liquidity(signer: signer) {
        // Pool: 10_000_000_000_000 STC : 100_000_000_000 USDT (ratio 100:1)
        TokenSwapRouter::add_liquidity<STC, WUSDT>(
            &signer,
            10000000000000,   // 10000 STC (9 decimals)
            100000000000,     // 100 USDT (9 decimals)
            1,
            1,
        );
    }
}
// check: EXECUTED


// -- Test 1: Default (no limit configured) -> large swap succeeds -----

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun swap_no_limit(signer: signer) {
        // Swap 5000 STC -> should output ~50% of USDT reserve -- no limit set, so OK
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(&signer, 5000000000000, 0);
    }
}
// check: EXECUTED


// -- Test 2: Admin sets 30% output limit on STC->WUSDT direction ------

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun set_output_limit(signer: signer) {
        // Limit: max 30% of USDT reserve per swap when swapping STC->USDT
        TokenSwapConfig::set_swap_output_limit<STC, WUSDT>(&signer, 30);
        assert!(TokenSwapConfig::get_swap_output_limit<STC, WUSDT>() == 30, 2001);
    }
}
// check: EXECUTED


// -- Test 3: Small swap (well under 30%) -> succeeds ------------------

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun small_swap_ok(signer: signer) {
        // Swap a small amount -- output will be < 30% of USDT reserve
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(&signer, 100000000, 0);
    }
}
// check: EXECUTED


// -- Test 4: Large swap (>30% of USDT reserve) -> ABORTED -------------

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun large_swap_blocked(signer: signer) {
        // After previous swaps the pool is imbalanced.
        // Try to swap a very large amount of STC -- output should exceed 30% of USDT reserve.
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(&signer, 90000000000000, 0);
    }
}
// check: ABORTED


// -- Test 5: swap_token_for_exact_token also enforces limit ----------

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun exact_out_blocked(signer: signer) {
        // Try to request exact output > 30% of USDT reserve
        let (_, usdt_reserve) = TokenSwapRouter::get_reserves<STC, WUSDT>();
        // Request 50% of USDT reserve
        let requested = usdt_reserve / 2;
        TokenSwapRouter::swap_token_for_exact_token<STC, WUSDT>(&signer, 999999999999999, requested);
    }
}
// check: ABORTED


// -- Test 6: Reverse direction (WUSDT->STC) has no limit set -> OK -----

//# run --signers alice
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun reverse_swap_no_limit(signer: signer) {
        // WUSDT->STC direction has no limit configured, so any amount is OK
        TokenSwapRouter::swap_exact_token_for_token<WUSDT, STC>(&signer, 1000000000, 0);
    }
}
// check: EXECUTED


// -- Test 7: Admin can update limit ----------------------------------

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun update_limit(signer: signer) {
        // Raise limit to 80%
        TokenSwapConfig::set_swap_output_limit<STC, WUSDT>(&signer, 80);
        assert!(TokenSwapConfig::get_swap_output_limit<STC, WUSDT>() == 80, 3001);
    }
}
// check: EXECUTED


// -- Test 8: Admin can disable limit (set to 0) ---------------------

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun disable_limit(signer: signer) {
        TokenSwapConfig::set_swap_output_limit<STC, WUSDT>(&signer, 0);
        assert!(TokenSwapConfig::get_swap_output_limit<STC, WUSDT>() == 0, 4001);
    }
}
// check: EXECUTED
