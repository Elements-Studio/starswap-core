// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
/// library with helper methods for oracles that are concerned with computing average prices
module TokenSwapOracleLibrary {
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::U256::{Self, U256};
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::FixedPoint128;

    /// helper function that returns the current block timestamp within the range of u64, i.e. [0, 2**32 - 1]
    public fun current_block_timestamp(): u64 {
        Timestamp::now_seconds() % (1u64 << 32)
    }

    /// TWAP price oracle, include update price accumulators, on the first call per block
    public fun current_cumulative_prices<X: copy + drop + store, Y: copy + drop + store>(): (u128, u128, u64) {
        let (price_x_cumulative, price_y_cumulative, block_timestamp) = current_cumulative_prices_v2<X, Y>();
        let price_x_cumulative_decode = FixedPoint128::decode(FixedPoint128::encode_u256(price_x_cumulative, false));
        let price_y_cumulative_decode = FixedPoint128::decode(FixedPoint128::encode_u256(price_y_cumulative, false));

        (price_x_cumulative_decode, price_y_cumulative_decode, block_timestamp)
    }

    /// TWAP price oracle, include update price accumulators, on the first call per block
    /// return U256 with precision
    public fun current_cumulative_prices_v2<X: copy + drop + store, Y: copy + drop + store>(): (U256, U256, u64) {
        let block_timestamp = current_block_timestamp();
        let (price_x_cumulative, price_y_cumulative, last_block_timestamp) = TokenSwapRouter::get_cumulative_info<X, Y>();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        if (last_block_timestamp != block_timestamp) {
            let (x_reserve, y_reserve) = TokenSwapRouter::get_reserves<X, Y>();
            if (x_reserve !=0 && y_reserve != 0){
                let time_elapsed = block_timestamp - last_block_timestamp;
                // counterfactual
                let new_price_x_cumulative = U256::mul(FixedPoint128::to_u256(FixedPoint128::div(FixedPoint128::encode(y_reserve), x_reserve)), U256::from_u64(time_elapsed));
                let new_price_y_cumulative = U256::mul(FixedPoint128::to_u256(FixedPoint128::div(FixedPoint128::encode(x_reserve), y_reserve)), U256::from_u64(time_elapsed));
                price_x_cumulative = U256::add(price_x_cumulative, new_price_x_cumulative);
                price_y_cumulative = U256::add(price_y_cumulative, new_price_y_cumulative);
            };
        };
        (price_x_cumulative, price_y_cumulative, block_timestamp)
    }
}
}