// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

/// SwapLiquidityProvider: Vault + Operator model for safe liquidity management.
///
/// Design:
///   - Provider (fund owner) creates a Vault, deposits Token<X> and Token<Y>.
///   - Provider grants OperatorCap to an Operator address.
///   - Operator can add/remove liquidity using Vault funds (never withdraws to own account).
///   - Only Provider can withdraw funds from the Vault to their own account.
///   - If Operator key is compromised, funds stay in the Vault -- attacker can only
///     shuffle funds between Vault and LP pool, never extract them.
///
/// No modification to existing swap contracts is needed -- leverages the fact that
/// `TokenSwap::mint` and `TokenSwap::burn` are pure token functions (no signer required).

module SwapAdmin::SwapLiquidityProvider {
    use StarcoinFramework::Token;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Event;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Account;

    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwapLibrary;

    // ======================== Error codes ========================

    const ERR_VAULT_ALREADY_EXISTS: u64 = 20001;
    const ERR_VAULT_NOT_EXISTS: u64 = 20002;
    const ERR_NOT_PROVIDER: u64 = 20003;
    const ERR_NOT_OPERATOR: u64 = 20004;
    const ERR_OPERATOR_ALREADY_GRANTED: u64 = 20005;
    const ERR_OPERATOR_NOT_FOUND: u64 = 20006;
    const ERR_INSUFFICIENT_X: u64 = 20007;
    const ERR_INSUFFICIENT_Y: u64 = 20008;
    const ERR_INSUFFICIENT_LP: u64 = 20009;
    const ERR_INVALID_TOKEN_PAIR: u64 = 20010;
    const ERR_ZERO_AMOUNT: u64 = 20011;
    const ERR_CAP_ALREADY_EXISTS: u64 = 20012;
    const ERR_CAP_NOT_EXISTS: u64 = 20013;

    // ======================== Resources ========================

    /// Vault stored under Provider's address. Holds all funds + LP tokens.
    /// The Vault is token-pair-specific (one Vault per <X, Y> pair per provider).
    struct Vault<phantom X, phantom Y> has key, store {
        token_x: Token::Token<X>,
        token_y: Token::Token<Y>,
        lp_tokens: Token::Token<TokenSwap::LiquidityToken<X, Y>>,
        operators: vector<address>,
    }

    /// Capability stored under Operator's address, pointing back to Provider's Vault.
    /// This is the proof that the Operator is authorized.
    struct OperatorCap<phantom X, phantom Y> has key, store {
        provider: address,
    }

    /// Event handles stored under Provider's address.
    struct VaultEventHandle<phantom X, phantom Y> has key, store {
        deposit_event: Event::EventHandle<DepositEvent>,
        withdraw_event: Event::EventHandle<WithdrawEvent>,
        add_liquidity_event: Event::EventHandle<VaultAddLiquidityEvent>,
        remove_liquidity_event: Event::EventHandle<VaultRemoveLiquidityEvent>,
        grant_event: Event::EventHandle<GrantOperatorEvent>,
        revoke_event: Event::EventHandle<RevokeOperatorEvent>,
    }

    // ======================== Events ========================

    struct DepositEvent has drop, store {
        provider: address,
        amount_x: u128,
        amount_y: u128,
    }

    struct WithdrawEvent has drop, store {
        provider: address,
        amount_x: u128,
        amount_y: u128,
    }

    struct VaultAddLiquidityEvent has drop, store {
        operator: address,
        provider: address,
        amount_x: u128,
        amount_y: u128,
        liquidity: u128,
    }

    struct VaultRemoveLiquidityEvent has drop, store {
        operator: address,
        provider: address,
        liquidity: u128,
        amount_x: u128,
        amount_y: u128,
    }

    struct GrantOperatorEvent has drop, store {
        provider: address,
        operator: address,
    }

    struct RevokeOperatorEvent has drop, store {
        provider: address,
        operator: address,
    }

    // ======================== Provider operations ========================

    /// Create an empty Vault for token pair <X, Y>.
    /// X, Y do not need to be in sorted order -- we always store in canonical order internally.
    public fun create_vault<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);

        // Always create Vault in canonical order (X < Y).
        // If caller passes X > Y, we still store as <X, Y> from caller's perspective
        // but route to sorted order internally.
        if (order == 1) {
            create_vault_internal<X, Y>(provider);
        } else {
            create_vault_internal<Y, X>(provider);
        }
    }

    fun create_vault_internal<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
    ) {
        let addr = Signer::address_of(provider);
        assert!(!exists<Vault<X, Y>>(addr), ERR_VAULT_ALREADY_EXISTS);

        move_to(provider, Vault<X, Y> {
            token_x: Token::zero<X>(),
            token_y: Token::zero<Y>(),
            lp_tokens: Token::zero<TokenSwap::LiquidityToken<X, Y>>(),
            operators: Vector::empty(),
        });

        move_to(provider, VaultEventHandle<X, Y> {
            deposit_event: Event::new_event_handle<DepositEvent>(provider),
            withdraw_event: Event::new_event_handle<WithdrawEvent>(provider),
            add_liquidity_event: Event::new_event_handle<VaultAddLiquidityEvent>(provider),
            remove_liquidity_event: Event::new_event_handle<VaultRemoveLiquidityEvent>(provider),
            grant_event: Event::new_event_handle<GrantOperatorEvent>(provider),
            revoke_event: Event::new_event_handle<RevokeOperatorEvent>(provider),
        });
    }

    /// Provider deposits tokens from their account into the Vault.
    public fun deposit<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
        amount_x: u128,
        amount_y: u128,
    ) acquires Vault, VaultEventHandle {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            deposit_internal<X, Y>(provider, amount_x, amount_y);
        } else {
            deposit_internal<Y, X>(provider, amount_y, amount_x);
        }
    }

    fun deposit_internal<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
        amount_x: u128,
        amount_y: u128,
    ) acquires Vault, VaultEventHandle {
        let addr = Signer::address_of(provider);
        assert!(exists<Vault<X, Y>>(addr), ERR_VAULT_NOT_EXISTS);

        let vault = borrow_global_mut<Vault<X, Y>>(addr);
        if (amount_x > 0) {
            let token_x = Account::withdraw<X>(provider, amount_x);
            Token::deposit(&mut vault.token_x, token_x);
        };
        if (amount_y > 0) {
            let token_y = Account::withdraw<Y>(provider, amount_y);
            Token::deposit(&mut vault.token_y, token_y);
        };

        let event_handle = borrow_global_mut<VaultEventHandle<X, Y>>(addr);
        Event::emit_event(&mut event_handle.deposit_event, DepositEvent {
            provider: addr,
            amount_x,
            amount_y,
        });
    }

    /// Provider withdraws tokens from the Vault back to their own account.
    /// Only the Provider (Vault owner) can call this.
    public fun withdraw<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
        amount_x: u128,
        amount_y: u128,
    ) acquires Vault, VaultEventHandle {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            withdraw_internal<X, Y>(provider, amount_x, amount_y);
        } else {
            withdraw_internal<Y, X>(provider, amount_y, amount_x);
        }
    }

    fun withdraw_internal<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
        amount_x: u128,
        amount_y: u128,
    ) acquires Vault, VaultEventHandle {
        let addr = Signer::address_of(provider);
        assert!(exists<Vault<X, Y>>(addr), ERR_VAULT_NOT_EXISTS);

        let vault = borrow_global_mut<Vault<X, Y>>(addr);
        if (amount_x > 0) {
            assert!(Token::value(&vault.token_x) >= amount_x, ERR_INSUFFICIENT_X);
            let token_x = Token::withdraw(&mut vault.token_x, amount_x);
            Account::deposit(addr, token_x);
        };
        if (amount_y > 0) {
            assert!(Token::value(&vault.token_y) >= amount_y, ERR_INSUFFICIENT_Y);
            let token_y = Token::withdraw(&mut vault.token_y, amount_y);
            Account::deposit(addr, token_y);
        };

        let event_handle = borrow_global_mut<VaultEventHandle<X, Y>>(addr);
        Event::emit_event(&mut event_handle.withdraw_event, WithdrawEvent {
            provider: addr,
            amount_x,
            amount_y,
        });
    }

    /// Provider grants Operator capability to an address.
    /// Two-step process:
    ///   Step 1: Provider calls propose_operator(provider, operator_addr)
    ///   Step 2: Operator calls accept_operator_cap(operator, provider_addr)
    /// This avoids requiring both signers in a single transaction.
    public fun propose_operator<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
        operator_addr: address,
    ) acquires Vault, VaultEventHandle {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            propose_operator_internal<X, Y>(provider, operator_addr);
        } else {
            propose_operator_internal<Y, X>(provider, operator_addr);
        }
    }

    fun propose_operator_internal<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
        operator_addr: address,
    ) acquires Vault, VaultEventHandle {
        let provider_addr = Signer::address_of(provider);
        assert!(exists<Vault<X, Y>>(provider_addr), ERR_VAULT_NOT_EXISTS);

        // Add operator to Vault's operator list (proposal)
        let vault = borrow_global_mut<Vault<X, Y>>(provider_addr);
        assert!(!Vector::contains(&vault.operators, &operator_addr), ERR_OPERATOR_ALREADY_GRANTED);
        Vector::push_back(&mut vault.operators, operator_addr);

        let event_handle = borrow_global_mut<VaultEventHandle<X, Y>>(provider_addr);
        Event::emit_event(&mut event_handle.grant_event, GrantOperatorEvent {
            provider: provider_addr,
            operator: operator_addr,
        });
    }

    /// Operator accepts the capability after provider has proposed them.
    /// Creates OperatorCap under operator's account.
    public fun accept_operator_cap<X: copy + drop + store, Y: copy + drop + store>(
        operator: &signer,
        provider_addr: address,
    ) acquires Vault {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            accept_operator_cap_internal<X, Y>(operator, provider_addr);
        } else {
            accept_operator_cap_internal<Y, X>(operator, provider_addr);
        }
    }

    fun accept_operator_cap_internal<X: copy + drop + store, Y: copy + drop + store>(
        operator: &signer,
        provider_addr: address,
    ) acquires Vault {
        let operator_addr = Signer::address_of(operator);
        assert!(exists<Vault<X, Y>>(provider_addr), ERR_VAULT_NOT_EXISTS);
        assert!(!exists<OperatorCap<X, Y>>(operator_addr), ERR_CAP_ALREADY_EXISTS);

        // Verify operator has been proposed (is in the vault's operator list)
        let vault = borrow_global<Vault<X, Y>>(provider_addr);
        assert!(Vector::contains(&vault.operators, &operator_addr), ERR_NOT_OPERATOR);

        // Move OperatorCap to operator's account
        move_to(operator, OperatorCap<X, Y> {
            provider: provider_addr,
        });
    }

    /// Provider revokes Operator capability.
    /// Must be called by provider. The OperatorCap is removed from operator's account.
    /// NOTE: Since Move doesn't allow removing resources from another account directly,
    /// the operator must cooperate by calling `surrender_operator_cap`, OR
    /// the provider can simply remove the operator from the list (disabling future operations).
    public fun revoke_operator<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
        operator_addr: address,
    ) acquires Vault, VaultEventHandle {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            revoke_operator_internal<X, Y>(provider, operator_addr);
        } else {
            revoke_operator_internal<Y, X>(provider, operator_addr);
        }
    }

    fun revoke_operator_internal<X: copy + drop + store, Y: copy + drop + store>(
        provider: &signer,
        operator_addr: address,
    ) acquires Vault, VaultEventHandle {
        let provider_addr = Signer::address_of(provider);
        assert!(exists<Vault<X, Y>>(provider_addr), ERR_VAULT_NOT_EXISTS);

        // Remove operator from vault's operator list
        let vault = borrow_global_mut<Vault<X, Y>>(provider_addr);
        let (found, idx) = Vector::index_of(&vault.operators, &operator_addr);
        assert!(found, ERR_OPERATOR_NOT_FOUND);
        Vector::swap_remove(&mut vault.operators, idx);

        let event_handle = borrow_global_mut<VaultEventHandle<X, Y>>(provider_addr);
        Event::emit_event(&mut event_handle.revoke_event, RevokeOperatorEvent {
            provider: provider_addr,
            operator: operator_addr,
        });
    }

    /// Operator voluntarily surrenders their capability.
    public fun surrender_operator_cap<X: copy + drop + store, Y: copy + drop + store>(
        operator: &signer,
    ) acquires OperatorCap, Vault, VaultEventHandle {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            surrender_operator_cap_internal<X, Y>(operator);
        } else {
            surrender_operator_cap_internal<Y, X>(operator);
        }
    }

    fun surrender_operator_cap_internal<X: copy + drop + store, Y: copy + drop + store>(
        operator: &signer,
    ) acquires OperatorCap, Vault, VaultEventHandle {
        let operator_addr = Signer::address_of(operator);
        assert!(exists<OperatorCap<X, Y>>(operator_addr), ERR_CAP_NOT_EXISTS);

        let OperatorCap<X, Y> { provider } = move_from<OperatorCap<X, Y>>(operator_addr);

        // Also remove from vault's operator list if still present
        if (exists<Vault<X, Y>>(provider)) {
            let vault = borrow_global_mut<Vault<X, Y>>(provider);
            let (found, idx) = Vector::index_of(&vault.operators, &operator_addr);
            if (found) {
                Vector::swap_remove(&mut vault.operators, idx);
            };

            if (exists<VaultEventHandle<X, Y>>(provider)) {
                let event_handle = borrow_global_mut<VaultEventHandle<X, Y>>(provider);
                Event::emit_event(&mut event_handle.revoke_event, RevokeOperatorEvent {
                    provider,
                    operator: operator_addr,
                });
            };
        };
    }

    // ======================== Operator operations ========================

    /// Operator adds liquidity from Vault funds into the swap pool.
    /// Funds move: Vault -> LP Pool. LP tokens are stored back in Vault.
    /// The Operator never touches the actual tokens.
    public fun add_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        operator: &signer,
        provider_addr: address,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) acquires Vault, OperatorCap, VaultEventHandle {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            add_liquidity_internal<X, Y>(
                operator, provider_addr,
                amount_x_desired, amount_y_desired,
                amount_x_min, amount_y_min,
            );
        } else {
            add_liquidity_internal<Y, X>(
                operator, provider_addr,
                amount_y_desired, amount_x_desired,
                amount_y_min, amount_x_min,
            );
        }
    }

    fun add_liquidity_internal<X: copy + drop + store, Y: copy + drop + store>(
        operator: &signer,
        provider_addr: address,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) acquires Vault, OperatorCap, VaultEventHandle {
        let operator_addr = Signer::address_of(operator);

        // Verify operator is authorized for this provider's vault
        assert_is_operator<X, Y>(operator_addr, provider_addr);

        let vault = borrow_global_mut<Vault<X, Y>>(provider_addr);

        // Calculate optimal amounts (same logic as TokenSwapRouter)
        let (amount_x, amount_y) = calculate_amount_for_liquidity<X, Y>(
            amount_x_desired, amount_y_desired,
            amount_x_min, amount_y_min,
        );

        // Withdraw tokens from Vault
        assert!(Token::value(&vault.token_x) >= amount_x, ERR_INSUFFICIENT_X);
        assert!(Token::value(&vault.token_y) >= amount_y, ERR_INSUFFICIENT_Y);
        let token_x = Token::withdraw(&mut vault.token_x, amount_x);
        let token_y = Token::withdraw(&mut vault.token_y, amount_y);

        // Mint LP tokens using pure TokenSwap::mint (no signer needed!)
        let lp_token = TokenSwap::mint<X, Y>(token_x, token_y);
        let liquidity = Token::value(&lp_token);

        // Store LP tokens back in Vault
        Token::deposit(&mut vault.lp_tokens, lp_token);

        // Emit event
        let event_handle = borrow_global_mut<VaultEventHandle<X, Y>>(provider_addr);
        Event::emit_event(&mut event_handle.add_liquidity_event, VaultAddLiquidityEvent {
            operator: operator_addr,
            provider: provider_addr,
            amount_x: amount_x,
            amount_y: amount_y,
            liquidity,
        });
    }

    /// Operator removes liquidity from the swap pool back to Vault.
    /// Funds move: LP Pool -> Vault. Operator never touches the tokens.
    public fun remove_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        operator: &signer,
        provider_addr: address,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) acquires Vault, OperatorCap, VaultEventHandle {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            remove_liquidity_internal<X, Y>(
                operator, provider_addr,
                liquidity, amount_x_min, amount_y_min,
            );
        } else {
            remove_liquidity_internal<Y, X>(
                operator, provider_addr,
                liquidity, amount_y_min, amount_x_min,
            );
        }
    }

    fun remove_liquidity_internal<X: copy + drop + store, Y: copy + drop + store>(
        operator: &signer,
        provider_addr: address,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) acquires Vault, OperatorCap, VaultEventHandle {
        let operator_addr = Signer::address_of(operator);

        // Verify operator is authorized
        assert_is_operator<X, Y>(operator_addr, provider_addr);

        let vault = borrow_global_mut<Vault<X, Y>>(provider_addr);

        // Withdraw LP tokens from Vault
        assert!(Token::value(&vault.lp_tokens) >= liquidity, ERR_INSUFFICIENT_LP);
        let lp_token = Token::withdraw(&mut vault.lp_tokens, liquidity);

        // Burn LP tokens using pure TokenSwap::burn (no signer needed!)
        let (token_x, token_y) = TokenSwap::burn<X, Y>(lp_token);

        let amount_x = Token::value(&token_x);
        let amount_y = Token::value(&token_y);
        assert!(amount_x >= amount_x_min, ERR_INSUFFICIENT_X);
        assert!(amount_y >= amount_y_min, ERR_INSUFFICIENT_Y);

        // Deposit tokens back to Vault (NOT to operator's account!)
        Token::deposit(&mut vault.token_x, token_x);
        Token::deposit(&mut vault.token_y, token_y);

        // Emit event
        let event_handle = borrow_global_mut<VaultEventHandle<X, Y>>(provider_addr);
        Event::emit_event(&mut event_handle.remove_liquidity_event, VaultRemoveLiquidityEvent {
            operator: operator_addr,
            provider: provider_addr,
            liquidity,
            amount_x,
            amount_y,
        });
    }

    // ======================== Query functions ========================

    /// Check if a vault exists for provider
    public fun vault_exists<X: copy + drop + store, Y: copy + drop + store>(
        provider_addr: address,
    ): bool {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            exists<Vault<X, Y>>(provider_addr)
        } else {
            exists<Vault<Y, X>>(provider_addr)
        }
    }

    /// Get Vault balances: (token_x_balance, token_y_balance, lp_balance)
    public fun vault_balances<X: copy + drop + store, Y: copy + drop + store>(
        provider_addr: address,
    ): (u128, u128, u128) acquires Vault {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            vault_balances_internal<X, Y>(provider_addr)
        } else {
            let (y_bal, x_bal, lp_bal) = vault_balances_internal<Y, X>(provider_addr);
            (x_bal, y_bal, lp_bal)
        }
    }

    fun vault_balances_internal<X: copy + drop + store, Y: copy + drop + store>(
        provider_addr: address,
    ): (u128, u128, u128) acquires Vault {
        assert!(exists<Vault<X, Y>>(provider_addr), ERR_VAULT_NOT_EXISTS);
        let vault = borrow_global<Vault<X, Y>>(provider_addr);
        (
            Token::value(&vault.token_x),
            Token::value(&vault.token_y),
            Token::value(&vault.lp_tokens),
        )
    }

    /// Check if an address is an authorized operator for a provider's vault
    public fun is_operator<X: copy + drop + store, Y: copy + drop + store>(
        operator_addr: address,
        provider_addr: address,
    ): bool acquires Vault {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            is_operator_internal<X, Y>(operator_addr, provider_addr)
        } else {
            is_operator_internal<Y, X>(operator_addr, provider_addr)
        }
    }

    fun is_operator_internal<X: copy + drop + store, Y: copy + drop + store>(
        operator_addr: address,
        provider_addr: address,
    ): bool acquires Vault {
        if (!exists<Vault<X, Y>>(provider_addr)) return false;
        if (!exists<OperatorCap<X, Y>>(operator_addr)) return false;

        let vault = borrow_global<Vault<X, Y>>(provider_addr);
        Vector::contains(&vault.operators, &operator_addr)
    }

    /// Get operator list for a vault
    public fun get_operators<X: copy + drop + store, Y: copy + drop + store>(
        provider_addr: address,
    ): vector<address> acquires Vault {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERR_INVALID_TOKEN_PAIR);
        if (order == 1) {
            get_operators_internal<X, Y>(provider_addr)
        } else {
            get_operators_internal<Y, X>(provider_addr)
        }
    }

    fun get_operators_internal<X: copy + drop + store, Y: copy + drop + store>(
        provider_addr: address,
    ): vector<address> acquires Vault {
        assert!(exists<Vault<X, Y>>(provider_addr), ERR_VAULT_NOT_EXISTS);
        let vault = borrow_global<Vault<X, Y>>(provider_addr);
        *&vault.operators
    }

    // ======================== Internal helpers ========================

    /// Assert that operator_addr is authorized for provider_addr's vault.
    /// Checks both: (1) OperatorCap exists, (2) operator is in vault's list.
    fun assert_is_operator<X: copy + drop + store, Y: copy + drop + store>(
        operator_addr: address,
        provider_addr: address,
    ) acquires Vault, OperatorCap {
        assert!(exists<Vault<X, Y>>(provider_addr), ERR_VAULT_NOT_EXISTS);
        assert!(exists<OperatorCap<X, Y>>(operator_addr), ERR_NOT_OPERATOR);

        // Verify the cap points to the correct provider
        let cap = borrow_global<OperatorCap<X, Y>>(operator_addr);
        assert!(cap.provider == provider_addr, ERR_NOT_OPERATOR);

        // Verify operator is in vault's authorized list (defense in depth)
        let vault = borrow_global<Vault<X, Y>>(provider_addr);
        assert!(Vector::contains(&vault.operators, &operator_addr), ERR_NOT_OPERATOR);
    }

    /// Calculate optimal token amounts for adding liquidity (mirrors TokenSwapRouter logic).
    fun calculate_amount_for_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ): (u128, u128) {
        let (reserve_x, reserve_y) = TokenSwap::get_reserves<X, Y>();
        if (reserve_x == 0 && reserve_y == 0) {
            return (amount_x_desired, amount_y_desired)
        };

        let amount_y_optimal = TokenSwapLibrary::quote(amount_x_desired, reserve_x, reserve_y);
        if (amount_y_optimal <= amount_y_desired) {
            assert!(amount_y_optimal >= amount_y_min, ERR_INSUFFICIENT_Y);
            return (amount_x_desired, amount_y_optimal)
        };

        let amount_x_optimal = TokenSwapLibrary::quote(amount_y_desired, reserve_y, reserve_x);
        assert!(amount_x_optimal <= amount_x_desired, ERR_INSUFFICIENT_X);
        assert!(amount_x_optimal >= amount_x_min, ERR_INSUFFICIENT_X);
        (amount_x_optimal, amount_y_desired)
    }
}