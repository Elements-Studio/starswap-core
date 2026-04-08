//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WUSDT};

    fun init_token(signer: signer) {
        let precision: u8 = 9;
        TokenMock::register_token<WUSDT>(&signer, precision);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenMock::WUSDT;
    use SwapAdmin::CommonHelper;
    use StarcoinFramework::Math;

    fun init_account(signer: signer) {
        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));
        let usdt_amount: u128 = 100000 * scaling_factor;
        CommonHelper::safe_mint<WUSDT>(&signer, usdt_amount);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::WUSDT;
    use SwapAdmin::TokenSwap;
    use StarcoinFramework::STC::STC;

    fun register_token_pair(signer: signer) {
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);
        assert!(TokenSwap::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun add_liquidity(signer: signer) {
        // Add liquidity: 100_000 STC + 10_000_000 WUSDT (ratio 1:100)
        TokenSwapRouter::add_liquidity<STC, WUSDT>(&signer, 100000, 10000000, 10, 10);
        let total_liquidity = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity > 0, 3001);
    }
}
// check: EXECUTED

// ---- Test 1: Small swap (< 30% of reserve) should succeed ----
//# run --signers alice
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun swap_within_limit(signer: signer) {
        // Swap 10000 STC, which is 10% of 100000 STC reserve -> well under 30%
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(&signer, 10000, 0);
    }
}
// check: EXECUTED

// ---- Test 2: Large swap (> 30% of reserve) should abort with ERROR_SWAP_SWAPOUT_OVER_LIMIT (2010) ----
//# run --signers alice
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun swap_over_limit(signer: signer) {
        // After previous swap, STC reserve ~110000, WUSDT reserve ~9090909.
        // Swap 80000 STC -> output will be >> 30% of WUSDT reserve -> should abort.
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(&signer, 80000, 0);
    }
}
// check: MoveAbort

// ---- Test 3: Swap exactly at boundary (just under 30%) should succeed ----
//# run --signers alice
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;

    fun swap_at_boundary(signer: signer) {
        // Swap a moderate amount that stays under 30% output ratio
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(&signer, 20000, 0);
    }
}
// check: EXECUTED
