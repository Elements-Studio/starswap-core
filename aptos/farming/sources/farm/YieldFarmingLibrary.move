// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {

module YieldFarmingLibrary {
    use std::error;

    use SwapAdmin::BigExponential;
    use SwapAdmin::U256Wrapper::{Self, U256};

    const ERR_FARMING_TIMESTAMP_INVALID: u64 = 101;
    const ERR_FARMING_CALC_LAST_IDX_BIGGER_THAN_NOW: u64 = 102;
    const ERR_FARMING_TOTAL_WEIGHT_IS_ZERO: u64 = 103;

    /// Update farming asset
    public fun calculate_harvest_index_with_asset_info(
        asset_total_weight: u128,
        asset_harvest_index: u128,
        asset_last_update_timestamp: u64,
        asset_release_per_second: u128,
        now_seconds: u64): u128 {
        // Recalculate harvest index
        if (asset_total_weight <= 0) {
            calculate_harvest_index_weight_zero(
                asset_harvest_index,
                asset_last_update_timestamp,
                now_seconds,
                asset_release_per_second
            )
        } else {
            calculate_harvest_index(
                asset_harvest_index,
                asset_total_weight,
                asset_last_update_timestamp,
                now_seconds,
                asset_release_per_second
            )
        }
    }

    /// There is calculating from harvest index and global parameters without asset_total_weight
    public fun calculate_harvest_index_weight_zero(harvest_index: u128,
                                                   last_update_timestamp: u64,
                                                   now_seconds: u64,
                                                   release_per_second: u128): u128 {
        assert!(last_update_timestamp <= now_seconds, error::invalid_argument(ERR_FARMING_TIMESTAMP_INVALID));
        let time_period = now_seconds - last_update_timestamp;
        let addtion_index = release_per_second * (time_period as u128);
        let index_u256 = U256Wrapper::add(
            U256Wrapper::from_u128(harvest_index),
            BigExponential::mantissa(BigExponential::exp_direct_expand(addtion_index))
        );
        BigExponential::to_safe_u128(index_u256)
    }

    /// There is calculating from harvest index and global parameters
    public fun calculate_harvest_index(harvest_index: u128,
                                       asset_total_weight: u128,
                                       last_update_timestamp: u64,
                                       now_seconds: u64,
                                       release_per_second: u128): u128 {
        let additional_harvest_index =
            calculate_addtion_harvest_index(
                asset_total_weight,
                last_update_timestamp,
                now_seconds,
                release_per_second);

        let index_u256 = U256Wrapper::add(
            U256Wrapper::from_u128(harvest_index),
            additional_harvest_index,
        );
        BigExponential::to_safe_u128(index_u256)
    }

    /// Computer addtion harvest index from old harvest index
    public fun calculate_addtion_harvest_index(asset_total_weight: u128,
                                               last_update_timestamp: u64,
                                               now_seconds: u64,
                                               release_per_second: u128): U256 {
        assert!(asset_total_weight > 0, error::invalid_argument(ERR_FARMING_TOTAL_WEIGHT_IS_ZERO));
        assert!(last_update_timestamp <= now_seconds, error::invalid_argument(ERR_FARMING_TIMESTAMP_INVALID));

        let time_period = now_seconds - last_update_timestamp;
        let numr = release_per_second * (time_period as u128);
        let denom = asset_total_weight;
        BigExponential::mantissa(BigExponential::exp(numr, denom))
    }

    /// This function will return a gain index
    public fun calculate_withdraw_amount(harvest_index: u128,
                                         last_harvest_index: u128,
                                         asset_weight: u128): u128 {
        assert!(
            harvest_index >= last_harvest_index,
            error::invalid_argument(ERR_FARMING_CALC_LAST_IDX_BIGGER_THAN_NOW)
        );
        let amount_u256 = U256Wrapper::mul(
            U256Wrapper::from_u128(asset_weight),
            U256Wrapper::from_u128(harvest_index - last_harvest_index)
        );
        BigExponential::truncate(BigExponential::exp_from_u256(amount_u256))
    }

    #[test]
    fun test_withdraw_amount() {
        let harvest_index = 1000000;
        let asset_total_weight = 100000000;
        let last_update_timestamp = 1;
        let now_seconds = 11;
        let release_per_second = 2;

        let new_index = Self::calculate_harvest_index(
            harvest_index,
            asset_total_weight,
            last_update_timestamp,
            now_seconds,
            release_per_second
        );
        assert!(new_index == 200001000000, 10001);

        let amount = Self::calculate_withdraw_amount(new_index, harvest_index, asset_total_weight);
        assert!(amount == 20, 10002);
    }

    #[test]
    fun test_calc_harvest_index() {
        let harvest_index = 1499999999999999999;
        let asset_total_weight = 7000000000;
        let last_update_timestamp = 86443;
        let now_seconds = 86444;
        let release_per_second = 1000000000;

        let new_index = Self::calculate_harvest_index(
            harvest_index,
            asset_total_weight,
            last_update_timestamp,
            now_seconds,
            release_per_second
        );
        assert!(new_index == 1642857142857142856, 10003);

        let amount = Self::calculate_withdraw_amount(new_index, harvest_index, release_per_second * 2);
        assert!(amount == 285714285, 10004);
    }
}
}


