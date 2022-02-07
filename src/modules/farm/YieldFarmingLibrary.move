// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x4783d08fb16990bd35d83f3e23bf93b8 {

module YieldFarmingLibrary {

    use 0x1::U256;
    use 0x1::Errors;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::BigExponential;

    const ERR_FARMING_TIMESTAMP_INVALID : u64 = 101;
    const ERR_FARMING_CALC_LAST_IDX_BIGGER_THAN_NOW : u64 = 102;
    const ERR_FARMING_TOTAL_WEIGHT_IS_ZERO : u64 = 103;

    /// Update farming asset
    public fun calculate_harvest_index_with_asse_info(
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
        assert(last_update_timestamp <= now_seconds, Errors::invalid_argument(ERR_FARMING_TIMESTAMP_INVALID));
        let time_period = now_seconds - last_update_timestamp;
        let addtion_index = release_per_second * (time_period as u128);
        let index_u256 = U256::add(
            U256::from_u128(harvest_index),
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
        assert(asset_total_weight > 0, Errors::invalid_argument(ERR_FARMING_TOTAL_WEIGHT_IS_ZERO));
        assert(last_update_timestamp <= now_seconds, Errors::invalid_argument(ERR_FARMING_TIMESTAMP_INVALID));

        let time_period = now_seconds - last_update_timestamp;
        let numr = release_per_second * (time_period as u128);
        let denom = asset_total_weight;
        let index_u256 = U256::add(
            U256::from_u128(harvest_index),
            BigExponential::mantissa(BigExponential::exp(numr, denom))
        );
        BigExponential::to_safe_u128(index_u256)
    }

    /// This function will return a gain index
    public fun calculate_withdraw_amount(harvest_index: u128,
                                         last_harvest_index: u128,
                                         asset_weight: u128): u128 {
        assert(harvest_index >= last_harvest_index, Errors::invalid_argument(ERR_FARMING_CALC_LAST_IDX_BIGGER_THAN_NOW));
        let amount_u256 = U256::mul(U256::from_u128(asset_weight), U256::from_u128(harvest_index - last_harvest_index));
        BigExponential::truncate(BigExponential::exp_from_u256(amount_u256))
    }

}

}


