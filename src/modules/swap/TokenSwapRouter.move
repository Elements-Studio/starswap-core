// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module TokenSwapRouter {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwap::{LiquidityToken, Self};
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Token;
    use 0x1::U256::U256;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFee;

    const ERROR_ROUTER_PARAMETER_INVALID: u64 = 1001;
    const ERROR_ROUTER_INSUFFICIENT_X_AMOUNT: u64 = 1002;
    const ERROR_ROUTER_INSUFFICIENT_Y_AMOUNT: u64 = 1003;
    const ERROR_ROUTER_INVALID_TOKEN_PAIR: u64 = 1004;
    const ERROR_ROUTER_OVERLIMIT_X_DESIRED: u64 = 1005;
    const ERROR_ROUTER_Y_OUT_LESSTHAN_EXPECTED: u64 = 1006;
    const ERROR_ROUTER_X_IN_OVER_LIMIT_MAX: u64 = 1007;
    const ERROR_ROUTER_ADD_LIQUIDITY_FAILED: u64 = 1008;
    const ERROR_ROUTER_WITHDRAW_INSUFFICIENT: u64 = 1009;
    const ERROR_ROUTER_SWAP_ROUTER_PAIR_INVALID: u64 = 1010;


    ///swap router depth
    const ROUTER_SWAP_ROUTER_DEPTH_ONE: u64 = 1;
    const ROUTER_SWAP_ROUTER_DEPTH_TWO: u64 = 2;
    const ROUTER_SWAP_ROUTER_DEPTH_THREE: u64 = 3;


    /// Check if swap pair exists
    public fun swap_pair_exists<X: copy + drop + store, Y: copy + drop + store>(): bool {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwap::swap_pair_exists<X, Y>()
        } else {
            TokenSwap::swap_pair_exists<Y, X>()
        }
    }

    /// Swap token auto accept
    public fun swap_pair_token_auto_accept<Token: store>(signer: &signer) {
        if (!Account::is_accepts_token<Token>(Signer::address_of(signer))) {
            Account::do_accept_token<Token>(signer);
        };
    }

    /// Register swap pair by comparing sort
    public fun register_swap_pair<X: copy + drop + store,
                                  Y: copy + drop + store>(account: &signer) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwap::register_swap_pair<X, Y>(account);
        } else {
            TokenSwap::register_swap_pair<Y, X>(account);
        };
    }


    public fun liquidity<X: copy + drop + store,
                         Y: copy + drop + store>(account: address): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            Account::balance<LiquidityToken<X, Y>>(account)
        } else {
            Account::balance<LiquidityToken<Y, X>>(account)
        }
    }

    public fun total_liquidity<X: copy + drop + store, Y: copy + drop + store>(): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            Token::market_cap<LiquidityToken<X, Y>>()
        } else {
            Token::market_cap<LiquidityToken<Y, X>>()
        }
    }

    public fun add_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            intra_add_liquidity<X, Y>(
                signer,
                amount_x_desired,
                amount_y_desired,
                amount_x_min,
                amount_y_min,
            );
        } else {
            intra_add_liquidity<Y, X>(
                signer,
                amount_y_desired,
                amount_x_desired,
                amount_y_min,
                amount_x_min,
            );
        }
    }

    fun intra_add_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        let (amount_x, amount_y) = intra_calculate_amount_for_liquidity<X, Y>(
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min,
        );
        let x_token = Account::withdraw<X>(signer, amount_x);
        let y_token = Account::withdraw<Y>(signer, amount_y);

        let liquidity_token = TokenSwap::mint<X, Y>(x_token, y_token);
        if (!Account::is_accepts_token<LiquidityToken<X, Y>>(Signer::address_of(signer))) {
            Account::do_accept_token<LiquidityToken<X, Y>>(signer);
        };

        // emit liquidity event
        let liquidity: u128 = Token::value<LiquidityToken<X, Y>>(&liquidity_token);
        assert(liquidity > 0, ERROR_ROUTER_ADD_LIQUIDITY_FAILED);
        Account::deposit(Signer::address_of(signer), liquidity_token);
        TokenSwap::emit_add_liquidity_event<X, Y>(signer, liquidity, amount_x_desired, amount_y_desired, amount_x_min, amount_y_min);
    }

    fun intra_calculate_amount_for_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ): (u128, u128) {
        let (reserve_x, reserve_y) = get_reserves<X, Y>();
        if (reserve_x == 0 && reserve_y == 0) {
            return (amount_x_desired, amount_y_desired)
        } else {
            let amount_y_optimal = TokenSwapLibrary::quote(amount_x_desired, reserve_x, reserve_y);
            if (amount_y_optimal <= amount_y_desired) {
                assert(amount_y_optimal >= amount_y_min, ERROR_ROUTER_INSUFFICIENT_Y_AMOUNT);
                return (amount_x_desired, amount_y_optimal)
            } else {
                let amount_x_optimal = TokenSwapLibrary::quote(amount_y_desired, reserve_y, reserve_x);
                assert(amount_x_optimal <= amount_x_desired, ERROR_ROUTER_OVERLIMIT_X_DESIRED);
                assert(amount_x_optimal >= amount_x_min, ERROR_ROUTER_INSUFFICIENT_X_AMOUNT);
                return (amount_x_optimal, amount_y_desired)
            }
        }
    }

    public fun remove_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            intra_remove_liquidity<X, Y>(signer, liquidity, amount_x_min, amount_y_min);
        } else {
            intra_remove_liquidity<Y, X>(signer, liquidity, amount_y_min, amount_x_min);
        }
    }

    fun intra_remove_liquidity<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        let liquidity_token = Account::withdraw<LiquidityToken<X, Y>>(signer, liquidity);
        let (token_x, token_y) = TokenSwap::burn(liquidity_token);
        assert(Token::value(&token_x) >= amount_x_min, ERROR_ROUTER_INSUFFICIENT_X_AMOUNT);
        assert(Token::value(&token_y) >= amount_y_min, ERROR_ROUTER_INSUFFICIENT_Y_AMOUNT);
        Account::deposit(Signer::address_of(signer), token_x);
        Account::deposit(Signer::address_of(signer), token_y);
        TokenSwap::emit_remove_liquidity_event<X, Y>(signer, liquidity, amount_x_min, amount_y_min);
    }

    public fun swap_exact_token_for_token<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        amount_x_in: u128,
        amount_y_out_min: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);

        // auto accept swap token
        swap_pair_token_auto_accept<Y>(signer);
        // calculate actual y out
        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<X, Y>();
        let (reserve_x, reserve_y) = get_reserves<X, Y>();
        let y_out = TokenSwapLibrary::get_amount_out(amount_x_in, reserve_x, reserve_y, fee_numberator, fee_denumerator);
        assert(y_out >= amount_y_out_min, ERROR_ROUTER_Y_OUT_LESSTHAN_EXPECTED);

        // do actual swap
        let token_x = Account::withdraw<X>(signer, amount_x_in);
        let (token_x_out, token_y_out);
        let (token_x_fee, token_y_fee);
        if (order == 1) {
            (token_x_out, token_y_out, token_x_fee, token_y_fee) = TokenSwap::swap<X, Y>(token_x, y_out, Token::zero(), 0);
            TokenSwap::emit_swap_event<X, Y>(signer, amount_x_in, y_out);
        } else {
            (token_y_out, token_x_out, token_y_fee, token_x_fee) = TokenSwap::swap<Y, X>(Token::zero(), 0, token_x, y_out);
            TokenSwap::emit_swap_event<Y, X>(signer, amount_x_in, y_out);
        };
        Token::destroy_zero(token_x_out);
        Account::deposit(Signer::address_of(signer), token_y_out);
        Token::destroy_zero(token_y_fee);

        //handle swap fee
        if (TokenSwap::get_swap_fee_switch()) {
            TokenSwapFee::handle_token_swap_fee<X, Y>(Signer::address_of(signer), token_x_fee);
        } else {
            Token::destroy_zero(token_x_fee);
        }
    }

    public fun swap_token_for_exact_token<X: copy + drop + store, Y: copy + drop + store>(
        signer: &signer,
        amount_x_in_max: u128,
        amount_y_out: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);

        // auto accept swap token
        swap_pair_token_auto_accept<Y>(signer);

        // calculate actual x in
        let (reserve_x, reserve_y) = get_reserves<X, Y>();
        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<X, Y>();
        let x_in = TokenSwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y, fee_numberator, fee_denumerator);
        assert(x_in <= amount_x_in_max, ERROR_ROUTER_X_IN_OVER_LIMIT_MAX);

        // do actual swap
        let token_x = Account::withdraw<X>(signer, x_in);
        let (token_x_out, token_y_out);
        let (token_x_fee, token_y_fee);
        if (order == 1) {
            (token_x_out, token_y_out, token_x_fee, token_y_fee) =
                TokenSwap::swap<X, Y>(token_x, amount_y_out, Token::zero(), 0);
            TokenSwap::emit_swap_event<X, Y>(signer, x_in, amount_y_out);
        } else {
            (token_y_out, token_x_out, token_y_fee, token_x_fee) =
                TokenSwap::swap<Y, X>(Token::zero(), 0, token_x, amount_y_out);
            TokenSwap::emit_swap_event<Y, X>(signer, x_in, amount_y_out);
        };
        Token::destroy_zero(token_x_out);
        Account::deposit(Signer::address_of(signer), token_y_out);
        Token::destroy_zero(token_y_fee);

        //handle swap fee
        if (TokenSwap::get_swap_fee_switch()) {
            TokenSwapFee::handle_token_swap_fee<X, Y>(Signer::address_of(signer), token_x_fee);
        } else {
            Token::destroy_zero(token_x_fee);
        }
    }


    /// Get reserves of a token pair.
    /// The order of `X`, `Y` doesn't need to be sorted.
    /// And the order of return values are based on the order of type parameters.
    public fun get_reserves<X: copy + drop + store, Y: copy + drop + store>(): (u128, u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwap::get_reserves<X, Y>()
        } else {
            let (y, x) = TokenSwap::get_reserves<Y, X>();
            (x, y)
        }
    }

    /// Get cumulative info of a token pair.
    /// The order of `X`, `Y` doesn't need to be sorted.
    /// And the order of return values are based on the order of type parameters.
    public fun get_cumulative_info<X: copy + drop + store, Y: copy + drop + store>(): (U256, U256, u64) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwap::get_cumulative_info<X, Y>()
        } else {
            let (cumulative_y, cumulative_x, last_block_timestamp) = TokenSwap::get_cumulative_info<Y, X>();
            (cumulative_x, cumulative_y, last_block_timestamp)
        }
    }


    /// Withdraw liquidity from users
    public fun withdraw_liquidity_token<X: copy + drop + store, Y: copy + drop + store>(
        account: &signer,
        amount: u128
    ): Token::Token<LiquidityToken<X, Y>> {
        let user_liquidity = liquidity<X, Y>(Signer::address_of(account));
        assert(amount <= user_liquidity, ERROR_ROUTER_WITHDRAW_INSUFFICIENT);

        Account::withdraw<LiquidityToken<X, Y>>(account, amount)
    }

    /// Deposit liquidity token into user source list
    public fun deposit_liquidity_token<X: copy + drop + store, Y: copy + drop + store>(
        account: address,
        to_deposit: Token::Token<LiquidityToken<X, Y>>
    ) {
        Account::deposit<LiquidityToken<X, Y>>(account, to_deposit);
    }

    /// Poundage number of liquidity token pair
    public fun get_poundage_rate<X: copy + drop + store,
                                 Y: copy + drop + store>(): (u64, u64) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapConfig::get_poundage_rate<X, Y>()
        } else {
            TokenSwapConfig::get_poundage_rate<Y, X>()
        }
    }

    /// Poundage rate from swap fee
    public fun set_poundage_rate<X: copy + drop + store,
                                 Y: copy + drop + store>(signer: &signer, num: u64, denum: u64) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapConfig::set_poundage_rate<X, Y>(signer, num, denum);
        } else {
            TokenSwapConfig::set_poundage_rate<Y, X>(signer, num, denum);
        };
    }

    /// Operation rate from all swap fee
    public fun set_swap_fee_operation_rate(signer: &signer,
                                           num: u64,
                                           denum: u64) {
        TokenSwapConfig::set_swap_fee_operation_rate(signer, num, denum);
    }
}
}