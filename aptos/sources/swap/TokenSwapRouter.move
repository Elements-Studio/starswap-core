// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapRouter {
    use aptos_framework::coin::{Self, Coin};
    use std::signer;
    use std::option;

    use SwapAdmin::TokenSwap::{LiquidityToken, Self};
    use SwapAdmin::U256Wrapper::U256;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapConfig;


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
    public fun swap_pair_exists<X: store, Y: store>(): bool {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwap::swap_pair_exists<X, Y>()
        } else {
            TokenSwap::swap_pair_exists<Y, X>()
        }
    }

    /// Swap token auto accept
    public fun swap_pair_token_auto_accept<Token: store>(signer: &signer) {
        if (! coin::is_account_registered<Token>(signer::address_of(signer))) {
            coin::register<Token>(signer);
        };
    }

    /// Register swap pair by comparing sort
    public fun register_swap_pair<X: store,
                                  Y: store>(signer: &signer) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwap::register_swap_pair<X, Y>(signer);
        } else {
            TokenSwap::register_swap_pair<Y, X>(signer);
        };
    }


    public fun liquidity<X: store,
                         Y: store>(signer: address): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            (coin::balance<LiquidityToken<X, Y>>(signer) as u128)
        } else {
            (coin::balance<LiquidityToken<Y, X>>(signer) as u128)
        }
    }

    public fun total_liquidity<X: store, Y: store>(): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            option::get_with_default(&coin::supply<LiquidityToken<X, Y>>(), 0u128)
        } else {
            option::get_with_default(&coin::supply<LiquidityToken<Y, X>>(), 0u128)
        }
    }

    public fun add_liquidity<X: store, Y: store>(
        signer: &signer,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
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

    fun intra_add_liquidity<X: store, Y: store>(
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
        let x_token = coin::withdraw<X>(signer, (amount_x as u64));
        let y_token = coin::withdraw<Y>(signer, (amount_y as u64));

        let liquidity_token = TokenSwap::mint_and_emit_event<X, Y>(
            signer, x_token, y_token, amount_x_desired, amount_y_desired, amount_x_min, amount_y_min);

        if (!coin::is_account_registered<LiquidityToken<X, Y>>(signer::address_of(signer))) {
            coin::register<LiquidityToken<X, Y>>(signer);
        };

        let liquidity: u128 = (coin::value<LiquidityToken<X, Y>>(&liquidity_token) as u128);
        assert!(liquidity > 0, ERROR_ROUTER_ADD_LIQUIDITY_FAILED);
        coin::deposit(signer::address_of(signer), liquidity_token);
    }

    fun intra_calculate_amount_for_liquidity<X: store, Y: store>(
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
                assert!(amount_y_optimal >= amount_y_min, ERROR_ROUTER_INSUFFICIENT_Y_AMOUNT);
                return (amount_x_desired, amount_y_optimal)
            } else {
                let amount_x_optimal = TokenSwapLibrary::quote(amount_y_desired, reserve_y, reserve_x);
                assert!(amount_x_optimal <= amount_x_desired, ERROR_ROUTER_OVERLIMIT_X_DESIRED);
                assert!(amount_x_optimal >= amount_x_min, ERROR_ROUTER_INSUFFICIENT_X_AMOUNT);
                return (amount_x_optimal, amount_y_desired)
            }
        }
    }

    public fun remove_liquidity<X: store, Y: store>(
        signer: &signer,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            intra_remove_liquidity<X, Y>(signer, liquidity, amount_x_min, amount_y_min);
        } else {
            intra_remove_liquidity<Y, X>(signer, liquidity, amount_y_min, amount_x_min);
        }
    }

    fun intra_remove_liquidity<X: store, Y: store>(
        signer: &signer,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        let liquidity_token = coin::withdraw<LiquidityToken<X, Y>>(signer, (liquidity as u64));
        let (token_x, token_y) = TokenSwap::burn_and_emit_event(signer, liquidity_token, amount_x_min, amount_y_min);
        assert!((coin::value(&token_x) as u128) >= amount_x_min, ERROR_ROUTER_INSUFFICIENT_X_AMOUNT);
        assert!((coin::value(&token_y) as u128) >= amount_y_min, ERROR_ROUTER_INSUFFICIENT_Y_AMOUNT);
        coin::deposit(signer::address_of(signer), token_x);
        coin::deposit(signer::address_of(signer), token_y);
        // TokenSwap::emit_remove_liquidity_event<X, Y>(signer, liquidity, amount_x_min, amount_y_min);
    }

    /// Computer y out value by given x_in and slipper value
    public fun compute_y_out<X: store, Y: store>(amount_x_in: u128): u128 {
        // calculate actual y out
        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<X, Y>();
        let (reserve_x, reserve_y) = get_reserves<X, Y>();
        TokenSwapLibrary::get_amount_out(amount_x_in, reserve_x, reserve_y, fee_numberator, fee_denumerator)
    }

    public fun swap_exact_token_for_token<X: store, Y: store>(
        signer: &signer,
        amount_x_in: u128,
        amount_y_out_min: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);

        // auto accept swap token
        swap_pair_token_auto_accept<Y>(signer);
        // calculate actual y out
        let y_out = compute_y_out<X, Y>(amount_x_in);
        assert!(y_out >= amount_y_out_min, ERROR_ROUTER_Y_OUT_LESSTHAN_EXPECTED);

        // do actual swap
        let token_x = coin::withdraw<X>(signer, (amount_x_in as u64));
        let (token_x_out, token_y_out);
        let (token_x_fee, token_y_fee);
        if (order == 1) {
            (token_x_out, token_y_out, token_x_fee, token_y_fee) = TokenSwap::swap_and_emit_event<X, Y>(signer, token_x, y_out, coin::zero(), 0);
        } else {
            (token_y_out, token_x_out, token_y_fee, token_x_fee) = TokenSwap::swap_and_emit_event<Y, X>(signer, coin::zero(), 0, token_x, y_out);
        };

        coin::destroy_zero(token_x_out);
        coin::deposit(signer::address_of(signer), token_y_out);
        coin::destroy_zero(token_y_fee);

        //handle swap fee
        if (TokenSwapConfig::get_swap_fee_switch()) {
            TokenSwapFee::handle_token_swap_fee<X, Y>(signer::address_of(signer), token_x_fee);
        } else {
            coin::destroy_zero(token_x_fee);
        }
    }

    /// Computer x in value by given y_out and x_in slipper value
    public fun compute_x_in<X: store, Y: store>(amount_y_out: u128) : u128 {
        // calculate actual x in
        let (reserve_x, reserve_y) = get_reserves<X, Y>();
        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<X, Y>();
        TokenSwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y, fee_numberator, fee_denumerator)
    }

    public fun swap_token_for_exact_token<X: store, Y: store>(
        signer: &signer,
        amount_x_in_max: u128,
        amount_y_out: u128,
    ) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);

        // auto accept swap token
        swap_pair_token_auto_accept<Y>(signer);

        // calculate actual x in
        let x_in = compute_x_in<X, Y>(amount_y_out);
        assert!(x_in <= amount_x_in_max, ERROR_ROUTER_X_IN_OVER_LIMIT_MAX);

        // do actual swap
        let token_x = coin::withdraw<X>(signer, (x_in as u64));
        let (token_x_out, token_y_out);
        let (token_x_fee, token_y_fee);
        if (order == 1) {
            (token_x_out, token_y_out, token_x_fee, token_y_fee) =
                TokenSwap::swap<X, Y>(token_x, amount_y_out, coin::zero(), 0);
        } else {
            (token_y_out, token_x_out, token_y_fee, token_x_fee) =
                TokenSwap::swap<Y, X>(coin::zero(), 0, token_x, amount_y_out);
        };
        coin::destroy_zero(token_x_out);
        coin::deposit(signer::address_of(signer), token_y_out);
        coin::destroy_zero(token_y_fee);

        //handle swap fee
        if (TokenSwapConfig::get_swap_fee_switch()) {
            TokenSwapFee::handle_token_swap_fee<X, Y>(signer::address_of(signer), token_x_fee);
        } else {
            coin::destroy_zero(token_x_fee);
        }
    }


    /// Get reserves of a token pair.
    /// The order of `X`, `Y` doesn't need to be sorted.
    /// And the order of return values are based on the order of type parameters.
    public fun get_reserves<X: store, Y: store>(): (u128, u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
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
    public fun get_cumulative_info<X: store, Y: store>(): (U256, U256, u64) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwap::get_cumulative_info<X, Y>()
        } else {
            let (cumulative_y, cumulative_x, last_block_timestamp) = TokenSwap::get_cumulative_info<Y, X>();
            (cumulative_x, cumulative_y, last_block_timestamp)
        }
    }


    /// Withdraw liquidity from users
    public fun withdraw_liquidity_token<X: store, Y: store>(
        signer: &signer,
        amount: u128
    ): Coin<LiquidityToken<X, Y>> {
        let user_liquidity = liquidity<X, Y>(signer::address_of(signer));
        assert!(amount <= user_liquidity, ERROR_ROUTER_WITHDRAW_INSUFFICIENT);

        coin::withdraw<LiquidityToken<X, Y>>(signer, (amount as u64))
    }

    /// Deposit liquidity token into user source list
    public fun deposit_liquidity_token<X: store, Y: store>(
        signer: address,
        to_deposit: Coin<LiquidityToken<X, Y>>
    ) {
        coin::deposit<LiquidityToken<X, Y>>(signer, to_deposit);
    }

    /// Poundage number of liquidity token pair
    public fun get_poundage_rate<X: store,
                                 Y: store>(): (u64, u64) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapConfig::get_poundage_rate<X, Y>()
        } else {
            TokenSwapConfig::get_poundage_rate<Y, X>()
        }
    }
    
    /// Operation number of liquidity token pair
    public fun get_swap_fee_operation_rate_v2<X: store,
                                 Y: store>(): (u64, u64) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapConfig::get_swap_fee_operation_rate_v2<X, Y>()
        } else {
            TokenSwapConfig::get_swap_fee_operation_rate_v2<Y, X>()
        }
    }

    /// Poundage rate from swap fee
    public fun set_poundage_rate<X: store,
                                 Y: store>(signer: &signer, num: u64, denum: u64) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapConfig::set_poundage_rate<X, Y>(signer, num, denum);
        } else {
            TokenSwapConfig::set_poundage_rate<Y, X>(signer, num, denum);
        };
    }

    public entry fun upgrade_tokenpair_to_tokenswappair<X: store,
                                                          Y: store>(signer: signer) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwap::upgrade_tokenpair_to_tokenswappair<X, Y>(&signer);
        } else {
            TokenSwap::upgrade_tokenpair_to_tokenswappair<Y, X>(&signer);
        };
    }

    /// Operation rate from all swap fee
    public fun set_swap_fee_operation_rate(signer: &signer,
                                           num: u64,
                                           denum: u64) {
        TokenSwapConfig::set_swap_fee_operation_rate(signer, num, denum);
    }

    /// Operation_v2 rate from all swap fee
    public fun set_swap_fee_operation_rate_v2<X: store,
                                              Y: store>(signer: &signer,
                                                                      num: u64,
                                                                      denum: u64) {
        TokenSwapConfig::set_swap_fee_operation_rate_v2<X, Y>(signer, num, denum);
    }    

    /// Set fee auto convert switch config
    public fun set_fee_auto_convert_switch(signer: &signer, auto_convert_switch: bool) {
        TokenSwapConfig::set_fee_auto_convert_switch(signer, auto_convert_switch);
    }

    /// Set global freeze switch
    public fun set_global_freeze_switch(signer: &signer, freeze: bool) {
        TokenSwapConfig::set_global_freeze_switch(signer, freeze);
    }

    /// Set alloc mode upgrade switch
    public fun set_alloc_mode_upgrade_switch(signer: &signer, upgrade_switch: bool) {
        TokenSwapConfig::set_alloc_mode_upgrade_switch(signer, upgrade_switch);
    }

    /// Set white list boost switch
    public fun set_white_list_boost_switch(signer: &signer, white_list_switch: bool, white_list_pubkey:vector<u8>){
        TokenSwapConfig::set_white_list_boost_switch(signer, white_list_switch,white_list_pubkey);
    }
}