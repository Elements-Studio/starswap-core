// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapSyrup {
    use aptos_framework::coin;    
    use aptos_framework::account;
    use aptos_framework::timestamp;

    use aptos_std::event;
    use aptos_std::type_info;

    use std::error;
    use std::vector;
    use std::signer;
    use std::option;

    use SwapAdmin::STAR;
    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::YieldFarmingMultiplier;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeSyrup};
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::CommonHelper;

    const ERROR_ADD_POOL_REPEATE: u64 = 101;
    const ERROR_PLEDAGE_TIME_INVALID: u64 = 102;
    const ERROR_STAKE_ID_INVALID: u64 = 103;
    const ERROR_HARVEST_STILL_LOCKING: u64 = 104;
    const ERROR_FARMING_STAKE_NOT_EXISTS: u64 = 105;
    const ERROR_FARMING_STAKE_TIME_NOT_EXISTS: u64 = 106;
    const ERROR_ALLOC_MODE_UPGRADE_SWITCH_NOT_TURNED_ON: u64 = 107;
    const ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON: u64 = 108;
    const ERROR_UPGRADE_EXTEND_INFO_HAS_EXISTS: u64 = 109;

    /// Syrup pool of token type
    struct Syrup<phantom TokenT> has key, store {
        /// Parameter modify capability for Syrup
        param_cap: YieldFarming::ParameterModifyCapability<PoolTypeSyrup, coin::Coin<TokenT>>,
        release_per_second: u128,
    }

    /// Syrup pool extend information
    struct SyrupExtInfo<phantom TokenT> has key, store {
        multiplier_cap: YieldFarmingMultiplier::PoolCapability<PoolTypeSyrup, coin::Coin<TokenT>>,
        alloc_point: u128,
    }

    struct SyrupStakeList<phantom TokenT> has key, store {
        items: vector<SyrupStake<TokenT>>,
    }

    struct SyrupStake<phantom TokenT> has key, store {
        id: u64,
        /// Harvest capability for Syrup
        harvest_cap: YieldFarming::HarvestCapability<PoolTypeSyrup, coin::Coin<TokenT>>,
        /// Stepwise multiplier
        stepwise_multiplier: u64,
        /// Stake amount
        token_amount: u128,
        /// The time stamp of start staking
        start_time: u64,
        /// The time stamp of end staking, user can unstake/harvest after this point
        end_time: u64,
    }

    /// Event emitted when farm been added
    struct AddPoolEvent has drop, store {
        /// token code of X type
        type_info: type_info::TypeInfo,
        /// signer of farm add
        signer: address,
        /// admin address
        admin: address,
    }

    /// Event emitted when farm been added
    struct ActivationStateEvent has drop, store {
        /// token code of X type
        type_info: type_info::TypeInfo,
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
        type_info: type_info::TypeInfo,
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
        type_info: type_info::TypeInfo,
        /// signer of stake user
        signer: address,
        /// admin address
        admin: address,
    }

    struct SyrupEvent has key, store {
        add_pool_event: event::EventHandle<AddPoolEvent>,
        activation_state_event_handler: event::EventHandle<ActivationStateEvent>,
        stake_event_handler: event::EventHandle<StakeEvent>,
        unstake_event_handler: event::EventHandle<UnstakeEvent>,
    }

    /// Initialize for Syrup pool
    public fun initialize(signer: &signer, token: coin::Coin<STAR::STAR>) {
        YieldFarming::initialize<PoolTypeSyrup, STAR::STAR>(signer, token);

        move_to(signer, SyrupEvent{
            add_pool_event: account::new_event_handle<AddPoolEvent>(signer),
            activation_state_event_handler: account::new_event_handle<ActivationStateEvent>(signer),
            stake_event_handler: account::new_event_handle<StakeEvent>(signer),
            unstake_event_handler: account::new_event_handle<UnstakeEvent>(signer),
        });
    }

    /// TODO: Deprecated call
    /// Add syrup pool for token type
    public fun add_pool<TokenT: store>(signer: &signer,
                                       release_per_second: u128,
                                       delay: u64)
    acquires SyrupEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let account = signer::address_of(signer);
        assert!(!exists<Syrup<TokenT>>(account), ERROR_ADD_POOL_REPEATE);

        // Check alloc mode not turn on
        assert!(!TokenSwapConfig::get_alloc_mode_upgrade_switch(),
            error::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON));

        let param_cap = YieldFarming::add_asset<PoolTypeSyrup, coin::Coin<TokenT>>(
            signer,
            release_per_second,
            delay);

        move_to(signer, Syrup<TokenT>{
            param_cap,
            release_per_second,
        });

        let event = borrow_global_mut<SyrupEvent>(account);
        event::emit_event(&mut event.add_pool_event,
            AddPoolEvent{
                type_info: type_info::type_of<TokenT>(),
                signer: signer::address_of(signer),
                admin: account,
            });
    }

    /// Add syrup pool for token type v2
    public fun add_pool_v2<TokenT: store>(signer: &signer, alloc_point: u128, delay: u64) acquires SyrupEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let account = signer::address_of(signer);
        assert!(!exists<Syrup<TokenT>>(account), ERROR_ADD_POOL_REPEATE);

        let param_cap =
            YieldFarming::add_asset_v2<PoolTypeSyrup, coin::Coin<TokenT>>(signer, alloc_point, delay);

        move_to(signer, Syrup<TokenT>{
            param_cap,
            release_per_second: 0,
        });

        // Extend multiplier
        let multiplier_cap =
            YieldFarmingMultiplier::init<PoolTypeSyrup, coin::Coin<TokenT>>(signer);
        move_to(signer, SyrupExtInfo<TokenT>{
            alloc_point,
            multiplier_cap
        });

        // Publish event
        let event = borrow_global_mut<SyrupEvent>(account);
        event::emit_event(&mut event.add_pool_event,
            AddPoolEvent{
                type_info: type_info::type_of<TokenT>(),
                signer: signer::address_of(signer),
                admin: account,
            });
    }

    /// Set release per second for token type pool
    public fun set_release_per_second<TokenT: copy + drop + store>(signer: &signer,
                                                                   release_per_second: u128) acquires Syrup {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        // Check alloc mode has turn on
        assert!(!TokenSwapConfig::get_alloc_mode_upgrade_switch(),
            error::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON));

        let broker_addr = signer::address_of(signer);
        let syrup = borrow_global_mut<Syrup<TokenT>>(broker_addr);

        let (alive, _, _, _, ) =
            YieldFarming::query_info<PoolTypeSyrup, coin::Coin<TokenT>>(broker_addr);

        YieldFarming::modify_parameter<PoolTypeSyrup, STAR::STAR, coin::Coin<TokenT>>(
            &syrup.param_cap,
            broker_addr,
            release_per_second,
            alive,
        );
        syrup.release_per_second = release_per_second;
    }

    /// Set alivestate for token type pool
    public fun set_alive<TokenT: copy + drop + store>(signer: &signer, alive: bool) acquires Syrup {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        // Check alloc mode has turn on
        assert!(!TokenSwapConfig::get_alloc_mode_upgrade_switch(),
            error::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON));

        let broker_addr = signer::address_of(signer);
        let syrup = borrow_global_mut<Syrup<TokenT>>(broker_addr);

        YieldFarming::modify_parameter<PoolTypeSyrup, STAR::STAR, coin::Coin<TokenT>>(
            &syrup.param_cap,
            broker_addr,
            syrup.release_per_second,
            alive,
        );
    }

    /// Update pool allocation point
    /// Only called by admin
    public fun update_allocation_point<TokenT: store>(signer: &signer, alloc_point: u128) acquires Syrup, SyrupExtInfo {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        assert!(TokenSwapConfig::get_alloc_mode_upgrade_switch(),
            error::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_NOT_TURNED_ON));

        let broker = signer::address_of(signer);
        let syrup = borrow_global<Syrup<TokenT>>(broker);
        let syrup_ext_info = borrow_global_mut<SyrupExtInfo<TokenT>>(broker);

        YieldFarming::update_pool<PoolTypeSyrup, STAR::STAR, coin::Coin<TokenT>>(
            &syrup.param_cap, broker, alloc_point, syrup_ext_info.alloc_point);
        syrup_ext_info.alloc_point = alloc_point;
    }


    /// Deposit Token into the pool
    public fun deposit<PoolType: store, TokenT: copy + drop + store>(
        account: &signer,
        token: coin::Coin<TokenT>) {
        YieldFarming::deposit<PoolType, TokenT>(account, token);
    }

    /// View Treasury Remaining
    public fun get_treasury_balance<PoolType: store, TokenT: copy + drop + store>(): u128 {
        YieldFarming::get_treasury_balance<PoolType, TokenT>(STAR::token_address())
    }

    /// Stake token type to syrup
    /// @param: pledege_time per second
    public fun stake<TokenT: store>(signer: &signer, pledge_time_sec: u64, amount: u128)
    acquires Syrup, SyrupStakeList, SyrupEvent {
        TokenSwapConfig::assert_global_freeze();
        assert!(pledge_time_sec > 0, error::invalid_state(ERROR_PLEDAGE_TIME_INVALID));

        let user_addr = signer::address_of(signer);
        let broker_addr = STAR::token_address();

        CommonHelper::safe_accept_token<STAR::STAR>(signer);

        if (!exists<SyrupStakeList<TokenT>>(user_addr)) {
            move_to(signer, SyrupStakeList<TokenT>{
                items: vector::empty<SyrupStake<TokenT>>(),
            });
        };

        let stake_token = coin::withdraw<TokenT>(signer, (amount as u64));
        let stepwise_multiplier = pledage_time_to_multiplier(pledge_time_sec);
        let now_seconds = timestamp::now_seconds();
        let start_time = now_seconds;
        let end_time = start_time + pledge_time_sec;

        let syrup = borrow_global<Syrup<TokenT>>(broker_addr);
        let (harvest_cap, id) = if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            // maybe upgrade under the upgrading switch turned on
            maybe_upgrade_all_stake<TokenT>(signer, &syrup.param_cap);

            YieldFarming::stake_v2<PoolTypeSyrup, STAR::STAR, coin::Coin<TokenT>>(
                signer,
                broker_addr,
                stake_token,
                amount * (stepwise_multiplier as u128),
                amount,
                stepwise_multiplier,
                pledge_time_sec,
                &syrup.param_cap)
        } else {
            YieldFarming::stake<PoolTypeSyrup, STAR::STAR, coin::Coin<TokenT>>(
                signer,
                broker_addr,
                stake_token,
                amount,
                stepwise_multiplier,
                pledge_time_sec,
                &syrup.param_cap)
        };

        // Save stake to list
        let stake_list = borrow_global_mut<SyrupStakeList<TokenT>>(user_addr);
        vector::push_back<SyrupStake<TokenT>>(&mut stake_list.items, SyrupStake<TokenT>{
            id,
            harvest_cap,
            token_amount: amount,
            stepwise_multiplier,
            start_time,
            end_time,
        });

        // Publish stake event to chain
        let event = borrow_global_mut<SyrupEvent>(broker_addr);
        event::emit_event(&mut event.stake_event_handler,
            StakeEvent{
                type_info: type_info::type_of<TokenT>(),
                signer: user_addr,
                amount,
                admin: broker_addr,
            });
    }

    /// Unstake from list
    /// @param: id, start with 1
    public fun unstake<TokenT: store>(signer: &signer, id: u64): (
        coin::Coin<TokenT>,
        coin::Coin<STAR::STAR>
    ) acquires SyrupStakeList, SyrupEvent, Syrup {
        TokenSwapConfig::assert_global_freeze();

        let user_addr = signer::address_of(signer);
        let broker_addr = STAR::token_address();
        assert!(id > 0, error::invalid_state(ERROR_STAKE_ID_INVALID));

        let stake_list = borrow_global_mut<SyrupStakeList<TokenT>>(user_addr);
        let stake = get_stake<TokenT>(&stake_list.items, id);

        assert!(stake.id == id, error::invalid_state(ERROR_STAKE_ID_INVALID));
        assert!(stake.end_time < timestamp::now_seconds(), error::invalid_state(ERROR_HARVEST_STILL_LOCKING));

        // Upgrade if alloc mode upgrade switch turned on
        let syrup = borrow_global<Syrup<TokenT>>(broker_addr);
        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            // maybe upgrade under the upgrading switch turned on
            maybe_upgrade_all_stake<TokenT>(signer, &syrup.param_cap);
        };

        let SyrupStake<TokenT>{
            id: _,
            harvest_cap,
            stepwise_multiplier: _,
            start_time: _,
            end_time: _,
            token_amount: _,
        } = pop_stake<TokenT>(&mut stake_list.items, id);

        let (
            unstaken_token,
            reward_token
        ) = YieldFarming::unstake<PoolTypeSyrup, STAR::STAR, coin::Coin<TokenT>>(signer, broker_addr, harvest_cap);

        let event = borrow_global_mut<SyrupEvent>(broker_addr);
        event::emit_event(&mut event.unstake_event_handler,
            UnstakeEvent{
                signer: user_addr,
                type_info: type_info::type_of<TokenT>(),
                admin: broker_addr,
            });

        (unstaken_token, reward_token)
    }


    public fun get_stake_info<TokenT: store>(user_addr: address, id: u64): (u64, u64, u64, u128) acquires SyrupStakeList {
        let stake_list = borrow_global<SyrupStakeList<TokenT>>(user_addr);
        let stake = get_stake(&stake_list.items, id);
        (
            stake.start_time,
            stake.end_time,
            stake.stepwise_multiplier,
            stake.token_amount
        )
    }

    public fun query_total_stake<TokenT: store>(): u128 {
        YieldFarming::query_total_stake<PoolTypeSyrup, coin::Coin<TokenT>>(STAR::token_address())
    }

    public fun query_expect_gain<TokenT: store>(user_addr: address, id: u64): u128 acquires SyrupStakeList {
        let stake_list = borrow_global<SyrupStakeList<TokenT>>(user_addr);
        let stake = get_stake(&stake_list.items, id);
        YieldFarming::query_expect_gain<PoolTypeSyrup, STAR::STAR, coin::Coin<TokenT>>(
            user_addr,
            STAR::token_address(),
            &stake.harvest_cap
        )
    }

    /// Query stake id list from user
    public fun query_stake_list<TokenT: store>(user_addr: address): vector<u64> {
        YieldFarming::query_stake_list<PoolTypeSyrup, coin::Coin<TokenT>>(user_addr)
    }

    /// query info for syrup pool
    public fun query_release_per_second<TokenT: store>(): u128 acquires Syrup {
        let syrup = borrow_global<Syrup<TokenT>>(STAR::token_address());
        syrup.release_per_second
    }

    /// Queyry global pool info
    /// return value: (total_alloc_point, pool_release_per_second)
    public fun query_syrup_info(): (u128, u128) {
        YieldFarming::query_global_pool_info<PoolTypeSyrup>(STAR::token_address())
    }

    /// Query pool info from pool type v2
    /// return value: (alloc_point, asset_total_amount, asset_total_weight, harvest_index)
    public fun query_pool_info_v2<TokenT: store>(): (u128, u128, u128, u128) {
        YieldFarming::query_pool_info_v2<PoolTypeSyrup, coin::Coin<TokenT>>(STAR::token_address())
    }

    /// Get current stake id
    public fun get_global_stake_id<TokenT: store>(user_addr: address): u64 {
        YieldFarming::get_global_stake_id<PoolTypeSyrup, coin::Coin<TokenT>>(user_addr)
    }

    public fun pledage_time_to_multiplier(pledge_time_sec: u64): u64 {
        // 1. Check the time has in config
        assert!(TokenSwapConfig::has_in_stepwise(pledge_time_sec),
            error::invalid_state(ERROR_FARMING_STAKE_TIME_NOT_EXISTS));

        // 2. return multiplier of time
        TokenSwapConfig::get_stepwise_multiplier(pledge_time_sec)
    }

    fun get_stake<TokenT: store>(c: &vector<SyrupStake<TokenT>>, id: u64): &SyrupStake<TokenT> {
        let idx = find_idx_by_id<TokenT>(c, id);
        assert!(option::is_some<u64>(&idx), error::invalid_state(ERROR_FARMING_STAKE_NOT_EXISTS));
        vector::borrow(c, option::destroy_some<u64>(idx))
    }

    fun pop_stake<TokenT: store>(c: &mut vector<SyrupStake<TokenT>>, id: u64): SyrupStake<TokenT> {
        let idx = find_idx_by_id<TokenT>(c, id);
        assert!(option::is_some<u64>(&idx), error::invalid_state(ERROR_FARMING_STAKE_NOT_EXISTS));
        vector::remove(c, option::destroy_some<u64>(idx))
    }

    fun find_idx_by_id<TokenT: store>(c: &vector<SyrupStake<TokenT>>, id: u64): option::Option<u64> {
        let len = vector::length(c);
        if (len == 0) {
            return option::none()
        };
        let idx = len - 1;
        loop {
            let el = vector::borrow(c, idx);
            if (el.id == id) {
                return option::some(idx)
            };
            if (idx == 0) {
                return option::none()
            };
            idx = idx - 1;
        }
    }

    /// Syrup global information
    public fun upgrade_syrup_global(signer: &signer, pool_release_per_second: u128) {
        YieldFarming::initialize_global_pool_info<PoolTypeSyrup>(signer, pool_release_per_second);
    }

    /// Extend syrup pool for type
    public fun extend_syrup_pool<TokenT: store>(signer: &signer, override_update: bool) acquires SyrupExtInfo {
        STAR::assert_genesis_address(signer);

        let broker = signer::address_of(signer);

        let alloc_point = if (!exists<SyrupExtInfo<TokenT>>(broker)) {
            let multiplier_cap =
                YieldFarmingMultiplier::init<PoolTypeSyrup, coin::Coin<TokenT>>(signer);

            let alloc_point = 50;
            move_to(signer, SyrupExtInfo<TokenT>{
                alloc_point,
                multiplier_cap
            });
            alloc_point
        } else {
            let syrup_ext_info = borrow_global<SyrupExtInfo<TokenT>>(broker);
            syrup_ext_info.alloc_point
        };

        YieldFarming::extend_farming_asset<PoolTypeSyrup, coin::Coin<TokenT>>(signer, alloc_point, override_update);
    }

    /// Upgrade all staking resource that
    /// two condition are matched that
    /// the upgrading switch has opened and new resource doesn't exist
    fun maybe_upgrade_all_stake<TokenT: store>(signer: &signer,
                                               cap: &YieldFarming::ParameterModifyCapability<PoolTypeSyrup, coin::Coin<TokenT>>) {
        let account_addr = signer::address_of(signer);

        // Check false if old stakes not exists or new stakes are exist
        if (!YieldFarming::exists_stake_at_address<PoolTypeSyrup, coin::Coin<TokenT>>(account_addr) ||
            YieldFarming::exists_stake_list_extend<PoolTypeSyrup, coin::Coin<TokenT>>(account_addr)) {
            return
        };

        // Access Control
        let stake_ids = YieldFarming::query_stake_list<PoolTypeSyrup, coin::Coin<TokenT>>(account_addr);
        let len = vector::length(&stake_ids);
        let idx = 0;
        loop {
            if (idx >= len) {
                break
            };

            let stake_id = vector::borrow(&stake_ids, idx);
            YieldFarming::extend_farm_stake_info<PoolTypeSyrup, coin::Coin<TokenT>>(signer, *stake_id, cap);

            idx = idx + 1;
        }
    }
}