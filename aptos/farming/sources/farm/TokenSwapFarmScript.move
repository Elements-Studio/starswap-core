// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapFarmScript {
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapFarm;


    /// Called by admin account
    public entry fun add_farm_pool_v2<X, Y>(account: &signer, alloc_point: u128) {
        TokenSwapFarmRouter::add_farm_pool_v2<X, Y>(account, alloc_point);
    }


    /// Stake liquidity token
    public entry fun stake<X, Y>(account: &signer, amount: u128) {
        TokenSwapFarmRouter::stake<X, Y>(account, amount);
    }

    /// Unstake liquidity token
    public entry fun unstake<X, Y>(account: &signer, amount: u128) {
        TokenSwapFarmRouter::unstake<X, Y>(account, amount);
    }

    /// Havest governance token from pool
    public entry fun harvest<X, Y>(account: &signer, amount: u128) {
        TokenSwapFarmRouter::harvest<X, Y>(account, amount);
    }

    /// Get gain count
    public fun lookup_gain<X, Y>(account: address): u128 {
        TokenSwapFarmRouter::lookup_gain<X, Y>(account)
    }

    /// Query an info from farm which combinded X and Y
    public fun query_info<X, Y>(): (bool, u128, u128, u128) {
        TokenSwapFarmRouter::query_info<X, Y>()
    }

    /// Query all stake amount
    public fun query_total_stake<X, Y>(): u128 {
        TokenSwapFarmRouter::query_total_stake<X, Y>()
    }

    /// Query all stake amount
    public fun query_stake<X, Y>(account: address): u128 {
        TokenSwapFarmRouter::query_stake<X, Y>(account)
    }

    /// Query release per second
    public fun query_release_per_second<X, Y>(): u128 {
        TokenSwapFarmRouter::query_release_per_second<X, Y>()
    }

    public entry fun set_farm_alloc_point<X, Y>(signer: &signer, alloc_point: u128) {
        TokenSwapFarmRouter::set_farm_alloc_point<X, Y>(signer, alloc_point);
    }

    public fun get_farm_multiplier<X, Y>(): u64 {
        TokenSwapFarmRouter::get_farm_multiplier<X, Y>()
    }

    public entry fun set_pool_release_per_second(signer: &signer, release_per_second: u128) {
        TokenSwapFarm::set_pool_release_per_second(signer, release_per_second);
    }

    /// boost for farm
    public entry fun boost<X, Y>(signer: &signer, boost_amount: u128) {
        TokenSwapFarmRouter::boost<X, Y>(signer, boost_amount);
    }

    /// white list boost for farm
    public entry fun wl_boost<X, Y>(signer: &signer, boost_amount: u128, signature: vector<u8>) {
        TokenSwapFarmRouter::wl_boost<X, Y>(signer, boost_amount, &signature);
    }

    public entry fun initialize_boost_event(signer: &signer) {
        TokenSwapFarmBoost::initialize_boost_event(signer);
    }
}