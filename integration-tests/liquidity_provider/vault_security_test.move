//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr SwapAdmin --amount 10000000000000

//# faucet --addr provider --amount 100000000000000

//# faucet --addr operator --amount 10000000000000

//# faucet --addr attacker --amount 10000000000000


// Setup: Register token, pair, create vault, deposit, grant operator
//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WUSDT};
    fun setup_token(signer: signer) {
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
        let scaling_factor = Math::pow(10, 9u64);
        CommonHelper::safe_mint<WUSDT>(&signer, 100000 * scaling_factor);
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
    fun setup_vault(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        SwapLiquidityProvider::create_vault<STC, WUSDT>(&signer);
        SwapLiquidityProvider::deposit<STC, WUSDT>(&signer, 80000 * scaling_factor, 8000 * scaling_factor);
    }
}
// check: EXECUTED

//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun setup_propose(signer: signer) {
        SwapLiquidityProvider::propose_operator<STC, WUSDT>(&signer, @operator);
    }
}
// check: EXECUTED

//# run --signers operator
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun setup_accept(signer: signer) {
        SwapLiquidityProvider::accept_operator_cap<STC, WUSDT>(&signer, @provider);
    }
}
// check: EXECUTED

// Operator adds liquidity so the vault has LP tokens
//# run --signers operator
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun setup_liquidity(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        SwapLiquidityProvider::add_liquidity<STC, WUSDT>(
            &signer, @provider,
            50000 * scaling_factor, 5000 * scaling_factor, 1, 1,
        );
    }
}
// check: EXECUTED


// ======================== Security Test 1: Attacker cannot use vault ========================
// Unauthorized account tries to add_liquidity (no OperatorCap)

//# run --signers attacker
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun test_attacker_add_liquidity(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        // Should abort: attacker has no OperatorCap
        SwapLiquidityProvider::add_liquidity<STC, WUSDT>(
            &signer, @provider,
            1000 * scaling_factor, 100 * scaling_factor, 1, 1,
        );
    }
}
// check: "Keep(ABORTED { code: 20004"


// ======================== Security Test 2: Attacker cannot remove liquidity ========================

//# run --signers attacker
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun test_attacker_remove_liquidity(signer: signer) {
        // Should abort: attacker has no OperatorCap
        SwapLiquidityProvider::remove_liquidity<STC, WUSDT>(
            &signer, @provider,
            1000000000, 1, 1,
        );
    }
}
// check: "Keep(ABORTED { code: 20004"


// ======================== Security Test 3: Attacker cannot withdraw from vault ========================

//# run --signers attacker
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun test_attacker_withdraw(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        // Should abort: attacker is not the vault owner.
        // withdraw checks that vault exists at Signer::address_of(&signer),
        // and attacker has no vault -> ERR_VAULT_NOT_EXISTS
        SwapLiquidityProvider::withdraw<STC, WUSDT>(&signer, 1000 * scaling_factor, 0);
    }
}
// check: "Keep(ABORTED { code: 20002"


// ======================== Security Test 4: Operator cannot withdraw ========================
// Even authorized operator cannot call withdraw (withdraw only checks provider signer)

//# run --signers operator
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun test_operator_cannot_withdraw(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        // Operator tries to withdraw from their own address (no vault there)
        SwapLiquidityProvider::withdraw<STC, WUSDT>(&signer, 1000 * scaling_factor, 0);
    }
}
// check: "Keep(ABORTED { code: 20002"


// ======================== Security Test 5: Attacker cannot create duplicate vault ========================

//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun test_duplicate_vault(signer: signer) {
        // Provider already has a vault, creating another should fail
        SwapLiquidityProvider::create_vault<STC, WUSDT>(&signer);
    }
}
// check: "Keep(ABORTED { code: 20001"


// ======================== Security Test 6: Funds cycle safely ========================
// Verify that after add + remove cycle, all funds remain in vault

//# run --signers operator
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Account;

    fun test_funds_stay_in_vault(signer: signer) {
        let provider_addr = @provider;
        let operator_addr = @operator;

        // Record operator's balances before
        let op_stc_before = Account::balance<STC>(operator_addr);

        // Get vault state
        let (_x_bal, _y_bal, lp_bal) = SwapLiquidityProvider::vault_balances<STC, WUSDT>(provider_addr);

        // Remove all LP from vault
        SwapLiquidityProvider::remove_liquidity<STC, WUSDT>(
            &signer, provider_addr,
            lp_bal, 1, 1,
        );

        // Operator's account balance should NOT have increased
        // (funds go to vault, not operator)
        let op_stc_after = Account::balance<STC>(operator_addr);
        assert!(op_stc_after <= op_stc_before, 10100);

        // Vault should have all the tokens now, zero LP
        let (x_final, y_final, lp_final) = SwapLiquidityProvider::vault_balances<STC, WUSDT>(provider_addr);
        assert!(x_final > 0, 10101);
        assert!(y_final > 0, 10102);
        assert!(lp_final == 0, 10103);
    }
}
// check: EXECUTED
