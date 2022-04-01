// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapFarm {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Event;
    use StarcoinFramework::Errors;

    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::YieldFarmingV4 as YieldFarmingNew;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwap::LiquidityToken;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeFarmPool};


    const ERR_FARM_PARAM_ERROR: u64 = 101;

    const DEFAULT_BOOST_FACTOR: u64 = 1; // user boost factor section is [1,2.5]
    const BOOST_FACTOR_PRECESION: u64 = 100; //two-digit precision

    /// Event emitted when farm been added
    struct AddFarmEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of farm add
        signer: address,
        /// admin address
        admin: address,
    }

    /// Event emitted when farm been added
    struct ActivationStateEvent has drop, store {
        /// token code of X type
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
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
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
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
        x_token_code: Token::TokenCode,
        /// token code of X type
        y_token_code: Token::TokenCode,
        /// signer of stake user
        signer: address,
        /// admin address
        admin: address,
    }

    struct FarmPoolEvent has key, store {
        add_farm_event_handler: Event::EventHandle<AddFarmEvent>,
        activation_state_event_handler: Event::EventHandle<ActivationStateEvent>,
        stake_event_handler: Event::EventHandle<StakeEvent>,
        unstake_event_handler: Event::EventHandle<UnstakeEvent>,
    }

    struct FarmPoolCapability<phantom X, phantom Y> has key, store {
        cap: YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
        release_per_seconds: u128,
    }

    struct FarmMultiplier<phantom X, phantom Y> has key, store {
        multiplier: u64,
    }

    struct FarmPoolStake<phantom X, phantom Y> has key, store {
        id: u64,
        /// Harvest capability for Farm
        cap: YieldFarming::HarvestCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
    }


    struct FarmPoolInfo<phantom X, phantom Y> has key, store {
        alloc_point: u128
    }

    struct FarmPoolCapabilityV2<phantom X, phantom Y> has key, store {
        cap: YieldFarmingNew::PoolModifyCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
    }

    struct FarmPoolStakeV2<phantom X, phantom Y> has key, store {
        id: u64,
        /// Harvest capability for Farm
        cap: YieldFarmingNew::HarvestCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
    }

    struct UserInfo<phantom X, phantom Y> has key, store {
        user_amount: u128,
        boost_factor: u64,
        vestar_balance: u128,
    }


    /// Initialize farm big pool
    public fun initialize_farm_pool(account: &signer, token: Token::Token<STAR::STAR>) {
        YieldFarmingNew::initialize<PoolTypeFarmPool, STAR::STAR>(account, token);

        move_to(account, FarmPoolEvent{
            add_farm_event_handler: Event::new_event_handle<AddFarmEvent>(account),
            activation_state_event_handler: Event::new_event_handle<ActivationStateEvent>(account),
            stake_event_handler: Event::new_event_handle<StakeEvent>(account),
            unstake_event_handler: Event::new_event_handle<UnstakeEvent>(account),
        });
    }



    /// Called by admin
    /// this will config yield farming global pool info
    public fun initialize_global_pool_info<
        PoolType: store>(account: &signer, pool_release_per_second: u128) {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);
        YieldFarmingNew::initialize_global_pool_info<PoolTypeFarmPool>(account, pool_release_per_second);
    }

//    /// Initialize Liquidity pair gov pool, only called by token issuer
//    public fun add_farm<X: copy + drop + store,
//                        Y: copy + drop + store>(
//        signer: &signer,
//        release_per_seconds: u128) acquires FarmPoolEvent {
//
//        // Only called by the genesis
//        STAR::assert_genesis_address(signer);
//
//        // To determine how many amount release in every period
//        let cap = YieldFarming::add_asset<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(
//            signer,
//            release_per_seconds,
//            0);
//
//        move_to(signer, FarmPoolCapability<X, Y>{
//            cap,
//            release_per_seconds,
//        });
//
//        move_to(signer, FarmMultiplier<X, Y>{
//            multiplier: 1
//        });
//
//        // TODO (9191stc): Add to DAO
//        // GovernanceDaoProposal::plugin<
//        //    PoolTypeProposal<X, Y, GovTokenT>,
//        //    GovTokenT>(account, modify_cap);
//
//        // Emit add farm event
//        let admin = Signer::address_of(signer);
//        let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin);
//        Event::emit_event(&mut farm_pool_event.add_farm_event_handler,
//            AddFarmEvent{
//                y_token_code: Token::token_code<X>(),
//                x_token_code: Token::token_code<Y>(),
//                signer: Signer::address_of(signer),
//                admin,
//            });
//    }


    /// Initialize Liquidity pair gov pool, only called by token issuer
    public fun add_farm<X: copy + drop + store,
                        Y: copy + drop + store>(
        signer: &signer,
        alloc_point: u128) acquires FarmPoolEvent {

        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        // To determine how many amount release in every period
        let cap = YieldFarmingNew::add_asset<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(
            signer,
            alloc_point,
            0);

        move_to(signer, FarmPoolCapabilityV2<X, Y>{
            cap,
//            release_per_seconds,
        });

        move_to(signer, FarmPoolInfo<X, Y>{
            alloc_point: alloc_point
        });

        // Emit add farm event
        let admin = Signer::address_of(signer);
        let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin);
        Event::emit_event(&mut farm_pool_event.add_farm_event_handler,
            AddFarmEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: Signer::address_of(signer),
                admin,
            });
    }



    /// call only for migrate
    public fun migrate_farm_global_pool(account: &signer){
        STAR::assert_genesis_address(account);
        let reward_token = YieldFarming::migrate_from_farming<PoolTypeFarmPool, STAR::STAR>(account);
        YieldFarmingNew::initialize<PoolTypeFarmPool, STAR::STAR>(account, reward_token);
    }

    public fun migrate_farm_pool<X: copy + drop + store,
                                 Y: copy + drop + store>(account: &signer){
        STAR::assert_genesis_address(account);
        let (asset_total_amount, harvest_index, last_update_timestamp, start_time) =
            YieldFarming::migrate_from_farming_asset<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account);
        YieldFarmingNew::migrate_to_farming_asset<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account,
            asset_total_amount, asset_total_amount, harvest_index, last_update_timestamp, start_time);
    }


    /// Deprecated call
    /// Set farm mutiplier of second per releasing
    public fun set_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>(signer: &signer, multiplier: u64)
    acquires FarmPoolCapability, FarmMultiplier {

        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker = Signer::address_of(signer);
        let cap = borrow_global<FarmPoolCapability<X, Y>>(broker);
        let farm_mult = borrow_global_mut<FarmMultiplier<X, Y>>(broker);

        let (alive, _, _, _, ) =
            YieldFarming::query_info<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(broker);

        let relese_per_sec_mul = cap.release_per_seconds * (multiplier as u128);
        YieldFarming::modify_parameter<PoolTypeFarmPool, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
            &cap.cap,
            broker,
            relese_per_sec_mul,
            alive,
        );
        farm_mult.multiplier = multiplier;
    }

    /// Deprecated call
    /// Get farm mutiple of second per releasing
    public fun get_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>(): u64 acquires FarmMultiplier {
        let farm_mult = borrow_global_mut<FarmMultiplier<X, Y>>(STAR::token_address());
        farm_mult.multiplier
    }


    public fun set_farm_alloc_point<X: copy + drop + store,
                                   Y: copy + drop + store>(signer: &signer, alloc_point: u128)
    acquires FarmPoolCapabilityV2, FarmPoolInfo {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker = Signer::address_of(signer);
        let cap = borrow_global<FarmPoolCapabilityV2<X, Y>>(broker);
        let farm_pool_info = borrow_global_mut<FarmPoolInfo<X, Y>>(broker);

//        let (alive, _, _, _, ) =
//            YieldFarming::query_info<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(broker);
//
//        let relese_per_sec_mul = cap.release_per_seconds * (multiplier as u128);
        YieldFarmingNew::update_pool<PoolTypeFarmPool, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
            &cap.cap,
            broker,
            alloc_point,
            farm_pool_info.alloc_point,
        );
        farm_pool_info.alloc_point = alloc_point;
    }

    /// Get farm mutiplier, equals to pool alloc_point
    public fun get_farm_multiplier_v2<X: copy + drop + store,
                                   Y: copy + drop + store>(): u64 acquires FarmPoolInfo {
        let farm_pool_info = borrow_global_mut<FarmPoolInfo<X, Y>>(STAR::token_address());
        (farm_pool_info.alloc_point as u64)
    }


    /// Deprecated call
    /// Reset activation of farm from token type X and Y
    public fun reset_farm_activation<X: copy + drop + store, Y: copy + drop + store>(
        account: &signer,
        active: bool) acquires FarmPoolEvent, FarmPoolCapability {

        STAR::assert_genesis_address(account);
        let admin_addr = Signer::address_of(account);
        let cap = borrow_global_mut<FarmPoolCapability<X, Y>>(admin_addr);

        YieldFarming::modify_parameter<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>
        >(
            &cap.cap,
            admin_addr,
            cap.release_per_seconds,
            active,
        );

        let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin_addr);
        Event::emit_event(&mut farm_pool_event.activation_state_event_handler,
            ActivationStateEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: Signer::address_of(account),
                admin: admin_addr,
                activation_state: active,
            });
    }

    /// Stake liquidity Token pair
    public fun stake<X: copy + drop + store,
                     Y: copy + drop + store>(account: &signer,
                                             amount: u128)
    acquires FarmPoolCapability, FarmPoolEvent, FarmPoolStake, FarmPoolCapabilityV2 {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = Signer::address_of(account);
        if (!Account::is_accept_token<STAR::STAR>(account_addr)) {
            Account::do_accept_token<STAR::STAR>(account);
        };

        //check if need migrate
        if (!YieldFarming::exists_stake_at_address<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)) {
            migrate_farm_stake_info<X, Y>(account);
        };

        // Actual stake
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());
        let harvest_cap = inner_stake<X, Y>(account, amount, farm_cap);

        // Store a capability to account
        move_to(account, harvest_cap);

        // Emit stake event
        let farm_stake_event = borrow_global_mut<FarmPoolEvent>(STAR::token_address());
        Event::emit_event(&mut farm_stake_event.stake_event_handler,
            StakeEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: account_addr,
                admin: STAR::token_address(),
                amount,
            });
    }


    fun migrate_farm_stake_info<X: copy + drop + store,
                                Y: copy + drop + store>(account: &signer)
        acquires FarmPoolStake, FarmPoolCapability, FarmPoolCapabilityV2{
        migrate_farm_stake<X, Y>(account);
        migrate_farm_stake_list<X, Y>(account);
    }

    fun migrate_farm_stake<X: copy + drop + store,
                           Y: copy + drop + store>(account: &signer)
        acquires FarmPoolCapability, FarmPoolCapabilityV2 {

        let account_addr = Signer::address_of(account);
        //double check if need migrate
        if (!YieldFarming::exists_stake_at_address<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)){
            return
        };

        // Access Control
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());
        let farm_cap_new = borrow_global_mut<FarmPoolCapabilityV2<X, Y>>(STAR::token_address());

        let stake_ids = YieldFarming::query_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr);
        let len = Vector::length(&stake_ids);
        let idx = 0;
        loop {
            if (idx >= len) {
                break
            };
            let stake_id = Vector::borrow(&stake_ids, idx);

            let (id, asset, asset_weight, last_harvest_index, gain, asset_multiplier) =
                YieldFarming::migrate_from_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, stake_id, &farm_cap.cap);
            YieldFarmingNew::migrate_to_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, id,
                asset, asset_weight, asset_weight, get_default_boost_factor_scale(), last_harvest_index, gain, &farm_cap_new.cap);

            idx = idx + 1;
        }
    }

    fun migrate_farm_stake_list<X: copy + drop + store,
                           Y: copy + drop + store>(account: &signer)
        acquires FarmPoolStake, FarmPoolCapability, FarmPoolCapabilityV2 {

        let account_addr = Signer::address_of(account);
        //double check if need migrate
        if (!YieldFarming::exists_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)){
            return
        };

        // Access Control
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());
        let farm_cap_new = borrow_global_mut<FarmPoolCapabilityV2<X, Y>>(STAR::token_address());

        // destory old FarmPoolStake s
        let FarmPoolStake<X, Y>{
            id: _,
            cap : unwrap_harvest_cap
        } = move_from<FarmPoolStake<X, Y>>(account_addr);
        // destory old harvest_capability
        let (_stake_id, deadline) = YieldFarming::destory_harvest_capability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, account);

        let (id, _items) = YieldFarming::migrate_from_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr, &farm_cap.cap);
        let harvest_cap_new = YieldFarmingNew::migrate_to_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, id, deadline, &farm_cap_new.cap);

        // Store a new harvest capability to account
        move_to(account, FarmPoolStakeV2<X, Y>{
            cap: harvest_cap_new,
            id: id,
        });
    }



    public fun get_default_boost_factor_scale(): u64{
        DEFAULT_BOOST_FACTOR * BOOST_FACTOR_PRECESION
    }




    /// Unstake liquidity Token pair
    public fun unstake<X: copy + drop + store,
                       Y: copy + drop + store>(account: &signer, amount: u128)
    acquires FarmPoolCapability, FarmPoolStake, FarmPoolEvent {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = Signer::address_of(account);
        //check if need migrate
        if (!YieldFarming::exists_stake_at_address<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)){
        migrate_farm_stake_info<X, Y>(account);
        };

        // Actual stake
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());
        let farm_stake = move_from<FarmPoolStake<X, Y>>(account_addr);
        let harvest_cap = inner_unstake<X, Y>(account, amount, farm_cap, farm_stake);

        move_to(account, harvest_cap);

        // Emit unstake event
        let farm_stake_event = borrow_global_mut<FarmPoolEvent>(STAR::token_address());
        Event::emit_event(&mut farm_stake_event.unstake_event_handler,
            UnstakeEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: account_addr,
                admin: STAR::token_address(),
            });
    }

    /// Harvest reward from token pool
    public fun harvest<X: copy + drop + store,
                       Y: copy + drop + store>(account: &signer, amount: u128) acquires FarmPoolStake {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = Signer::address_of(account);
        //check if need migrate
        if (!YieldFarming::exists_stake_at_address<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)){
          migrate_farm_stake_info<X, Y>(account);
        };

        let farm_harvest_cap = borrow_global_mut<FarmPoolStake<X, Y>>(account_addr);
        let token = YieldFarming::harvest<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>>(
            account_addr,
            STAR::token_address(),
            amount,
            &farm_harvest_cap.cap,
        );
        Account::deposit<STAR::STAR>(account_addr, token);
    }

    /// Return calculated APY
    public fun lookup_gain<X: copy + drop + store, Y: copy + drop + store>(account: address): u128 acquires FarmPoolStake {
        let farm = borrow_global<FarmPoolStake<X, Y>>(account);
        YieldFarming::query_expect_gain<PoolTypeFarmPool, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
            account, STAR::token_address(), &farm.cap)
    }

    /// Query all stake amount
    public fun query_info<X: copy + drop + store, Y: copy + drop + store>(): (bool, u128, u128, u128) {
        YieldFarming::query_info<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query all stake amount
    public fun query_total_stake<X: copy + drop + store, Y: copy + drop + store>(): u128 {
        YieldFarming::query_total_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query stake amount from user
    public fun query_stake<X: copy + drop + store, Y: copy + drop + store>(account: address): u128 acquires FarmPoolStake {
        let farm = borrow_global<FarmPoolStake<X, Y>>(account);
        YieldFarming::query_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, farm.id)
    }

    /// Query release per second
    public fun query_release_per_second<X: copy + drop + store, Y: copy + drop + store>(): u128 acquires FarmPoolCapability {
        let cap = borrow_global<FarmPoolCapability<X, Y>>(STAR::token_address());
        cap.release_per_seconds
    }

    /// Inner stake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_stake<X: copy + drop + store,
                    Y: copy + drop + store>(account: &signer,
                                            amount: u128,
                                            farm_cap: &FarmPoolCapability<X, Y>)
    : FarmPoolStake<X, Y> acquires FarmPoolStake {
        let account_addr = Signer::address_of(account);
        // If stake exist, unstake all withdraw staking, and set reward token to buffer pool
        let own_token = if (YieldFarming::exists_stake_at_address<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)) {
            let FarmPoolStake<X, Y>{
                id: _,
                cap : unwrap_harvest_cap
            } = move_from<FarmPoolStake<X, Y>>(account_addr);

            // Unstake all liquidity token and reward token
            let (own_token, reward_token) = YieldFarming::unstake<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>
            >(account, STAR::token_address(), unwrap_harvest_cap);
            Account::deposit<STAR::STAR>(account_addr, reward_token);
            own_token
        } else {
            Token::zero<LiquidityToken<X, Y>>()
        };


        // Withdraw addtion token. Addtionally, combine addtion token and own token.
        let addition_token = TokenSwapRouter::withdraw_liquidity_token<X, Y>(account, amount);
        let total_token = Token::join<LiquidityToken<X, Y>>(own_token, addition_token);
        let total_amount = Token::value<LiquidityToken<X, Y>>(&total_token);

        let (new_harvest_cap, stake_id) = YieldFarming::stake<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>>(
            account,
            STAR::token_address(),
            total_token,
            total_amount,
            1,
            0,
            &farm_cap.cap
        );
        FarmPoolStake<X, Y>{
            cap: new_harvest_cap,
            id: stake_id,
        }
    }

    /// Inner unstake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_unstake<X: copy + drop + store,
                      Y: copy + drop + store>(account: &signer,
                                              amount: u128,
                                              farm_cap: &FarmPoolCapability<X, Y>,
                                              farm_stake: FarmPoolStake<X, Y>)
    : FarmPoolStake<X, Y> {
        let account_addr = Signer::address_of(account);
        let FarmPoolStake{
            cap: unwrap_harvest_cap,
            id: _,
        } = farm_stake;
        assert!(amount > 0, Errors::invalid_state(ERR_FARM_PARAM_ERROR));

        // unstake all from pool
        let (own_asset_token, reward_token) = YieldFarming::unstake<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>
        >(account, STAR::token_address(), unwrap_harvest_cap);

        // Process reward token
        Account::deposit<STAR::STAR>(account_addr, reward_token);

        // Process asset token
        let withdraw_asset_token = Token::withdraw<LiquidityToken<X, Y>>(&mut own_asset_token, amount);
        TokenSwapRouter::deposit_liquidity_token<X, Y>(account_addr, withdraw_asset_token);

        let own_asset_amount = Token::value<LiquidityToken<X, Y>>(&own_asset_token);

        // Restake to pool
        let (new_harvest_cap, stake_id) = YieldFarming::stake<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>>(
            account,
            STAR::token_address(),
            own_asset_token,
            own_asset_amount,
            1,
            0,
            &farm_cap.cap
        );
        FarmPoolStake<X, Y>{
            cap: new_harvest_cap,
            id: stake_id,
        }
    }
}
}