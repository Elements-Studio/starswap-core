//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr SwapAdmin --amount 10000000000000

//# faucet --addr provider --amount 100000000000000

//# faucet --addr operator --amount 10000000000000

//# faucet --addr attacker --amount 10000000000000


// Task 5: Register mock token WUSDT
//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WUSDT};
    fun register_token(signer: signer) {
        TokenMock::register_token<WUSDT>(&signer, 9u8);
    }
}
// check: EXECUTED


// Task 6: Mint WUSDT to provider
//# run --signers provider
script {
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::Math;
    fun mint_to_provider(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        CommonHelper::safe_mint<WUSDT>(&signer, 100000 * scaling_factor);
    }
}
// check: EXECUTED


// Task 7: Register swap pair STC/WUSDT
//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun register_pair(signer: signer) {
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);
        assert!(TokenSwap::swap_pair_exists<STC, WUSDT>(), 10001);
    }
}
// check: EXECUTED


// ======================== Test 1: Create Vault ========================

// Task 8: Provider creates vault
//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    fun test_create_vault(signer: signer) {
        SwapLiquidityProvider::create_vault<STC, WUSDT>(&signer);
        assert!(SwapLiquidityProvider::vault_exists<STC, WUSDT>(Signer::address_of(&signer)), 10010);
    }
}
// check: EXECUTED


// ======================== Test 2: Deposit into Vault ========================

// Task 9: Provider deposits STC and WUSDT into vault
//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Math;
    fun test_deposit(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        let stc_deposit = 80000 * scaling_factor;
        let usdt_deposit = 8000 * scaling_factor;
        SwapLiquidityProvider::deposit<STC, WUSDT>(&signer, stc_deposit, usdt_deposit);

        let provider_addr = Signer::address_of(&signer);
        let (x_bal, y_bal, lp_bal) = SwapLiquidityProvider::vault_balances<STC, WUSDT>(provider_addr);
        assert!(x_bal == stc_deposit, 10020);
        assert!(y_bal == usdt_deposit, 10021);
        assert!(lp_bal == 0, 10022);
    }
}
// check: EXECUTED


// ======================== Test 3: Grant Operator (2-step) ========================

// Task 10: Provider proposes operator
//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    fun test_propose_operator(signer: signer) {
        SwapLiquidityProvider::propose_operator<STC, WUSDT>(&signer, @operator);
    }
}
// check: EXECUTED

// Task 11: Operator accepts capability
//# run --signers operator
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    fun test_accept_operator(signer: signer) {
        SwapLiquidityProvider::accept_operator_cap<STC, WUSDT>(&signer, @provider);
        assert!(SwapLiquidityProvider::is_operator<STC, WUSDT>(
            Signer::address_of(&signer), @provider), 10030);
    }
}
// check: EXECUTED


// ======================== Test 4: Operator adds liquidity ========================

// Task 12: Operator adds liquidity from vault to pool
//# run --signers operator
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun test_operator_add_liquidity(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        let provider_addr = @provider;
        let stc_desired = 50000 * scaling_factor;
        let usdt_desired = 5000 * scaling_factor;
        SwapLiquidityProvider::add_liquidity<STC, WUSDT>(
            &signer, provider_addr,
            stc_desired, usdt_desired, 1, 1,
        );

        // Verify vault has LP tokens and reduced X/Y balances
        let (x_bal, y_bal, lp_bal) = SwapLiquidityProvider::vault_balances<STC, WUSDT>(provider_addr);
        assert!(x_bal == 30000 * scaling_factor, 10040); // 80000 - 50000
        assert!(y_bal == 3000 * scaling_factor, 10041);  // 8000 - 5000
        assert!(lp_bal > 0, 10042);
    }
}
// check: EXECUTED


// ======================== Test 5: Operator removes liquidity ========================

// Task 12: Operator removes some liquidity back to vault
//# run --signers operator
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun test_operator_remove_liquidity(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        let provider_addr = @provider;

        // Get current LP balance
        let (_x_before, _y_before, lp_before) = SwapLiquidityProvider::vault_balances<STC, WUSDT>(provider_addr);
        // Remove half of LP
        let remove_amount = lp_before / 2;
        SwapLiquidityProvider::remove_liquidity<STC, WUSDT>(
            &signer, provider_addr,
            remove_amount, 1, 1,
        );

        // Verify: X and Y increased, LP decreased
        let (x_after, y_after, lp_after) = SwapLiquidityProvider::vault_balances<STC, WUSDT>(provider_addr);
        assert!(x_after > 30000 * scaling_factor, 10050);
        assert!(y_after > 3000 * scaling_factor, 10051);
        assert!(lp_after < lp_before, 10052);
        let _ = scaling_factor;
    }
}
// check: EXECUTED


// ======================== Test 6: Provider withdraws from vault ========================

// Task 13: Provider withdraws some tokens from vault
//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::Math;
    fun test_provider_withdraw(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        let provider_addr = Signer::address_of(&signer);
        let (x_before, _y_before, _lp) = SwapLiquidityProvider::vault_balances<STC, WUSDT>(provider_addr);

        let withdraw_x = 1000 * scaling_factor;
        let stc_balance_before = Account::balance<STC>(provider_addr);
        SwapLiquidityProvider::withdraw<STC, WUSDT>(&signer, withdraw_x, 0);

        // Vault X balance decreased
        let (x_after, _y_after, _lp2) = SwapLiquidityProvider::vault_balances<STC, WUSDT>(provider_addr);
        assert!(x_after == x_before - withdraw_x, 10060);

        // Provider account STC balance increased
        let stc_balance_after = Account::balance<STC>(provider_addr);
        assert!(stc_balance_after > stc_balance_before, 10061);
    }
}
// check: EXECUTED


// ======================== Test 7: Revoke operator ========================

// Task 14: Provider revokes operator
//# run --signers provider
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Signer;
    fun test_revoke_operator(signer: signer) {
        let provider_addr = Signer::address_of(&signer);
        let operator_addr = @operator;
        SwapLiquidityProvider::revoke_operator<STC, WUSDT>(&signer, operator_addr);
        assert!(!SwapLiquidityProvider::is_operator<STC, WUSDT>(operator_addr, provider_addr), 10070);
    }
}
// check: EXECUTED


// ======================== Test 8: Revoked operator cannot add liquidity ========================

// Task 15: Revoked operator tries to add liquidity (should fail)
//# run --signers operator
script {
    use SwapAdmin::SwapLiquidityProvider;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;
    fun test_revoked_operator_fails(signer: signer) {
        let scaling_factor = Math::pow(10, 9u64);
        // This should abort with ERR_NOT_OPERATOR (20004)
        SwapLiquidityProvider::add_liquidity<STC, WUSDT>(
            &signer, @provider,
            1000 * scaling_factor, 100 * scaling_factor, 1, 1,
        );
    }
}
// check: "Keep(ABORTED { code: 20004"
