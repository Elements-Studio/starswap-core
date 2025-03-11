// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

/// Token Swap
module swap_admin::TokenSwap {

    use std::option;
    use std::signer;
    use std::string;
    use starcoin_std::type_info::type_name;

    use starcoin_framework::coin;
    use starcoin_framework::event;
    use starcoin_framework::timestamp;
    use starcoin_std::comparator;
    use starcoin_std::debug;
    use starcoin_std::type_info;

    use swap_admin::FixedPoint128;
    use swap_admin::SafeMath;
    use swap_admin::TokenSwapConfig;

    struct LiquidityToken<phantom X, phantom Y> has key, store, copy, drop {}

    struct LiquidityTokenCapability<phantom X, phantom Y> has key, store {
        mint: coin::MintCapability<LiquidityToken<X, Y>>,
        burn: coin::BurnCapability<LiquidityToken<X, Y>>,
        freeze: coin::FreezeCapability<LiquidityToken<X, Y>>,
    }

    // event emitted when add token pair register.
    #[event]
    struct RegisterEvent has drop, store {
        /// token code of X type
        x_token_code: string::String,
        /// token code of X type
        y_token_code: string::String,
        /// signer of token pair register
        signer: address,
    }

    // event emitted when add token liquidity.
    #[event]
    struct AddLiquidityEvent has drop, store {
        /// liquidity value by user X and Y type
        liquidity: u128,
        /// token code of X type
        x_token_code: string::String,
        /// token code of X type
        y_token_code: string::String,
        /// signer of add liquidity
        signer: address,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128,
    }

    // event emitted when remove token liquidity.
    #[event]
    struct RemoveLiquidityEvent has drop, store {
        /// liquidity value by user X and Y type
        liquidity: u128,
        /// token code of X type
        x_token_code: string::String,
        /// token code of X type
        y_token_code: string::String,
        /// signer of remove liquidity
        signer: address,
        amount_x_min: u128,
        amount_y_min: u128,
    }

    // event emitted when token swap.
    #[event]
    struct SwapEvent has drop, store {
        /// token code of X type
        x_token_code: string::String,
        /// token code of X type
        y_token_code: string::String,
        x_in: u128,
        y_out: u128,
        signer: address,
    }


    // Struct for swap pair
    #[event]
    struct TokenSwapPair<phantom X, phantom Y> has key, store {
        token_x_reserve: coin::Coin<X>,
        token_y_reserve: coin::Coin<Y>,
        last_block_timestamp: u64,
        last_price_x_cumulative: u256,
        last_price_y_cumulative: u256,
        last_k: u256,
    }

    const ERROR_SWAP_INVALID_TOKEN_PAIR: u64 = 2000;
    const ERROR_SWAP_INVALID_PARAMETER: u64 = 2001;
    const ERROR_SWAP_TOKEN_INSUFFICIENT: u64 = 2002;
    const ERROR_SWAP_DUPLICATE_TOKEN: u64 = 2003;
    const ERROR_SWAP_BURN_CALC_INVALID: u64 = 2004;
    const ERROR_SWAP_SWAPOUT_CALC_INVALID: u64 = 2005;
    const ERROR_SWAP_PRIVILEGE_INSUFFICIENT: u64 = 2006;
    const ERROR_SWAP_ADDLIQUIDITY_INVALID: u64 = 2007;
    const ERROR_SWAP_TOKEN_NOT_EXISTS: u64 = 2008;
    const ERROR_SWAP_TOKEN_FEE_INVALID: u64 = 2009;

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const LIQUIDITY_TOKEN_SCALE: u8 = 9;


    /// Check if swap pair exists
    public fun swap_pair_exists<X, Y>(): bool {
        let order = compare_token<X, Y>();
        assert!(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);
        coin::is_coin_initialized<LiquidityToken<X, Y>>() &&
            exists<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address())
    }

    // for now, only admin can register token pair
    public fun register_swap_pair<X, Y>(swap_admin: &signer) {
        debug::print(&string::utf8(b"swap_admin::TokenSwap::register_swap_pair | entered"));
        assert_swap_admin(swap_admin);

        // check X,Y is token.
        assert_is_token<X>();
        assert_is_token<Y>();

        let order = compare_token<X, Y>();
        assert!(order != 0, ERROR_SWAP_INVALID_TOKEN_PAIR);

        // Step 1:  Register TokenSwapPair
        assert!(!exists<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address()), ERROR_SWAP_DUPLICATE_TOKEN);
        debug::print(&type_name<TokenSwapPair<X, Y>>());
        move_to(swap_admin, TokenSwapPair<X, Y> {
            token_x_reserve: coin::zero<X>(),
            token_y_reserve: coin::zero<Y>(),
            last_block_timestamp: 0,
            last_price_x_cumulative: 0,
            last_price_y_cumulative: 0,
            last_k: 0,
        });

        // Step 2: Register coin::Coin<LiquidityToken<X, Y>>
        let (
            burn_cap,
            freeze_cap,
            mint_cap
        ) = coin::initialize<LiquidityToken<X, Y>>(
            swap_admin,
            coin_pair_name<X, Y>(),
            coin_pair_symbol<X, Y>(),
            LIQUIDITY_TOKEN_SCALE,
            true,
        );
        move_to(swap_admin, LiquidityTokenCapability { mint: mint_cap, burn: burn_cap, freeze: freeze_cap });

        // Step 3: Emit register event
        event::emit(RegisterEvent {
            x_token_code: type_info::type_name<X>(),
            y_token_code: type_info::type_name<Y>(),
            signer: signer::address_of(swap_admin),
        });

        debug::print(&string::utf8(b"swap_admin::TokenSwap::register_swap_pair | exited"));
    }

    public fun coin_pair_symbol<X, Y>(): string::String {
        let x_name = coin::symbol<X>();
        let y_name = coin::symbol<Y>();
        let ret = copy x_name;
        string::append(&mut ret, string::utf8(b"::"));
        string::append(&mut ret, y_name);
        ret
    }

    public fun coin_pair_name<X, Y>(): string::String {
        let x_name = coin::name<X>();
        let y_name = coin::name<Y>();
        let ret = string::utf8(b"L<");
        string::append(&mut ret, x_name);
        string::append(&mut ret, string::utf8(b","));
        string::append(&mut ret, y_name);
        string::append(&mut ret, string::utf8(b">"));
        ret
    }

    /// Liquidity Provider's methods
    /// type args, X, Y should be sorted.
    public fun mint<X, Y>(
        x: coin::Coin<X>,
        y: coin::Coin<Y>,
    ): coin::Coin<LiquidityToken<X, Y>> acquires TokenSwapPair, LiquidityTokenCapability {
        TokenSwapConfig::assert_global_freeze();

        let total_supply: u128 = option::destroy_some(coin::supply<LiquidityToken<X, Y>>());
        let (x_reserve, y_reserve) = get_reserves<X, Y>();
        let x_value = (coin::value<X>(&x) as u128);
        let y_value = (coin::value<Y>(&y) as u128);
        let liquidity = if (total_supply == 0) {
            // 1000 is the MINIMUM_LIQUIDITY
            // sqrt(x*y) - 1000
            SafeMath::sqrt_u256(SafeMath::mul_u128(x_value, y_value)) - 1000
        } else {
            let x_liquidity = SafeMath::safe_mul_div_u128(x_value, total_supply, x_reserve);
            let y_liquidity = SafeMath::safe_mul_div_u128(y_value, total_supply, y_reserve);
            // use smaller one.
            if (x_liquidity < y_liquidity) {
                x_liquidity
            } else {
                y_liquidity
            }
        };
        assert!(liquidity > 0, ERROR_SWAP_ADDLIQUIDITY_INVALID);
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        coin::merge(&mut token_pair.token_x_reserve, x);
        coin::merge(&mut token_pair.token_y_reserve, y);
        let liquidity_cap = borrow_global<LiquidityTokenCapability<X, Y>>(TokenSwapConfig::admin_address());
        let mint_token = coin::mint((liquidity as u64), &liquidity_cap.mint, );
        update_oracle<X, Y>(x_reserve, y_reserve);
        // emit_mint_event<X, Y>(x_value, y_value, liquidity);

        mint_token
    }


    public fun burn<X, Y>(
        to_burn: coin::Coin<LiquidityToken<X, Y>>,
    ): (coin::Coin<X>, coin::Coin<Y>) acquires TokenSwapPair, LiquidityTokenCapability {
        TokenSwapConfig::assert_global_freeze();

        let to_burn_value = (coin::value(&to_burn) as u128);
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        let x_reserve = (coin::value(&token_pair.token_x_reserve) as u128);
        let y_reserve = (coin::value(&token_pair.token_y_reserve) as u128);
        let total_supply = option::destroy_some(coin::supply<LiquidityToken<X, Y>>());
        let x = SafeMath::safe_mul_div_u128(to_burn_value, x_reserve, total_supply);
        let y = SafeMath::safe_mul_div_u128(to_burn_value, y_reserve, total_supply);
        assert!(x > 0 && y > 0, ERROR_SWAP_BURN_CALC_INVALID);
        burn_liquidity<X, Y>(to_burn);

        let x_token = coin::extract(&mut token_pair.token_x_reserve, (x as u64));
        let y_token = coin::extract(&mut token_pair.token_y_reserve, (y as u64));
        update_oracle<X, Y>(x_reserve, y_reserve);
        // emit_burn_event<X, Y>(x, y, to_burn_value);
        (x_token, y_token)
    }


    fun burn_liquidity<X, Y>(
        to_burn: coin::Coin<LiquidityToken<X, Y>>
    ) acquires LiquidityTokenCapability {
        let liquidity_cap = borrow_global<LiquidityTokenCapability<X, Y>>(TokenSwapConfig::admin_address());
        coin::burn<LiquidityToken<X, Y>>(to_burn, &liquidity_cap.burn);
    }

    /// Get reserves of a token pair.
    /// The order of type args should be sorted.
    public fun get_reserves<X, Y>(): (u128, u128) acquires TokenSwapPair {
        let token_pair = borrow_global<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        let x_reserve = (coin::value(&token_pair.token_x_reserve) as u128);
        let y_reserve = (coin::value(&token_pair.token_y_reserve) as u128);
        //        let last_block_timestamp = token_pair.last_block_timestamp;
        (x_reserve, y_reserve)
    }

    /// Get cumulative info of a token pair.
    /// The order of type args should be sorted.
    public fun get_cumulative_info<X, Y>(): (u256, u256, u64) acquires TokenSwapPair {
        let token_pair = borrow_global<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        let last_price_x_cumulative = *&token_pair.last_price_x_cumulative;
        let last_price_y_cumulative = *&token_pair.last_price_y_cumulative;
        let last_block_timestamp = token_pair.last_block_timestamp;
        (last_price_x_cumulative, last_price_y_cumulative, last_block_timestamp)
    }

    public fun swap<X, Y>(
        x_in: coin::Coin<X>,
        y_out: u128,
        y_in: coin::Coin<Y>,
        x_out: u128,
    ): (coin::Coin<X>, coin::Coin<Y>, coin::Coin<X>, coin::Coin<Y>) acquires TokenSwapPair {
        TokenSwapConfig::assert_global_freeze();

        let x_in_value = (coin::value(&x_in) as u128);
        let y_in_value = (coin::value(&y_in) as u128);
        assert!(x_in_value > 0 || y_in_value > 0, ERROR_SWAP_TOKEN_INSUFFICIENT);
        let (x_reserve, y_reserve) = get_reserves<X, Y>();
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        coin::merge(&mut token_pair.token_x_reserve, x_in);
        coin::merge(&mut token_pair.token_y_reserve, y_in);
        let x_swapped = coin::extract(&mut token_pair.token_x_reserve, (x_out as u64));
        let y_swapped = coin::extract(&mut token_pair.token_y_reserve, (y_out as u64));
        {
            let x_reserve_new = (coin::value(&token_pair.token_x_reserve) as u128);
            let y_reserve_new = (coin::value(&token_pair.token_y_reserve) as u128);
            let (x_adjusted, y_adjusted);
            let (fee_numerator, fee_denominator) = TokenSwapConfig::get_poundage_rate<X, Y>();
            //                x_adjusted = x_reserve_new * 1000 - x_in_value * 3;
            //                y_adjusted = y_reserve_new * 1000 - y_in_value * 3;
            x_adjusted = x_reserve_new * (fee_denominator as u128) - x_in_value * (fee_numerator as u128);
            y_adjusted = y_reserve_new * (fee_denominator as u128) - y_in_value * (fee_numerator as u128);
            // x_adjusted, y_adjusted >= x_reserve, y_reserve * 1000000
            let cmp_order = SafeMath::safe_compare_mul_u128(x_adjusted, y_adjusted, x_reserve, y_reserve * 1000000);
            assert!((EQUAL == cmp_order || GREATER_THAN == cmp_order), ERROR_SWAP_SWAPOUT_CALC_INVALID);
        };

        let (x_swap_fee, y_swap_fee);
        // cacl and handle swap fee, default fee rate is 3/1000
        if (TokenSwapConfig::get_swap_fee_switch()) {
            let (actual_fee_operation_numerator, actual_fee_operation_denominator) =
                cacl_actual_swap_fee_operation_rate<X, Y>();

            let x_swap_fee_amount = SafeMath::safe_mul_div_u128(
                x_in_value,
                actual_fee_operation_numerator,
                actual_fee_operation_denominator
            );

            let y_swap_fee_amount = SafeMath::safe_mul_div_u128(
                y_in_value,
                actual_fee_operation_numerator,
                actual_fee_operation_denominator
            );

            x_swap_fee = coin::extract(
                &mut token_pair.token_x_reserve,
                (x_swap_fee_amount as u64),
            );
            y_swap_fee = coin::extract(
                &mut token_pair.token_y_reserve,
                (y_swap_fee_amount as u64),
            );
        } else {
            x_swap_fee = coin::zero();
            y_swap_fee = coin::zero();
        };

        update_oracle<X, Y>(x_reserve, y_reserve);
        // emit_swap_event<X, Y>(x_in_value, y_out, y_in_value, x_out);

        (x_swapped, y_swapped, x_swap_fee, y_swap_fee)
    }


    /// Caller should call this function to determine the order of A, B
    ///
    /// TODO(VR): Different accounts declare the same symbol
    /// Consider the following scenario:
    /// If 0xab and 0xcd claim ETH at the same time, how to compare them?
    ///
    public fun compare_token<X, Y>(): u8 {
        // let x_bytes = bcs::to_bytes<string::String>(&type_info::type_name<X>());
        // let y_bytes = bcs::to_bytes<string::String>(&type_info::type_name<Y>());
        let x_bytes = &type_info::struct_name(&type_info::type_of<X>());
        let y_bytes = &type_info::struct_name(&type_info::type_of<Y>());
        let ret = comparator::compare_u8_vector(*x_bytes, *y_bytes);
        if (comparator::is_equal(&ret)) {
            0
        } else if (comparator::is_smaller_than(&ret)) {
            1
        } else {
            2
        }
    }

    fun assert_swap_admin(signer: &signer) {
        assert!(signer::address_of(signer) == TokenSwapConfig::admin_address(), ERROR_SWAP_PRIVILEGE_INSUFFICIENT);
    }

    public fun assert_is_token<T>(): bool {
        assert!(type_info::account_address(&type_info::type_of<T>()) != @0x0, ERROR_SWAP_TOKEN_NOT_EXISTS);
        true
    }

    fun update_oracle<X, Y>(
        x_reserve: u128,
        y_reserve: u128,
    ) acquires TokenSwapPair {
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());

        let last_block_timestamp = token_pair.last_block_timestamp;
        let block_timestamp = timestamp::now_seconds() % (1u64 << 32);
        let time_elapsed: u64 = block_timestamp - last_block_timestamp;
        if (time_elapsed > 0 && x_reserve != 0 && y_reserve != 0) {
            let last_price_x_cumulative = FixedPoint128::to_u256(
                FixedPoint128::div(FixedPoint128::encode(y_reserve), x_reserve)
            ) * (time_elapsed as u256);

            let last_price_y_cumulative = FixedPoint128::to_u256(
                FixedPoint128::div(FixedPoint128::encode(x_reserve), y_reserve)
            ) * (time_elapsed as u256);

            token_pair.last_price_x_cumulative = token_pair.last_price_x_cumulative + last_price_x_cumulative;
            token_pair.last_price_y_cumulative = token_pair.last_price_y_cumulative + last_price_y_cumulative;
        };

        token_pair.last_block_timestamp = block_timestamp;
    }

    /// if swap fee deposit to fee address fail, return back to lp pool
    public fun return_back_to_lp_pool<X, Y>(
        x_in: coin::Coin<X>,
        y_in: coin::Coin<Y>,
    ) acquires TokenSwapPair {
        let token_pair = borrow_global_mut<TokenSwapPair<X, Y>>(TokenSwapConfig::admin_address());
        coin::merge(&mut token_pair.token_x_reserve, x_in);
        coin::merge(&mut token_pair.token_y_reserve, y_in);
    }

    public fun cacl_actual_swap_fee_operation_rate<X, Y>(): (u128, u128) {
        let (fee_numerator, fee_denominator) = TokenSwapConfig::get_poundage_rate<X, Y>();
        let (operation_numerator, operation_denominator) = TokenSwapConfig::get_swap_fee_operation_rate_v2<X, Y>();
        ((fee_numerator * operation_numerator as u128), (fee_denominator * operation_denominator as u128))
    }

    /// Do mint and emit `AddLiquidityEvent` event
    public fun mint_and_emit_event<X, Y>(
        signer: &signer,
        x_token: coin::Coin<X>,
        y_token: coin::Coin<Y>,
        amount_x_desired: u128,
        amount_y_desired: u128,
        amount_x_min: u128,
        amount_y_min: u128): coin::Coin<LiquidityToken<X, Y>>
    acquires TokenSwapPair, LiquidityTokenCapability {
        let liquidity_token = mint<X, Y>(x_token, y_token);

        event::emit(AddLiquidityEvent {
            x_token_code: type_info::type_name<X>(),
            y_token_code: type_info::type_name<Y>(),
            signer: signer::address_of(signer),
            liquidity: (coin::value<LiquidityToken<X, Y>>(&liquidity_token) as u128),
            amount_x_desired,
            amount_y_desired,
            amount_x_min,
            amount_y_min,
        });
        liquidity_token
    }

    /// Do burn and emit `RemoveLiquidityEvent` event
    public fun burn_and_emit_event<X, Y>(
        signer: &signer,
        to_burn: coin::Coin<LiquidityToken<X, Y>>,
        amount_x_min: u128,
        amount_y_min: u128)
    : (coin::Coin<X>, coin::Coin<Y>) acquires TokenSwapPair, LiquidityTokenCapability {
        let liquidity = coin::value<LiquidityToken<X, Y>>(&to_burn);
        let (x_token, y_token) = burn<X, Y>(to_burn);

        event::emit(RemoveLiquidityEvent {
            x_token_code: type_info::type_name<X>(),
            y_token_code: type_info::type_name<Y>(),
            signer: signer::address_of(signer),
            liquidity: (liquidity as u128),
            amount_x_min,
            amount_y_min,
        });
        (x_token, y_token)
    }

    /// Do swap and emit `SwapEvent` event
    public fun swap_and_emit_event<X, Y>(
        signer: &signer,
        x_in: coin::Coin<X>,
        y_out: u128,
        y_in: coin::Coin<Y>,
        x_out: u128
    ): (coin::Coin<X>, coin::Coin<Y>, coin::Coin<X>, coin::Coin<Y>) acquires TokenSwapPair {
        let (
            token_x_out,
            token_y_out,
            token_x_fee,
            token_y_fee
        ) = swap<X, Y>(x_in, y_out, y_in, x_out);

        event::emit(SwapEvent {
            x_token_code: type_info::type_name<X>(),
            y_token_code: type_info::type_name<Y>(),
            signer: signer::address_of(signer),
            x_in: (coin::value<X>(&token_x_out) as u128),
            y_out: (coin::value<Y>(&token_y_out) as u128),
        });
        (token_x_out, token_y_out, token_x_fee, token_y_fee)
    }

    #[test_only]
    struct A {}

    #[test_only]
    struct B {}

    #[test]
    public fun test_compare_token_order() {
        assert!(Self::compare_token<A, A>() == 0, 101);
        assert!(Self::compare_token<A, B>() == 1, 102);
        assert!(Self::compare_token<B, A>() == 2, 103);
    }
}