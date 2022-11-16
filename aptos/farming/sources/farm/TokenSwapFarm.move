// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapFarm {
    use std::error;
    use std::signer;
    use std::vector;

    use aptos_std::type_info;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::event;

    use SwapAdmin::CommonHelper;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwap::LiquidityToken;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapGovPoolType::PoolTypeFarmPool;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::YieldFarmingV3 as YieldFarming;

    const ERR_DEPRECATED: u64 = 1;
    const ERR_FARM_PARAM_ERROR: u64 = 101;
    const ERR_WHITE_LIST_BOOST_IS_OPEN: u64 = 102;
    const ERR_WHITE_LIST_BOOST_SIGN_IS_NULL: u64 = 103;
    const ERR_WHITE_LIST_BOOST_IS_NOT_WL_USER: u64 = 104;
    const ERR_BOOST_IS_NOT_TURN_ON:u64 = 105;

    const ERR_FARM_NOT_EXIST: u64 = 201;

    /// Event emitted when farm been added
    struct AddFarmEvent has drop, store {
        /// token code of X type
        x_type_info: type_info::TypeInfo,
        /// token code of X type
        y_type_info: type_info::TypeInfo,
        /// signer of farm add
        signer: address,
        /// admin address
        admin: address,
    }

    /// Event emitted when farm been added
    struct ActivationStateEvent has drop, store {
        /// token code of X type
        x_type_info: type_info::TypeInfo,
        /// token code of X type
        y_type_info: type_info::TypeInfo,
        /// signer of farm add
        signer: address,
        /// admin address
        admin: address,
        /// Activation state
        activation_state: bool,
    }

    /// Event emitted when stake been called
    struct StakeEvent has drop, store {
        /// token code of X type
        x_type_info: type_info::TypeInfo,
        /// token code of X type
        y_type_info: type_info::TypeInfo,
        /// signer of stake user
        signer: address,
        // value of stake user
        amount: u128,
        /// admin address
        admin: address,
    }

    /// Event emitted when unstake been called
    struct UnstakeEvent has drop, store {
        /// token code of X type
        x_type_info: type_info::TypeInfo,
        /// token code of X type
        y_type_info: type_info::TypeInfo,
        /// signer of stake user
        signer: address,
        /// admin address
        admin: address,
    }

    struct FarmPoolEvent has key, store {
        add_farm_event_handler: event::EventHandle<AddFarmEvent>,
        activation_state_event_handler: event::EventHandle<ActivationStateEvent>,
        stake_event_handler: event::EventHandle<StakeEvent>,
        unstake_event_handler: event::EventHandle<UnstakeEvent>,
    }

    struct FarmPoolCapability<phantom X, phantom Y> has key, store {
        cap: YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>,
        release_per_seconds: u128,
        //abandoned fields
    }

    struct FarmMultiplier<phantom X, phantom Y> has key, store {
        multiplier: u64,
    }

    struct FarmPoolStake<phantom X, phantom Y> has key, store {
        id: u64,
        /// Harvest capability for Farm
        cap: YieldFarming::HarvestCapability<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>,
    }


    struct FarmPoolInfo<phantom X, phantom Y> has key, store {
        alloc_point: u128
    }


    /// Initialize farm big pool
    public fun initialize_farm_pool(account: &signer, token: coin::Coin<STAR::STAR>) {
        YieldFarming::initialize<PoolTypeFarmPool, STAR::STAR>(account, token);

        move_to(account, FarmPoolEvent {
            add_farm_event_handler: account::new_event_handle<AddFarmEvent>(account),
            activation_state_event_handler: account::new_event_handle<ActivationStateEvent>(account),
            stake_event_handler: account::new_event_handle<StakeEvent>(account),
            unstake_event_handler: account::new_event_handle<UnstakeEvent>(account),
        });
    }

    /// Called by admin
    /// this will config yield farming global pool info
    public fun initialize_global_pool_info(account: &signer, pool_release_per_second: u128) {
        // Only called by the genesis
        STAR::assert_genesis_address(account);
        YieldFarming::initialize_global_pool_info<PoolTypeFarmPool>(account, pool_release_per_second);
    }

    /// Initialize Liquidity pair gov pool, only called by token issuer
    public fun add_farm_v2<X, Y>(
        signer: &signer,
        alloc_point: u128) acquires FarmPoolEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        // To determine how many amount release in every period
        let cap = YieldFarming::add_asset_v2<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
            signer,
            alloc_point,
            0);

        move_to(signer, FarmPoolCapability<X, Y> {
            cap,
            release_per_seconds: 0, //abandoned fields
        });

        move_to(signer, FarmPoolInfo<X, Y> {
            alloc_point
        });

        // Emit add farm event
        let admin = signer::address_of(signer);
        let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin);
        event::emit_event(&mut farm_pool_event.add_farm_event_handler,
            AddFarmEvent {
                y_type_info: type_info::type_of<X>(),
                x_type_info: type_info::type_of<Y>(),
                signer: signer::address_of(signer),
                admin,
            });
    }

    /// Get farm multiplier of second per releasing
    public fun get_farm_multiplier<X, Y>(): u64 acquires FarmPoolInfo {
        let farm_pool_info = borrow_global<FarmPoolInfo<X, Y>>(STAR::token_address());
        (farm_pool_info.alloc_point as u64)
    }


    public fun set_farm_alloc_point<X, Y>(signer: &signer, alloc_point: u128)
    acquires FarmPoolCapability, FarmPoolInfo, FarmPoolEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker = signer::address_of(signer);
        let cap = borrow_global<FarmPoolCapability<X, Y>>(broker);
        let farm_pool_info = borrow_global_mut<FarmPoolInfo<X, Y>>(broker);
        let last_alloc_point = farm_pool_info.alloc_point;

        YieldFarming::update_pool<PoolTypeFarmPool, STAR::STAR, coin::Coin<LiquidityToken<X, Y>>>(
            &cap.cap,
            broker,
            alloc_point,
            farm_pool_info.alloc_point,
        );
        farm_pool_info.alloc_point = alloc_point;

        if (alloc_point == 0 || last_alloc_point == 0) {
            let farm_pool_event = borrow_global_mut<FarmPoolEvent>(broker);
            event::emit_event(
                &mut farm_pool_event.activation_state_event_handler,
                ActivationStateEvent {
                    x_type_info: type_info::type_of<X>(),
                    y_type_info: type_info::type_of<Y>(),
                    signer: broker,
                    admin: broker,
                    activation_state: (alloc_point > 0),
                }
            );
        };
    }

    public fun set_pool_release_per_second(signer: &signer, pool_release_per_second: u128){
        STAR::assert_genesis_address(signer);

        // Updated release per second for `PoolTypeFarmPool`
        YieldFarming::modify_global_release_per_second_by_admin<PoolTypeFarmPool>(
            signer,
            pool_release_per_second
        );
    }


    /// Deposit Token into the pool
    public fun deposit<PoolType: store, CoinT>(
        account: &signer,
        token: coin::Coin<CoinT>
    ) {
        YieldFarming::deposit<PoolType, CoinT>(account, token);
    }

    /// View Treasury Remaining
    public fun get_treasury_balance<PoolType: store, CoinT>(): u128 {
        YieldFarming::get_treasury_balance<PoolType, CoinT>(STAR::token_address())
    }

    /// Stake liquidity Token pair
    public fun stake<X, Y>(account: &signer,
                           amount: u128)
    acquires FarmPoolCapability, FarmPoolEvent, FarmPoolStake {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = signer::address_of(account);
        CommonHelper::safe_accept_token<STAR::STAR>(account);

        // after pool alloc mode upgrade
        if (YieldFarming::exists_stake_list<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(account_addr) &&
            (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
                account_addr
            ))) {
            extend_farm_stake_resource<X, Y>(account);
        };

        // Actual stake
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());
        let harvest_cap = inner_stake<X, Y>(account, amount, farm_cap);

        // Store a capability to account
        move_to(account, harvest_cap);

        // Emit stake event
        let farm_stake_event = borrow_global_mut<FarmPoolEvent>(STAR::token_address());
        event::emit_event(&mut farm_stake_event.stake_event_handler,
            StakeEvent {
                y_type_info: type_info::type_of<X>(),
                x_type_info: type_info::type_of<Y>(),
                signer: account_addr,
                admin: STAR::token_address(),
                amount,
            });
    }

    fun extend_farm_stake_resource<X, Y>(account: &signer) acquires FarmPoolCapability {
        let account_addr = signer::address_of(account);
        //double check if need extend
        if (!(YieldFarming::exists_stake_at_address<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(account_addr) &&
            (!YieldFarming::exists_stake_extend<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(account_addr)))) {
            return
        };

        // Access Control
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());

        let stake_ids = YieldFarming::query_stake_list<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
            account_addr
        );
        let len = vector::length(&stake_ids);
        let idx = 0;
        loop {
            if (idx >= len) {
                break
            };
            let stake_id = vector::borrow(&stake_ids, idx);
            YieldFarming::extend_farm_stake_info<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
                account,
                *stake_id,
                &farm_cap.cap
            );

            idx = idx + 1;
        }
    }


    /// Unstake liquidity Token pair
    public fun unstake<X, Y>(account: &signer, amount: u128)
    acquires FarmPoolCapability, FarmPoolStake, FarmPoolEvent {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = signer::address_of(account);
        // after pool alloc mode upgrade
        if (YieldFarming::exists_stake_list<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(account_addr) &&
            (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
                account_addr
            ))) {
            extend_farm_stake_resource<X, Y>(account);
        };

        // Actual stake
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());
        let farm_stake = move_from<FarmPoolStake<X, Y>>(account_addr);
        let harvest_cap = inner_unstake<X, Y>(account, amount, farm_cap, farm_stake);

        move_to(account, harvest_cap);

        // Emit unstake event
        let farm_stake_event = borrow_global_mut<FarmPoolEvent>(STAR::token_address());
        event::emit_event(&mut farm_stake_event.unstake_event_handler,
            UnstakeEvent {
                y_type_info: type_info::type_of<X>(),
                x_type_info: type_info::type_of<Y>(),
                signer: account_addr,
                admin: STAR::token_address(),
            });
    }

    /// Harvest reward from token pool
    public fun harvest<X, Y>(account: &signer, amount: u128) acquires FarmPoolStake, FarmPoolCapability {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = signer::address_of(account);
        // after pool alloc mode upgrade
        if (YieldFarming::exists_stake_list<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(account_addr) &&
            (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
                account_addr
            ))) {
            extend_farm_stake_resource<X, Y>(account);
        };

        let farm_harvest_cap = borrow_global_mut<FarmPoolStake<X, Y>>(account_addr);
        let token = YieldFarming::harvest<
            PoolTypeFarmPool,
            STAR::STAR,
            coin::Coin<LiquidityToken<X, Y>>>(
            account_addr,
            STAR::token_address(),
            amount,
            &farm_harvest_cap.cap,
        );
        coin::deposit<STAR::STAR>(account_addr, token);

        let farm = borrow_global<FarmPoolStake<X, Y>>(account_addr);
        let farm_cap = borrow_global<FarmPoolCapability<X, Y>>(STAR::token_address());
        TokenSwapFarmBoost::update_boost_for_farm_pool<X, Y>(&farm_cap.cap, account, farm.id);
    }

    /// Return calculated APY
    public fun lookup_gain<X, Y>(account: address): u128 acquires FarmPoolStake {
        if (exists<FarmPoolStake<X, Y>>(account)) {
            let farm = borrow_global<FarmPoolStake<X, Y>>(account);
            YieldFarming::query_expect_gain<PoolTypeFarmPool, STAR::STAR, coin::Coin<LiquidityToken<X, Y>>>(
                account, STAR::token_address(), &farm.cap)
        }else {
            0
        }
    }

    /// Query all stake info
    public fun query_info<X, Y>(): (bool, u128, u128, u128) {
        YieldFarming::query_info<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query pool info from pool type v2
    /// return value: (alloc_point, asset_total_amount, asset_total_weight, harvest_index)
    public fun query_info_v2<X, Y>(): (u128, u128, u128, u128) {
        YieldFarming::query_pool_info_v2<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query all stake amount
    public fun query_total_stake<X, Y>(): u128 {
        YieldFarming::query_total_stake<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query stake amount from user
    public fun query_stake<X, Y>(account: address): u128 acquires FarmPoolStake {
        if (exists<FarmPoolStake<X, Y>>(account)) {
            let farm = borrow_global<FarmPoolStake<X, Y>>(account);
            YieldFarming::query_stake<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(account, farm.id)
        } else {
            0
        }
    }

    /// Query release per second
    public fun query_release_per_second<X, Y>(): u128 acquires FarmPoolInfo {
        let farm_pool_info = borrow_global<FarmPoolInfo<X, Y>>(STAR::token_address());
        let (total_alloc_point, pool_release_per_second) = YieldFarming::query_global_pool_info<PoolTypeFarmPool>(
            STAR::token_address()
        );
        pool_release_per_second * farm_pool_info.alloc_point / total_alloc_point
    }

    /// Query farm golbal pool info
    public fun query_global_pool_info(): (u128, u128) {
        let (total_alloc_point, pool_release_per_second) = YieldFarming::query_global_pool_info<PoolTypeFarmPool>(
            STAR::token_address()
        );
        (total_alloc_point, pool_release_per_second)
    }


    /// Inner stake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_stake<X, Y>(
        account: &signer,
        amount: u128,
        farm_cap: &FarmPoolCapability<X, Y>
    ): FarmPoolStake<X, Y> acquires FarmPoolStake {
        let account_addr = signer::address_of(account);
        // If stake exist, unstake all withdraw staking, and set reward token to buffer pool
        let own_token = if (YieldFarming::exists_stake_at_address<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
            account_addr
        )) {
            let FarmPoolStake<X, Y> {
                id: _,
                cap : unwrap_harvest_cap
            } = move_from<FarmPoolStake<X, Y>>(account_addr);

            // Unstake all liquidity token and reward token
            let (own_token, reward_token) = YieldFarming::unstake<
                PoolTypeFarmPool,
                STAR::STAR,
                coin::Coin<LiquidityToken<X, Y>>
            >(account, STAR::token_address(), unwrap_harvest_cap);
            coin::deposit<STAR::STAR>(account_addr, reward_token);
            own_token
        } else {
            coin::zero<LiquidityToken<X, Y>>()
        };


        // Withdraw addtion token. Addtionally, combine addtion token and own token.
        let addition_token = TokenSwapRouter::withdraw_liquidity_token<X, Y>(account, amount);
        let total_token = own_token;
        coin::merge<LiquidityToken<X, Y>>(&mut total_token, addition_token);
        let total_amount = coin::value<LiquidityToken<X, Y>>(&total_token);
        let total_amount = (total_amount as u128);


        // after pool alloc mode upgrade
        let (new_harvest_cap, stake_id) = {
            let new_weight_factor = TokenSwapFarmBoost::predict_boost_factor<X, Y>(account_addr, total_amount);
            let asset_weight = TokenSwapFarmBoost::calculate_boost_weight(total_amount, new_weight_factor);
            TokenSwapFarmBoost::set_boost_factor<X, Y>(&farm_cap.cap, account, new_weight_factor);

            YieldFarming::stake_v2<
                PoolTypeFarmPool,
                STAR::STAR,
                coin::Coin<LiquidityToken<X, Y>>>(
                account,
                STAR::token_address(),
                total_token,
                asset_weight,
                total_amount,
                new_weight_factor,
                0,
                &farm_cap.cap
            )
        };


        FarmPoolStake<X, Y> {
            cap: new_harvest_cap,
            id: stake_id,
        }
    }

    /// Inner unstake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_unstake<X, Y>(
        account: &signer,
        amount: u128,
        farm_cap: &FarmPoolCapability<X, Y>,
        farm_stake: FarmPoolStake<X, Y>
    ): FarmPoolStake<X, Y> {
        let account_addr = signer::address_of(account);
        let FarmPoolStake {
            cap: unwrap_harvest_cap,
            id: _,
        } = farm_stake;
        assert!(amount > 0, error::invalid_state(ERR_FARM_PARAM_ERROR));

        // unstake all from pool
        let (own_asset_token, reward_token) = YieldFarming::unstake<
            PoolTypeFarmPool,
            STAR::STAR,
            coin::Coin<LiquidityToken<X, Y>>
        >(account, STAR::token_address(), unwrap_harvest_cap);

        // Process reward token
        coin::deposit<STAR::STAR>(account_addr, reward_token);

        // Process asset token
        let withdraw_asset_token =
            coin::extract<LiquidityToken<X, Y>>(&mut own_asset_token, (amount as u64));
        TokenSwapRouter::deposit_liquidity_token<X, Y>(account_addr, withdraw_asset_token);

        let own_asset_amount = (coin::value<LiquidityToken<X, Y>>(&own_asset_token) as u128);

        // Restake to pool
        // after pool alloc mode upgrade
        let (
            new_harvest_cap,
            stake_id
        ) = {
            // once farm unstake, user boost factor lose efficacy, become 1
            TokenSwapFarmBoost::unboost_from_farm_pool<X, Y>(&farm_cap.cap, account);
            let weight_factor = TokenSwapFarmBoost::get_boost_factor<X, Y>(account_addr);
            let own_asset_weight = TokenSwapFarmBoost::calculate_boost_weight(own_asset_amount, weight_factor);
            YieldFarming::stake_v2<
                PoolTypeFarmPool,
                STAR::STAR,
                coin::Coin<LiquidityToken<X, Y>>>(
                account,
                STAR::token_address(),
                own_asset_token,
                own_asset_weight,
                own_asset_amount,
                weight_factor,
                0,
                &farm_cap.cap
            )
        };

        FarmPoolStake<X, Y> {
            cap: new_harvest_cap,
            id: stake_id,
        }
    }

    /// boost for farm
    public fun boost<X, Y>(account: &signer, boost_amount: u128)
    acquires FarmPoolStake, FarmPoolCapability {
        assert!(TokenSwapConfig::get_boost_switch(), error::invalid_state(ERR_BOOST_IS_NOT_TURN_ON));

        let user_addr = signer::address_of(account);
        if (YieldFarming::exists_stake_list<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(user_addr) &&
            (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(user_addr))) {
            extend_farm_stake_resource<X, Y>(account);
        };

        let farm = borrow_global<FarmPoolStake<X, Y>>(user_addr);
        let farm_cap = borrow_global<FarmPoolCapability<X, Y>>(@SwapAdmin);
        TokenSwapFarmBoost::boost_to_farm_pool<X, Y>(&farm_cap.cap, account, boost_amount, farm.id)
    }

    /// boost for farm
    public fun wl_boost<X, Y>(
        account: &signer,
        boost_amount: u128,
        _signature: &vector<u8>
    )acquires FarmPoolStake, FarmPoolCapability {
        assert!(TokenSwapConfig::get_boost_switch(), error::invalid_state(ERR_BOOST_IS_NOT_TURN_ON));

        let user_addr = signer::address_of(account);
        if (YieldFarming::exists_stake_list<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(user_addr) &&
            (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(user_addr))) {
            extend_farm_stake_resource<X, Y>(account);
        };

        let farm = borrow_global<FarmPoolStake<X, Y>>(user_addr);
        let farm_cap = borrow_global<FarmPoolCapability<X, Y>>(@SwapAdmin);
        TokenSwapFarmBoost::boost_to_farm_pool<X, Y>(&farm_cap.cap, account, boost_amount, farm.id)
    }


    #[test]
    fun test_wl_boost() {
        use aptos_std::ed25519;
        use std::bcs;

        let public_key = x"d6da1bea14990ad936a848c2a375a2c105d5038ce726ed03f8700998c4e840b5";
        let message = @0xc5578819fD7Ab114AbB77F1596A0fdb4;
        let signature = x"773c9540497ee99eefa3679e04debe8ed3690f44dcaa9dbe9326ff2958559b5ded7e165886fa845c8acbbc0571ad24a4fced0e1ee239358b3857d0165a09a40d";

        let sig = ed25519::new_signature_from_bytes(signature);
        let pub_key = ed25519::new_unvalidated_public_key_from_bytes(public_key);

        let msg = bcs::to_bytes(&message);
        loop {
            if (*vector::borrow(&msg, 0) == 0) {
                vector::remove(&mut msg, 0);
            } else {
                break
            }
        };

        assert!(
            ed25519::signature_verify_strict(&sig, &pub_key, msg),
            1001
        );
    }

    public fun update_token_pool_index<X, Y>(signer: &signer) acquires FarmPoolCapability {
        STAR::assert_genesis_address(signer);

        assert!(
            exists<FarmPoolCapability<X,Y>>(STAR::token_address()),
            error::invalid_state(ERR_FARM_NOT_EXIST)
        );

        // Updated harvest index of token type
        let farm = borrow_global_mut<FarmPoolCapability<X,Y>>(STAR::token_address());
        YieldFarming::update_pool_index<PoolTypeFarmPool, STAR::STAR, coin::Coin<LiquidityToken<X,Y>>>(
            &farm.cap,
            STAR::token_address(),
        );
    }
}