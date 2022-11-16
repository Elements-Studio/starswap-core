// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapFarmRouter {
    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapGov;

    const ERROR_ROUTER_INVALID_TOKEN_PAIR: u64 = 1001;


    public fun add_farm_pool_v2<X, Y>(account: &signer, alloc_point: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::add_farm_v2<X, Y>(account, alloc_point);
        } else {
            TokenSwapFarm::add_farm_v2<Y, X>(account, alloc_point);
        };
    }

    public fun stake<X, Y>(account: &signer, amount: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        TokenSwapGov::linear_withdraw_farm(account, 0);
        if (order == 1) {
            TokenSwapFarm::stake<X, Y>(account, amount);
        } else {
            TokenSwapFarm::stake<Y, X>(account, amount);
        };
    }

    public fun unstake<X, Y>(account: &signer, amount: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        TokenSwapGov::linear_withdraw_farm(account, 0);
        if (order == 1) {
            TokenSwapFarm::unstake<X, Y>(account, amount);
        } else {
            TokenSwapFarm::unstake<Y, X>(account, amount);
        }
    }

    /// Havest governance token from pool
    public fun harvest<X, Y>(account: &signer, amount: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        TokenSwapGov::linear_withdraw_farm(account, 0);
        if (order == 1) {
            TokenSwapFarm::harvest<X, Y>(account, amount);
        } else {
            TokenSwapFarm::harvest<Y, X>(account, amount);
        }
    }

    /// Get gain count
    public fun lookup_gain<X, Y>(account: address): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::lookup_gain<X, Y>(account)
        } else {
            TokenSwapFarm::lookup_gain<Y, X>(account)
        }
    }

    /// Query all stake amount
    public fun query_total_stake<X, Y>(): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::query_total_stake<X, Y>()
        } else {
            TokenSwapFarm::query_total_stake<Y, X>()
        }
    }

    /// Query all stake amount
    public fun query_stake<X, Y>(account: address): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::query_stake<X, Y>(account)
        } else {
            TokenSwapFarm::query_stake<Y, X>(account)
        }
    }

    public fun query_info<X, Y>(): (bool, u128, u128, u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::query_info<X, Y>()
        } else {
            TokenSwapFarm::query_info<Y, X>()
        }
    }

    /// return value: (alloc_point, asset_total_amount, asset_total_weight, harvest_index)
    public fun query_info_v2<X, Y>(): (u128, u128, u128, u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::query_info_v2<X, Y>()
        } else {
            TokenSwapFarm::query_info_v2<Y, X>()
        }
    }


    /// Query release per second
    public fun query_release_per_second<X, Y>(): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::query_release_per_second<X, Y>()
        } else {
            TokenSwapFarm::query_release_per_second<Y, X>()
        }
    }


    /// Set farm alloc point
    public fun set_farm_alloc_point<X, Y>(signer: &signer, alloc_point: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::set_farm_alloc_point<X, Y>(signer, alloc_point);
        } else {
            TokenSwapFarm::set_farm_alloc_point<Y, X>(signer, alloc_point);
        }
    }

    /// Get farm mutiple of second per releasing
    public fun get_farm_multiplier<X, Y>(): u64 {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::get_farm_multiplier<X, Y>()
        } else {
            TokenSwapFarm::get_farm_multiplier<Y, X>()
        }
    }

    public fun update_token_pool_index<X, Y>(signer: &signer){
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::update_token_pool_index<X, Y>(signer);
        } else {
            TokenSwapFarm::update_token_pool_index<Y, X>(signer);
        }
    }

    /// Query farm golbal pool info
    public fun query_global_pool_info(): (u128, u128) {
        TokenSwapFarm::query_global_pool_info()
    }

    /// boost for farm
    public fun boost<X, Y>(account: &signer, boost_amount: u128) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::boost<X, Y>(account, boost_amount);
        } else {
            TokenSwapFarm::boost<Y, X>(account, boost_amount);
        }
    }

    /// white list boost for farm
    public fun wl_boost<X, Y>(account: &signer, boost_amount: u128, signature: &vector<u8>) {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarm::wl_boost<X, Y>(account, boost_amount, signature);
        } else {
            TokenSwapFarm::wl_boost<Y, X>(account, boost_amount, signature);
        }
    }

    /// Query user boost factor
    public fun get_boost_factor<X, Y>(account: address): u64 {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarmBoost::get_boost_factor<X, Y>(account)
        } else {
            TokenSwapFarmBoost::get_boost_factor<Y, X>(account)
        }
    }

    /// Query user boost locked vestar amount
    public fun get_boost_locked_vestar_amount<X, Y>(account: address): u128 {
        let order = TokenSwap::compare_token<X, Y>();
        assert!(order != 0, ERROR_ROUTER_INVALID_TOKEN_PAIR);
        if (order == 1) {
            TokenSwapFarmBoost::get_boost_locked_vestar_amount<X, Y>(account)
        } else {
            TokenSwapFarmBoost::get_boost_locked_vestar_amount<Y, X>(account)
        }
    }
}