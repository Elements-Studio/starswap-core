// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapFarm {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Event;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Signature;
    use StarcoinFramework::BCS;

    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwap::LiquidityToken;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeFarmPool};
    use SwapAdmin::TokenSwapFarmBoost;

    const ERR_DEPRECATED: u64 = 1;

    const ERR_FARM_PARAM_ERROR: u64 = 101;
    const ERR_WHITE_LIST_BOOST_IS_OPEN: u64 = 102;
    const ERR_WHITE_LIST_BOOST_SIGN_IS_NULL: u64 = 103;
    const ERR_WHITE_LIST_BOOST_IS_NOT_WL_USER: u64 = 104;

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
        release_per_seconds: u128, //abandoned fields
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


    /// Initialize farm big pool
    public fun initialize_farm_pool(
        account: &signer,
        token: Token::Token<STAR::STAR>
    ) {
        YieldFarming::initialize<PoolTypeFarmPool, STAR::STAR>(account, token);

        move_to(account, FarmPoolEvent{
            add_farm_event_handler: Event::new_event_handle<AddFarmEvent>(account),
            activation_state_event_handler: Event::new_event_handle<ActivationStateEvent>(account),
            stake_event_handler: Event::new_event_handle<StakeEvent>(account),
            unstake_event_handler: Event::new_event_handle<UnstakeEvent>(account),
        });
    }

    /// Called by admin
    /// this will config yield farming global pool info
    public fun initialize_global_pool_info(
        account: &signer,
        pool_release_per_second: u128
    ) {
        // Only called by the genesis
        STAR::assert_genesis_address(account);
        YieldFarming::initialize_global_pool_info<PoolTypeFarmPool>(account, pool_release_per_second);
    }

    /// DEPRECATED call
    /// Initialize Liquidity pair gov pool, only called by token issuer
    public fun add_farm<X: copy + drop + store,
                        Y: copy + drop + store>(
        _signer: &signer,
        _release_per_seconds: u128
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // // Only called by the genesis
        // STAR::assert_genesis_address(signer);
        //
        // // To determine how many amount release in every period
        // let cap = YieldFarming::add_asset<
        //     PoolTypeFarmPool,
        //     Token::Token<LiquidityToken<X, Y>>>(
        //     signer,
        //     release_per_seconds,
        //     0
        // );
        //
        // move_to(signer, FarmPoolCapability<X, Y>{
        //     cap,
        //     release_per_seconds,
        // });
        //
        // move_to(signer, FarmMultiplier<X, Y>{
        //     multiplier: 1
        // });
        //
        // // Emit add farm event
        // let admin = Signer::address_of(signer);
        // let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin);
        // Event::emit_event(
        //     &mut farm_pool_event.add_farm_event_handler,
        //     AddFarmEvent {
        //         y_token_code: Token::token_code<X>(),
        //         x_token_code: Token::token_code<Y>(),
        //         signer: Signer::address_of(signer),
        //         admin,
        //     });
    }


    /// Initialize Liquidity pair gov pool, only called by token issuer
    public fun add_farm_v2<X: copy + drop + store,
                           Y: copy + drop + store>(
        signer: &signer,
        alloc_point: u128
    ) acquires FarmPoolEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        // To determine how many amount release in every period
        let cap = YieldFarming::add_asset_v2<
            PoolTypeFarmPool,
            Token::Token<LiquidityToken<X, Y>>
        >(
            signer,
            alloc_point,
            0
        );

        move_to(signer, FarmPoolCapability<X, Y>{
            cap,
            release_per_seconds: 0, //abandoned fields
        });

        move_to(signer, FarmPoolInfo<X, Y>{
            alloc_point
        });

        // Emit add farm event
        let admin = Signer::address_of(signer);
        let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin);
        Event::emit_event(
            &mut farm_pool_event.add_farm_event_handler,
            AddFarmEvent{
                y_token_code: Token::token_code<X>(),
                x_token_code: Token::token_code<Y>(),
                signer: Signer::address_of(signer),
                admin,
            }
        );
    }


    /// call only for extend
    public fun extend_farm_pool<X: copy + drop + store,
                                 Y: copy + drop + store>(
        _account: &signer,
        _override_update: bool
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // STAR::assert_genesis_address(account);
        //
        // let broker = Signer::address_of(account);
        // let farm_multiplier = borrow_global<FarmMultiplier<X, Y>>(broker);
        // let alloc_point = (farm_multiplier.multiplier as u128);
        // YieldFarming::extend_farming_asset<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, alloc_point, override_update);
        //
        // if(!exists<FarmPoolInfo<X, Y>>(broker)){
        //     move_to(account, FarmPoolInfo<X, Y>{
        //         alloc_point
        //     });
        // }else {
        //     let farm_pool_info = borrow_global_mut<FarmPoolInfo<X, Y>>(broker);
        //     farm_pool_info.alloc_point = alloc_point;
        // };
    }


    /// DEPRECATED call
    /// Set farm mutiplier of second per releasing
    public fun set_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>(
        _signer: &signer,
        _multiplier: u64
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // // Only called by the genesis
        // STAR::assert_genesis_address(signer);
        //
        // let broker = Signer::address_of(signer);
        // let cap = borrow_global<FarmPoolCapability<X, Y>>(broker);
        // let farm_mult = borrow_global_mut<FarmMultiplier<X, Y>>(broker);
        //
        // let (alive, _, _, _, ) =
        //     YieldFarming::query_info<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(broker);
        //
        // let relese_per_sec_mul = cap.release_per_seconds * (multiplier as u128);
        // YieldFarming::modify_parameter<PoolTypeFarmPool, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
        //     &cap.cap,
        //     broker,
        //     relese_per_sec_mul,
        //     alive,
        // );
        // farm_mult.multiplier = multiplier;
    }

    /// Get farm multiplier of second per releasing
    public fun get_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>()
    : u64 acquires FarmMultiplier, FarmPoolInfo {
        if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()){
            let farm_mult = borrow_global_mut<FarmMultiplier<X, Y>>(STAR::token_address());
            farm_mult.multiplier
            // Get farm mutiplier, equals to pool alloc_point
        } else {
            let farm_pool_info = borrow_global<FarmPoolInfo<X, Y>>(STAR::token_address());
            (farm_pool_info.alloc_point as u64)
        }
    }


    public fun set_farm_alloc_point<X: copy + drop + store,
                                    Y: copy + drop + store>(
        signer: &signer,
        alloc_point: u128
    ) acquires FarmPoolCapability, FarmPoolInfo, FarmPoolEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker = Signer::address_of(signer);
        let cap = borrow_global<FarmPoolCapability<X, Y>>(broker);
        let farm_pool_info = borrow_global_mut<FarmPoolInfo<X, Y>>(broker);
        let last_alloc_point = farm_pool_info.alloc_point;

        YieldFarming::update_pool<PoolTypeFarmPool, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
            &cap.cap,
            broker,
            alloc_point,
            farm_pool_info.alloc_point,
        );
        farm_pool_info.alloc_point = alloc_point;

        if (alloc_point == 0 || last_alloc_point == 0) {
            let farm_pool_event = borrow_global_mut<FarmPoolEvent>(broker);
            Event::emit_event(
                &mut farm_pool_event.activation_state_event_handler,
                ActivationStateEvent {
                    y_token_code: Token::token_code<X>(),
                    x_token_code: Token::token_code<Y>(),
                    signer: broker,
                    admin: broker,
                    activation_state: (alloc_point > 0),
                }
            );
        };
    }

    /// DEPRECATED call
    /// Reset activation of farm from token type X and Y
    public fun reset_farm_activation<X: copy + drop + store,
                                     Y: copy + drop + store>(
        _account: &signer,
        _active: bool
    )  {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // STAR::assert_genesis_address(account);
        // let admin_addr = Signer::address_of(account);
        // let cap = borrow_global_mut<FarmPoolCapability<X, Y>>(admin_addr);
        //
        // YieldFarming::modify_parameter<
        //     PoolTypeFarmPool,
        //     STAR::STAR,
        //     Token::Token<LiquidityToken<X, Y>>
        // >(
        //     &cap.cap,
        //     admin_addr,
        //     cap.release_per_seconds,
        //     active,
        // );
        //
        // let farm_pool_event = borrow_global_mut<FarmPoolEvent>(admin_addr);
        // Event::emit_event(&mut farm_pool_event.activation_state_event_handler,
        //     ActivationStateEvent{
        //         y_token_code: Token::token_code<X>(),
        //         x_token_code: Token::token_code<Y>(),
        //         signer: Signer::address_of(account),
        //         admin: admin_addr,
        //         activation_state: active,
        //     });
    }

    //Deposit Token into the pool
    public fun deposit<PoolType: store, TokenT: copy + drop + store>(
        account: &signer,
        token: Token::Token<TokenT>
    ) {
        YieldFarming::deposit<PoolType, TokenT>(account, token);
    }

    //View Treasury Remaining
    public fun get_treasury_balance<PoolType: store, TokenT: copy + drop + store>(): u128 {
        YieldFarming::get_treasury_balance<PoolType, TokenT>(STAR::token_address())
    }

    /// Stake liquidity Token pair
    public fun stake<X: copy + drop + store, Y: copy + drop + store>(
        account: &signer,
        amount: u128
    ) acquires FarmPoolCapability, FarmPoolEvent, FarmPoolStake {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = Signer::address_of(account);
        if (!Account::is_accept_token<STAR::STAR>(account_addr)) {
            Account::do_accept_token<STAR::STAR>(account);
        };

        // after pool alloc mode upgrade
        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            //check if need extend
            if (YieldFarming::exists_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr) &&
                (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr))) {
                extend_farm_stake_resource<X, Y>(account);
            };
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

    fun extend_farm_stake_resource<X: copy + drop + store,
                                   Y: copy + drop + store>(
        account: &signer
    ) acquires FarmPoolCapability {
        let account_addr = Signer::address_of(account);
        //double check if need extend
        if (!(YieldFarming::exists_stake_at_address<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr) &&
              (!YieldFarming::exists_stake_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)))) {
            return
        };

        // Access Control
        let farm_cap = borrow_global_mut<FarmPoolCapability<X, Y>>(STAR::token_address());

        let stake_ids = YieldFarming::query_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr);
        let len = Vector::length(&stake_ids);
        let idx = 0;
        loop {
            if (idx >= len) {
                break
            };
            let stake_id = Vector::borrow(&stake_ids, idx);
            YieldFarming::extend_farm_stake_info<
                PoolTypeFarmPool,
                Token::Token<LiquidityToken<X, Y>>
            >(
                account,
                *stake_id,
                &farm_cap.cap
            );

            idx = idx + 1;
        }
    }


    /// Unstake liquidity Token pair
    public fun unstake<X: copy + drop + store,
                       Y: copy + drop + store>(
        account: &signer,
        amount: u128
    ) acquires FarmPoolCapability, FarmPoolStake, FarmPoolEvent {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = Signer::address_of(account);
        // after pool alloc mode upgrade
        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            //check if need extend
            if (YieldFarming::exists_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr) &&
                (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr))) {
                extend_farm_stake_resource<X, Y>(account);
            };
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
                       Y: copy + drop + store>(
        account: &signer,
        amount: u128
    ) acquires FarmPoolStake, FarmPoolCapability {
        TokenSwapConfig::assert_global_freeze();

        let account_addr = Signer::address_of(account);
        // after pool alloc mode upgrade
        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            //check if need extend
            if (YieldFarming::exists_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr) &&
                (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr))) {
                extend_farm_stake_resource<X, Y>(account);
            };
        };

        let farm_harvest_cap = borrow_global_mut<FarmPoolStake<X, Y>>(account_addr);
        let token = YieldFarming::harvest<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>
        >(
            account_addr,
            STAR::token_address(),
            amount,
            &farm_harvest_cap.cap,
        );
        Account::deposit<STAR::STAR>(account_addr, token);

        let farm = borrow_global<FarmPoolStake<X, Y>>(account_addr);
        let farm_cap = borrow_global<FarmPoolCapability<X, Y>>(STAR::token_address());
        TokenSwapFarmBoost::update_boost_for_farm_pool<X,Y>(&farm_cap.cap,account,farm.id); 
    }

    /// Return calculated APY
    public fun lookup_gain<X: copy + drop + store,
                           Y: copy + drop + store>(
        account: address
    ): u128 acquires FarmPoolStake {
        if (exists<FarmPoolStake<X, Y>>(account)) {
            let farm = borrow_global<FarmPoolStake<X, Y>>(account);
            YieldFarming::query_expect_gain<PoolTypeFarmPool, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
                account, STAR::token_address(), &farm.cap)
        } else {
            0
        }
    }

    /// Query all stake info
    public fun query_info<X: copy + drop + store,
                          Y: copy + drop + store>()
    : (
        bool,
        u128,
        u128,
        u128
    ) {
        abort  Errors::invalid_state(ERR_DEPRECATED)
        //YieldFarming::query_info<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query pool info from pool type v2
    /// return value: (alloc_point, asset_total_amount, asset_total_weight, harvest_index)
    public fun query_info_v2<X: copy + drop + store,
                             Y: copy + drop + store>()
    : (
        u128,
        u128,
        u128,
        u128
    ) {
        YieldFarming::query_pool_info_v2<
            PoolTypeFarmPool,
            Token::Token<LiquidityToken<X, Y>>
        >(STAR::token_address())
    }

    /// Query all stake amount
    public fun query_total_stake<X: copy + drop + store, Y: copy + drop + store>(): u128 {
        YieldFarming::query_total_stake<
            PoolTypeFarmPool,
            Token::Token<LiquidityToken<X, Y>>
        >(STAR::token_address())
    }

    /// Query stake amount from user
    public fun query_stake<X: copy + drop + store,
                           Y: copy + drop + store>(
        account: address
    ): u128 acquires FarmPoolStake {
        if (exists<FarmPoolStake<X, Y>>(account)) {
            let farm = borrow_global<FarmPoolStake<X, Y>>(account);
            YieldFarming::query_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account, farm.id)
        } else{
            0
        }
    }

    /// Query release per second
    public fun query_release_per_second<X: copy + drop + store,
                                        Y: copy + drop + store>()
    : u128 acquires FarmPoolCapability, FarmPoolInfo {
        if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()){
            let cap = borrow_global<FarmPoolCapability<X, Y>>(STAR::token_address());
            cap.release_per_seconds
        } else {
            let farm_pool_info = borrow_global<FarmPoolInfo<X, Y>>(STAR::token_address());
            let (
                total_alloc_point,
                pool_release_per_second
            ) = YieldFarming::query_global_pool_info<PoolTypeFarmPool>(
                STAR::token_address()
            );
            pool_release_per_second * farm_pool_info.alloc_point / total_alloc_point
        }
    }

    /// Query farm golbal pool info
    public fun query_global_pool_info(): (u128, u128) {
        let (
            total_alloc_point,
            pool_release_per_second
        ) = YieldFarming::query_global_pool_info<PoolTypeFarmPool>(
            STAR::token_address()
        );
        (total_alloc_point, pool_release_per_second)
    }


    /// Inner stake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_stake<X: copy + drop + store,
                    Y: copy + drop + store>(
        account: &signer,
        amount: u128,
        farm_cap: &FarmPoolCapability<X, Y>
    ): FarmPoolStake<X, Y> acquires FarmPoolStake {
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

        // after pool alloc mode upgrade
        let (new_harvest_cap, stake_id) = if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            YieldFarming::stake<
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
            )
        } else {
            // predict boost factor
            let new_weight_factor = TokenSwapFarmBoost::predict_boost_factor<X, Y>(account_addr, total_amount);

            let asset_weight = TokenSwapFarmBoost::calculate_boost_weight(total_amount, new_weight_factor);
            TokenSwapFarmBoost::set_boost_factor<X, Y>(&farm_cap.cap, account, new_weight_factor);

            YieldFarming::stake_v2<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>>(
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

        FarmPoolStake<X, Y>{
            cap: new_harvest_cap,
            id: stake_id,
        }
    }

    /// Inner unstake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_unstake<X: copy + drop + store,
                      Y: copy + drop + store>(
        account: &signer,
        amount: u128,
        farm_cap: &FarmPoolCapability<X, Y>,
        farm_stake: FarmPoolStake<X, Y>
    ): FarmPoolStake<X, Y> {
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
        // after pool alloc mode upgrade
        let (new_harvest_cap, stake_id) = if (!TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            YieldFarming::stake<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>
            >(
                account,
                STAR::token_address(),
                own_asset_token,
                own_asset_amount,
                1,
                0,
                &farm_cap.cap
            )
        } else {
            // once farm unstake, user boost factor lose efficacy, become 1
            TokenSwapFarmBoost::unboost_from_farm_pool<X, Y>(&farm_cap.cap, account);
            let weight_factor = TokenSwapFarmBoost::get_boost_factor<X, Y>(account_addr);
            let own_asset_weight = TokenSwapFarmBoost::calculate_boost_weight(own_asset_amount, weight_factor);
            YieldFarming::stake_v2<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>>(
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

        FarmPoolStake<X, Y>{
            cap: new_harvest_cap,
            id: stake_id,
        }
    }

    /// boost for farm
    public fun boost<X: copy + drop + store,
                     Y: copy + drop + store>(
        account: &signer,
        boost_amount: u128)
    acquires FarmPoolStake, FarmPoolCapability {
        let user_addr = Signer::address_of(account);
        let (is_white_list_boost,_) = TokenSwapConfig::get_white_list_boost_switch();
        assert!( ! is_white_list_boost ,ERR_WHITE_LIST_BOOST_IS_OPEN);
        // after pool alloc mode upgrade
        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            //check if need extend
            if (YieldFarming::exists_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(user_addr) &&
                (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(user_addr))) {
                extend_farm_stake_resource<X, Y>(account);
            };
        };

        let farm = borrow_global<FarmPoolStake<X, Y>>(user_addr);
        let farm_cap = borrow_global<FarmPoolCapability<X, Y>>(@SwapAdmin);
        TokenSwapFarmBoost::boost_to_farm_pool<X, Y>(&farm_cap.cap, account, boost_amount, farm.id)
    }

    /// boost for farm
    public fun wl_boost<X: copy + drop + store,
                        Y: copy + drop + store>(
        account: &signer,
        boost_amount: u128,
        signature: &vector<u8>
    )acquires FarmPoolStake, FarmPoolCapability {
        let user_addr = Signer::address_of(account);
        let (
            is_white_list_boost,
            white_list_pubkey
        ) = TokenSwapConfig::get_white_list_boost_switch();

        if (is_white_list_boost) {
            assert!(
                Signature::ed25519_verify(
                    *signature,
                    white_list_pubkey,
                    BCS::to_bytes(&user_addr)
                ),
                Errors::invalid_state(ERR_WHITE_LIST_BOOST_IS_NOT_WL_USER)
            );
        };

        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            //check if need extend
            if (YieldFarming::exists_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(user_addr) &&
                (!YieldFarming::exists_stake_list_extend<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(user_addr))) {
                extend_farm_stake_resource<X, Y>(account);
            };
        };

        let farm = borrow_global<FarmPoolStake<X, Y>>(user_addr);
        let farm_cap = borrow_global<FarmPoolCapability<X, Y>>(@SwapAdmin);
        TokenSwapFarmBoost::boost_to_farm_pool<X, Y>(&farm_cap.cap, account, boost_amount, farm.id)
    }


    #[test]
    fun test_wl_boost(){
        use StarcoinFramework::Signature;
        use StarcoinFramework::BCS;

        let public_key =  x"d6da1bea14990ad936a848c2a375a2c105d5038ce726ed03f8700998c4e840b5";
        let message = @0xc5578819fD7Ab114AbB77F1596A0fdb4;
        let signature = x"773c9540497ee99eefa3679e04debe8ed3690f44dcaa9dbe9326ff2958559b5ded7e165886fa845c8acbbc0571ad24a4fced0e1ee239358b3857d0165a09a40d";
        assert!(Signature::ed25519_verify(signature, public_key, BCS::to_bytes(&message)), 1001);
    }
}
}