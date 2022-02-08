// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module TokenSwapFarmRouter {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwap;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarm;

    const ERROR_ROUTER_INVALID_TOKEN_PAIR: u64 = 1001;

    public fun add_farm_pool<X: copy + drop + store, Y: copy + drop + store>(account: &signer, release_per_second: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::add_farm<X, Y>(account, release_per_second);
        } else {
            TokenSwapFarm::add_farm<Y, X>(account, release_per_second);
        };
    }

    public fun reset_farm_activation<X: copy + drop + store, Y: copy + drop + store>(account: &signer,
                                                                                     active: bool) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::reset_farm_activation<X, Y>(account, active);
        } else {
            TokenSwapFarm::reset_farm_activation<Y, X>(account, active);
        };
    }

    public fun stake<X: copy + drop + store, Y: copy + drop + store>(account: &signer, amount: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::stake<X, Y>(account, amount);
        } else {
            TokenSwapFarm::stake<Y, X>(account, amount);
        };
    }

    public fun unstake<X: copy + drop + store, Y: copy + drop + store>(account: &signer, amount: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::unstake<X, Y>(account, amount);
        } else {
            TokenSwapFarm::unstake<Y, X>(account, amount);
        }
    }

    /// Havest governance token from pool
    public fun harvest<X: copy + drop + store, Y: copy + drop + store>(account: &signer, amount: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::harvest<X, Y>(account, amount);
        } else {
            TokenSwapFarm::harvest<Y, X>(account, amount);
        }
    }

    /// Get gain count
    public fun lookup_gain<X: copy + drop + store, Y: copy + drop + store>(account: address): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::lookup_gain<X, Y>(account)
        } else {
            TokenSwapFarm::lookup_gain<Y, X>(account)
        }
    }

    /// Query all stake amount
    public fun query_total_stake<X: copy + drop + store, Y: copy + drop + store>(): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::query_total_stake<X, Y>()
        } else {
            TokenSwapFarm::query_total_stake<Y, X>()
        }
    }

    /// Query all stake amount
    public fun query_stake<X: copy + drop + store, Y: copy + drop + store>(account: address): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::query_stake<X, Y>(account)
        } else {
            TokenSwapFarm::query_stake<Y, X>(account)
        }
    }

    public fun query_info<X: copy + drop + store, Y: copy + drop + store>(): (bool, u128, u128, u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::query_info<X, Y>()
        } else {
            TokenSwapFarm::query_info<Y, X>()
        }
    }

    /// Query release per second
    public fun query_release_per_second<X: copy + drop + store, Y: copy + drop + store>(): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::query_release_per_second<X, Y>()
        } else {
            TokenSwapFarm::query_release_per_second<Y, X>()
        }
    }

    /// Set farm mutiple of second per releasing
    public fun set_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>(signer: &signer, multiplier: u64) {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::set_farm_multiplier<X, Y>(signer, multiplier);
        } else {
            TokenSwapFarm::set_farm_multiplier<Y, X>(signer, multiplier);
        }
    }

    /// Get farm mutiple of second per releasing
    public fun get_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>(): u64 {
        let order = TokenSwap::compare_token<X, Y>();
        assert(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::get_farm_multiplier<X, Y>()
        } else {
            TokenSwapFarm::get_farm_multiplier<Y, X>()
        }
    }
}
}