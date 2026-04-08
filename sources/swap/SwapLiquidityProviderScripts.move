// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

/// Entry function wrappers for SwapLiquidityProvider.
/// These can be called via `account execute-function`.

module SwapAdmin::SwapLiquidityProviderScripts {
    use SwapAdmin::SwapLiquidityProvider;

    // ======================== Provider entry functions ========================

    /// Create a vault for token pair <X, Y>
    public entry fun create_vault<X: copy + drop + store, Y: copy + drop + store>(
        provider: signer,
    ) {
        SwapLiquidityProvider::create_vault<X, Y>(&provider);
    }

    /// Provider deposits tokens into the vault
    public entry fun deposit<X: copy + drop + store, Y: copy + drop + store>(
        provider: signer,
        amount_x: u128,
        amount_y: u128,
    ) {
        SwapLiquidityProvider::deposit<X, Y>(&provider, amount_x, amount_y);
    }

    /// Provider withdraws tokens from the vault
    public entry fun withdraw<X: copy + drop + store, Y: copy + drop + store>(
        provider: signer,
        amount_x: u128,
        amount_y: u128,
    ) {
        SwapLiquidityProvider::withdraw<X, Y>(&provider, amount_x, amount_y);
    }

    /// Provider proposes an operator (step 1 of 2-step grant)
    public entry fun propose_operator<X: copy + drop + store, Y: copy + drop + store>(
        provider: signer,
        operator_addr: address,
    ) {
        SwapLiquidityProvider::propose_operator<X, Y>(&provider, operator_addr);
    }

    /// Operator accepts the capability after being proposed (step 2 of 2-step grant)
    public entry fun accept_operator_cap<X: copy + drop + store, Y: copy + drop + store>(
        operator: signer,
        provider_addr: address,
    ) {
        SwapLiquidityProvider::accept_operator_cap<X, Y>(&operator, provider_addr);
    }

    /// Provider revokes an operator (removes from list; operator's OperatorCap
    /// becomes inoperative but stays in their account until they surrender it)
    public entry fun revoke_operator<X: copy + drop + store, Y: copy + drop + store>(
        provider: signer,
        operator_addr: address,
    ) {
        SwapLiquidityProvider::revoke_operator<X, Y>(&provider, operator_addr);
    }

    /// Operator surrenders their capability
    public entry fun surrender_operator_cap<X: copy + drop + store, Y: copy + drop + store>(
        operator: signer,
    ) {
        SwapLiquidityProvider::surrender_operator_cap<X, Y>(&operator);
    }

    // ======================== Operator entry functions ========================

    /// Operator adds liquidity from a provider's vault into the swap pool
    public entry fun add_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        operator: signer,
        provider_addr: address,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        SwapLiquidityProvider::add_liquidity<X, Y>(
            &operator, provider_addr,
            amount_x_desired, amount_y_desired,
            amount_x_min, amount_y_min,
        );
    }

    /// Operator removes liquidity from the swap pool back to provider's vault
    public entry fun remove_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        operator: signer,
        provider_addr: address,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        SwapLiquidityProvider::remove_liquidity<X, Y>(
            &operator, provider_addr,
            liquidity, amount_x_min, amount_y_min,
        );
    }
}
