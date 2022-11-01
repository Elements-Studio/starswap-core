// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapScripts {
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapRouter2;
    use SwapAdmin::TokenSwapRouter3;

    /// register swap for admin user
    public entry fun register_swap_pair<X, Y>(account: &signer) {
        TokenSwapRouter::register_swap_pair<X, Y>(account);
    }

    /// Add liquidity for user
    public entry fun add_liquidity<X, Y>(
        signer: &signer,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128) {
        TokenSwapRouter::add_liquidity<X, Y>(
            signer,
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min);
    }

    /// Remove liquidity for user
    public entry fun remove_liquidity<X, Y>(
        signer: &signer,
        liquidity: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    ) {
        TokenSwapRouter::remove_liquidity<X, Y>(
            signer, liquidity, amount_x_min, amount_y_min);
    }

    /// Poundage number of liquidity token pair
    public fun get_poundage_rate<X, Y>(): (u64, u64) {
        TokenSwapRouter::get_poundage_rate<X, Y>()
    }

    public entry fun swap_exact_token_for_token<X, Y>(
        signer: &signer,
        amount_x_in: u128,
        amount_y_out_min: u128,
    ) {
        TokenSwapRouter::swap_exact_token_for_token<X, Y>(signer, amount_x_in, amount_y_out_min);
    }

    public entry fun swap_exact_token_for_token_router2<X, R, Y>(
        signer: &signer,
        amount_x_in: u128,
        amount_y_out_min: u128,
    ) {
        TokenSwapRouter2::swap_exact_token_for_token<X, R, Y>(signer, amount_x_in, amount_y_out_min);
    }

    public entry fun swap_exact_token_for_token_router3<X, R, T, Y>(
        signer: &signer,
        amount_x_in: u128,
        amount_y_out_min: u128,
    ) {
        TokenSwapRouter3::swap_exact_token_for_token<X, R, T, Y>(signer, amount_x_in, amount_y_out_min);
    }

    public entry fun swap_token_for_exact_token<X, Y>(
        signer: &signer,
        amount_x_in_max: u128,
        amount_y_out: u128,
    ) {
        TokenSwapRouter::swap_token_for_exact_token<X, Y>(signer, amount_x_in_max, amount_y_out);
    }

    public entry fun swap_token_for_exact_token_router2<X, R, Y>(
        signer: &signer,
        amount_x_in_max: u128,
        amount_y_out: u128,
    ) {
        TokenSwapRouter2::swap_token_for_exact_token<X, R, Y>(signer, amount_x_in_max, amount_y_out);
    }

    public entry fun swap_token_for_exact_token_router3<X, R, T, Y>(
        signer: &signer,
        amount_x_in_max: u128,
        amount_y_out: u128,
    ) {
        TokenSwapRouter3::swap_token_for_exact_token<X, R, T, Y>(signer, amount_x_in_max, amount_y_out);
    }

    /// Poundage rate from swap fee
    public entry fun set_poundage_rate<X, Y>(signer: &signer, num: u64, denum: u64) {
        TokenSwapRouter::set_poundage_rate<X, Y>(signer, num, denum);
    }

    /// Operation rate from all swap fee
    public entry fun set_swap_fee_operation_rate(signer: &signer, num: u64, denum: u64) {
        TokenSwapRouter::set_swap_fee_operation_rate(signer, num, denum);
    }

    /// Operation_v2 rate from all swap fee
    public entry fun set_swap_fee_operation_rate_v2<X, Y>(signer: &signer,
                                                          num: u64,
                                                          denum: u64) {
        TokenSwapRouter::set_swap_fee_operation_rate_v2<X, Y>(signer, num, denum);
    }

    /// Set fee auto convert switch config
    public entry fun set_fee_auto_convert_switch(signer: &signer, auto_convert_switch: bool) {
        TokenSwapRouter::set_fee_auto_convert_switch(signer, auto_convert_switch);
    }

    /// Set global freeze switch
    public entry fun set_global_freeze_switch(signer: &signer, freeze: bool) {
        TokenSwapRouter::set_global_freeze_switch(signer, freeze);
    }


    /// Get amount in with token pair pondage rate
    public fun get_amount_in<X, Y>(x_value: u128): u128 {
        let (reserve_x, reverse_y) = TokenSwapRouter::get_reserves<X, Y>();
        let (fee_numberator, fee_denumerator) = TokenSwapRouter::get_poundage_rate<X, Y>();
        TokenSwapLibrary::get_amount_in(x_value, reserve_x, reverse_y, fee_numberator, fee_denumerator)
    }

    /// Get amount out with token pair pondage rate
    public fun get_amount_out<X, Y>(x_in_value: u128): u128 {
        let (reserve_x, reverse_y) = TokenSwapRouter::get_reserves<X, Y>();
        let (fee_numberator, fee_denumerator) = TokenSwapRouter::get_poundage_rate<X, Y>();
        TokenSwapLibrary::get_amount_out(x_in_value, reserve_x, reverse_y, fee_numberator, fee_denumerator)
    }
}