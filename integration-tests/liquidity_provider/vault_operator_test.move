//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr SwapAdmin --amount 10000000000000

//# faucet --addr provider --amount 100000000000000

//# faucet --addr operator1 --amount 10000000000000

//# faucet --addr operator2 --amount 10000000000000


// Setup
//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WUSDT};
    fun setup(signer: signer) {
        TokenMock::register_token<WUSDT>(&signer, 9u8);
    }
}
// check: EXECUTED

//# run --signers provider
script {
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::Math;
    fun setup_provider(signer: signer) {
        let sf = Math::pow(10, 9u64);
        CommonHelper::safe_mint<WUSDT>(&signer, 100000 * sf);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun setup_pair(signer: signer) {
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);
    }
}
// check: EXECUTED

//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun create_and_deposit(signer: signer) {
        let sf = Math::pow(10, 9u64);
        SwapLiquidityProvider::create_vault<STC, WUSDT>(&signer);
        SwapLiquidityProvider::deposit<STC, WUSDT>(&signer, 80000 * sf, 8000 * sf);
    }
}
// check: EXECUTED


// ======================== Test: Multiple operators ========================

// Provider proposes operator1 and operator2
//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun propose_ops(signer: signer) {
        SwapLiquidityProvider::propose_operator<STC, WUSDT>(&signer, @operator1);
        SwapLiquidityProvider::propose_operator<STC, WUSDT>(&signer, @operator2);
    }
}
// check: EXECUTED

// operator1 accepts
//# run --signers operator1
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun accept_op1(signer: signer) {
        SwapLiquidityProvider::accept_operator_cap<STC, WUSDT>(&signer, @provider);
    }
}
// check: EXECUTED

// operator2 accepts
//# run --signers operator2
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun accept_op2(signer: signer) {
        SwapLiquidityProvider::accept_operator_cap<STC, WUSDT>(&signer, @provider);
    }
}
// check: EXECUTED


// Verify both operators are authorized
//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    fun verify_operators(signer: signer) {
        let prov = Signer::address_of(&signer);
        assert!(SwapLiquidityProvider::is_operator<STC, WUSDT>(@operator1, prov), 10200);
        assert!(SwapLiquidityProvider::is_operator<STC, WUSDT>(@operator2, prov), 10201);

        let ops = SwapLiquidityProvider::get_operators<STC, WUSDT>(prov);
        assert!(Vector::length(&ops) == 2, 10202);
    }
}
// check: EXECUTED


// operator1 adds liquidity
//# run --signers operator1
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun op1_add_liquidity(signer: signer) {
        let sf = Math::pow(10, 9u64);
        SwapLiquidityProvider::add_liquidity<STC, WUSDT>(
            &signer, @provider, 20000 * sf, 2000 * sf, 1, 1,
        );
    }
}
// check: EXECUTED


// operator2 also adds liquidity
//# run --signers operator2
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun op2_add_liquidity(signer: signer) {
        let sf = Math::pow(10, 9u64);
        SwapLiquidityProvider::add_liquidity<STC, WUSDT>(
            &signer, @provider, 20000 * sf, 2000 * sf, 1, 1,
        );
    }
}
// check: EXECUTED


// ======================== Test: Operator surrender ========================

// operator1 surrenders their cap
//# run --signers operator1
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun surrender_op1(signer: signer) {
        SwapLiquidityProvider::surrender_operator_cap<STC, WUSDT>(&signer);
    }
}
// check: EXECUTED


// Verify operator1 can no longer operate but operator2 still can
//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    fun verify_after_surrender(signer: signer) {
        let prov = Signer::address_of(&signer);
        assert!(!SwapLiquidityProvider::is_operator<STC, WUSDT>(@operator1, prov), 10210);
        assert!(SwapLiquidityProvider::is_operator<STC, WUSDT>(@operator2, prov), 10211);

        let ops = SwapLiquidityProvider::get_operators<STC, WUSDT>(prov);
        assert!(Vector::length(&ops) == 1, 10212);
    }
}
// check: EXECUTED


// operator1 tries to add liquidity after surrender (should fail)
//# run --signers operator1
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun op1_fails_after_surrender(signer: signer) {
        let sf = Math::pow(10, 9u64);
        SwapLiquidityProvider::add_liquidity<STC, WUSDT>(
            &signer, @provider, 1000 * sf, 100 * sf, 1, 1,
        );
    }
}
// check: "Keep(ABORTED { code: 20004"


// operator2 can still remove liquidity
//# run --signers operator2
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun op2_still_works(signer: signer) {
        let (_x, _y, lp) = SwapLiquidityProvider::vault_balances<STC, WUSDT>(@provider);
        // Remove a small portion
        let remove_amount = lp / 4;
        SwapLiquidityProvider::remove_liquidity<STC, WUSDT>(
            &signer, @provider, remove_amount, 1, 1,
        );
    }
}
// check: EXECUTED
