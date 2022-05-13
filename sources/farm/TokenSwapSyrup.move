// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapSyrup {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Token;
    use StarcoinFramework::Event;
    use StarcoinFramework::Account;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Option;

    use SwapAdmin::STAR;
    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::YieldFarmingMultiplier;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeSyrup};
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapMultiPool;

    const ERROR_ADD_POOL_REPEATE: u64 = 101;
    const ERROR_TIME_CYCLE_INVALID: u64 = 102;
    const ERROR_STAKE_ID_INVALID: u64 = 103;
    const ERROR_HARVEST_STILL_LOCKING: u64 = 104;
    const ERROR_FARMING_STAKE_NOT_EXISTS: u64 = 105;
    const ERROR_FARMING_STAKE_TIME_NOT_EXISTS: u64 = 106;
    const ERROR_ALLOC_MODE_UPGRADE_SWITCH_NOT_TURNED_ON: u64 = 107;
    const ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON: u64 = 108;
    const ERROR_UPGRADE_EXTEND_INFO_HAS_EXISTS: u64 = 109;

    const ERROR_OBSOLETED_FUNCTION: u64 = 201;

    /// Syrup pool of token type
    struct Syrup<phantom TokenT> has key, store {
        /// Parameter modify capability for Syrup
        param_cap: YieldFarming::ParameterModifyCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        release_per_second: u128,
    }

    /// Syrup pool extend information
    /// OBSOLETED in v1.0.8
    struct SyrupExtInfo<phantom TokenT> has key, store {
        multiplier_cap: YieldFarmingMultiplier::PoolCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        alloc_point: u128,
    }

    struct SyrupExtInfo2<phantom TokenT> has key, store {
        multiplier_cap: TokenSwapMultiPool::MutiPoolCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        alloc_point: u128,
    }

    struct SyrupStakeList<phantom TokenT> has key, store {
        items: vector<SyrupStake<TokenT>>,
    }

    struct SyrupStake<phantom TokenT> has key, store {
        id: u64,
        /// Harvest capability for Syrup
        harvest_cap: YieldFarming::HarvestCapability<PoolTypeSyrup, Token::Token<TokenT>>,
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
        token_code: Token::TokenCode,
        /// signer of farm add
        signer: address,
        /// admin address
        admin: address,
    }

    /// Event emitted when farm been added
    struct ActivationStateEvent has drop, store {
        /// token code of X type
        token_code: Token::TokenCode,
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
        token_code: Token::TokenCode,
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
        token_code: Token::TokenCode,
        /// signer of stake user
        signer: address,
        /// admin address
        admin: address,
    }

    struct SyrupEvent has key, store {
        add_pool_event: Event::EventHandle<AddPoolEvent>,
        activation_state_event_handler: Event::EventHandle<ActivationStateEvent>,
        stake_event_handler: Event::EventHandle<StakeEvent>,
        unstake_event_handler: Event::EventHandle<UnstakeEvent>,
    }

    /// Initialize for Syrup pool
    public fun initialize(signer: &signer, token: Token::Token<STAR::STAR>) {
        YieldFarming::initialize<PoolTypeSyrup, STAR::STAR>(signer, token);

        move_to(signer, SyrupEvent{
            add_pool_event: Event::new_event_handle<AddPoolEvent>(signer),
            activation_state_event_handler: Event::new_event_handle<ActivationStateEvent>(signer),
            stake_event_handler: Event::new_event_handle<StakeEvent>(signer),
            unstake_event_handler: Event::new_event_handle<UnstakeEvent>(signer),
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

        let account = Signer::address_of(signer);
        assert!(!exists<Syrup<TokenT>>(account), ERROR_ADD_POOL_REPEATE);

        // Check alloc mode not turn on
        assert!(!TokenSwapConfig::get_alloc_mode_upgrade_switch(),
            Errors::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON));

        let param_cap = YieldFarming::add_asset<PoolTypeSyrup, Token::Token<TokenT>>(
            signer,
            release_per_second,
            delay);

        move_to(signer, Syrup<TokenT>{
            param_cap,
            release_per_second,
        });

        let event = borrow_global_mut<SyrupEvent>(account);
        Event::emit_event(&mut event.add_pool_event,
            AddPoolEvent{
                token_code: Token::token_code<TokenT>(),
                signer: Signer::address_of(signer),
                admin: account,
            });
    }

    /// Add syrup pool for token type v2
    public fun add_pool_v2<TokenT: store>(signer: &signer, alloc_point: u128, delay: u64) acquires SyrupEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let account = Signer::address_of(signer);
        assert!(!exists<Syrup<TokenT>>(account), ERROR_ADD_POOL_REPEATE);

        let param_cap =
            YieldFarming::add_asset_v2<PoolTypeSyrup, Token::Token<TokenT>>(signer, alloc_point, delay);

        move_to(signer, Syrup<TokenT>{
            param_cap,
            release_per_second: 0,
        });

        // Extend multiplier
        let multiplier_cap =
            TokenSwapMultiPool::init<PoolTypeSyrup, Token::Token<TokenT>>(signer, 0);
        move_to(signer, SyrupExtInfo2<TokenT>{
            alloc_point,
            multiplier_cap
        });

        // Publish event
        let event = borrow_global_mut<SyrupEvent>(account);
        Event::emit_event(&mut event.add_pool_event,
            AddPoolEvent{
                token_code: Token::token_code<TokenT>(),
                signer: Signer::address_of(signer),
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
            Errors::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON));

        let broker_addr = Signer::address_of(signer);
        let syrup = borrow_global_mut<Syrup<TokenT>>(broker_addr);

        let (alive, _, _, _, ) =
            YieldFarming::query_info<PoolTypeSyrup, Token::Token<TokenT>>(broker_addr);

        YieldFarming::modify_parameter<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
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
            Errors::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON));

        let broker_addr = Signer::address_of(signer);
        let syrup = borrow_global_mut<Syrup<TokenT>>(broker_addr);

        YieldFarming::modify_parameter<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            &syrup.param_cap,
            broker_addr,
            syrup.release_per_second,
            alive,
        );
    }

    /// Update pool allocation point
    /// Only called by admin
    public fun update_allocation_point<TokenT: store>(signer: &signer, alloc_point: u128) acquires Syrup, SyrupExtInfo2 {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        assert!(TokenSwapConfig::get_alloc_mode_upgrade_switch(),
            Errors::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_NOT_TURNED_ON));

        let broker = Signer::address_of(signer);
        let syrup = borrow_global<Syrup<TokenT>>(broker);
        let syrup_ext_info = borrow_global_mut<SyrupExtInfo2<TokenT>>(broker);

        YieldFarming::update_pool<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            &syrup.param_cap, broker, alloc_point, syrup_ext_info.alloc_point);
        syrup_ext_info.alloc_point = alloc_point;
    }


    /// Deposit Token into the pool
    public fun deposit<PoolType: store, TokenT: copy + drop + store>(
        account: &signer,
        token: Token::Token<TokenT>) {
        YieldFarming::deposit<PoolType, TokenT>(account, token);
    }

    /// View Treasury Remaining
    public fun get_treasury_balance<PoolType: store, TokenT: copy + drop + store>(): u128 {
        YieldFarming::get_treasury_balance<PoolType, TokenT>(STAR::token_address())
    }

    /// Stake token type to syrup
    /// @param: pledege_time per second
    public fun stake<TokenT: store>(signer: &signer, time_cycle: u64, amount: u128)
    acquires Syrup, SyrupStakeList, SyrupEvent, SyrupExtInfo2 {
        TokenSwapConfig::assert_global_freeze();
        assert!(time_cycle > 0, Errors::invalid_state(ERROR_TIME_CYCLE_INVALID));

        let user_addr = Signer::address_of(signer);
        let broker_addr = STAR::token_address();

        if (!Account::is_accept_token<STAR::STAR>(user_addr)) {
            Account::do_accept_token<STAR::STAR>(signer);
        };

        if (!exists<SyrupStakeList<TokenT>>(user_addr)) {
            move_to(signer, SyrupStakeList<TokenT>{
                items: Vector::empty<SyrupStake<TokenT>>(),
            });
        };

        let stake_token = Account::withdraw<TokenT>(signer, amount);
        let stepwise_multiplier = multiplier_from_timecycle<TokenT>(time_cycle);
        let now_seconds = Timestamp::now_seconds();
        let start_time = now_seconds;
        let end_time = start_time + time_cycle;

        let syrup = borrow_global<Syrup<TokenT>>(broker_addr);
        let (harvest_cap, id) = if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            // maybe upgrade under the upgrading switch turned on
            maybe_upgrade_all_stake<TokenT>(signer, &syrup.param_cap);

            YieldFarming::stake_v2<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
                signer,
                broker_addr,
                stake_token,
                amount * (stepwise_multiplier as u128),
                amount,
                stepwise_multiplier,
                time_cycle,
                &syrup.param_cap)
        } else {
            YieldFarming::stake<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
                signer,
                broker_addr,
                stake_token,
                amount,
                stepwise_multiplier,
                time_cycle,
                &syrup.param_cap)
        };

        // Save stake to list
        let stake_list = borrow_global_mut<SyrupStakeList<TokenT>>(user_addr);
        Vector::push_back<SyrupStake<TokenT>>(&mut stake_list.items, SyrupStake<TokenT>{
            id,
            harvest_cap,
            token_amount: amount,
            stepwise_multiplier,
            start_time,
            end_time,
        });

        // Handle mulitplier pool
        let ext_info = borrow_global_mut<SyrupExtInfo2<TokenT>>(broker_addr);
        TokenSwapMultiPool::add_stake<PoolTypeSyrup, Token::Token<TokenT>>(
            signer,
            time_cycle,
            id,
            amount,
            &ext_info.multiplier_cap);

        // Publish stake event to chain
        let event = borrow_global_mut<SyrupEvent>(broker_addr);
        Event::emit_event(&mut event.stake_event_handler,
            StakeEvent{
                token_code: Token::token_code<TokenT>(),
                signer: user_addr,
                amount,
                admin: broker_addr,
            });
    }

    /// Unstake from list
    /// @param: id, start with 1
    public fun unstake<TokenT: store>(signer: &signer, id: u64): (
        Token::Token<TokenT>,
        Token::Token<STAR::STAR>
    ) acquires SyrupStakeList, SyrupEvent, Syrup, SyrupExtInfo2 {
        TokenSwapConfig::assert_global_freeze();

        let user_addr = Signer::address_of(signer);
        let broker_addr = STAR::token_address();
        assert!(id > 0, Errors::invalid_state(ERROR_STAKE_ID_INVALID));

        let stake_list = borrow_global_mut<SyrupStakeList<TokenT>>(user_addr);
        let stake = get_stake<TokenT>(&stake_list.items, id);

        assert!(stake.id == id, Errors::invalid_state(ERROR_STAKE_ID_INVALID));
        assert!(stake.end_time < Timestamp::now_seconds(), Errors::invalid_state(ERROR_HARVEST_STILL_LOCKING));

        // Upgrade if alloc mode upgrade switch turned on
        let syrup = borrow_global<Syrup<TokenT>>(broker_addr);
        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            // maybe upgrade under the upgrading switch turned on
            maybe_upgrade_all_stake<TokenT>(signer, &syrup.param_cap);
        };

        let SyrupStake<TokenT>{
            id: _,
            harvest_cap,
            stepwise_multiplier: last_multiplier_factor,
            start_time: _,
            end_time: _,
            token_amount,
        } = pop_stake<TokenT>(&mut stake_list.items, id);


        // Remove asset from multiplier pool
        let (new_weight_factor, new_asset_weight) =
            TokenSwapMultiPool::calculate_suitable_weight<PoolTypeSyrup, Token::Token<TokenT>>(
                user_addr,
                id,
                Timestamp::now_seconds());

        YieldFarming::update_pool_stake_weight<PoolTypeSyrup, Token::Token<TokenT>>(
            &syrup.param_cap,
            broker_addr,
            user_addr,
            id,
            new_weight_factor,
            new_asset_weight,
            (token_amount * (last_multiplier_factor as u128)));

        let (
            unstaken_token,
            reward_token
        ) = YieldFarming::unstake<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(signer, broker_addr, harvest_cap);

        let ext_info = borrow_global_mut<SyrupExtInfo2<TokenT>>(broker_addr);
        TokenSwapMultiPool::remove_stake(signer, id, &ext_info.multiplier_cap);

        let event = borrow_global_mut<SyrupEvent>(broker_addr);
        Event::emit_event(&mut event.unstake_event_handler,
            UnstakeEvent{
                signer: user_addr,
                token_code: Token::token_code<TokenT>(),
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
        YieldFarming::query_total_stake<PoolTypeSyrup, Token::Token<TokenT>>(STAR::token_address())
    }

    public fun query_expect_gain<TokenT: store>(user_addr: address, id: u64): u128 acquires SyrupStakeList {
        let stake_list = borrow_global<SyrupStakeList<TokenT>>(user_addr);
        let stake = get_stake(&stake_list.items, id);
        YieldFarming::query_expect_gain<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            user_addr,
            STAR::token_address(),
            &stake.harvest_cap
        )
    }

    /// Query stake id list from user
    public fun query_stake_list<TokenT: store>(user_addr: address): vector<u64> {
        YieldFarming::query_stake_list<PoolTypeSyrup, Token::Token<TokenT>>(user_addr)
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
        YieldFarming::query_pool_info_v2<PoolTypeSyrup, Token::Token<TokenT>>(STAR::token_address())
    }

    /// Get current stake id
    public fun get_global_stake_id<TokenT: store>(user_addr: address): u64 {
        YieldFarming::get_global_stake_id<PoolTypeSyrup, Token::Token<TokenT>>(user_addr)
    }

    /// Put stepwise multiplier for syrup
    public fun put_multiplier_with_timecycle<TokenT: store>(signer: &signer,
                                                            time_cycle: u64,
                                                            multiplier: u64)
    acquires SyrupExtInfo2, Syrup {
        TokenSwapConfig::assert_admin(signer);

        let broker = TokenSwapConfig::admin_address();
        let (_, _, last_total_weight, _) = YieldFarming::query_pool_info_v2<PoolTypeSyrup, Token::Token<TokenT>>(broker);

        let ext_info = borrow_global_mut<SyrupExtInfo2<TokenT>>(TokenSwapConfig::admin_address());
        TokenSwapMultiPool::put_pool<PoolTypeSyrup, Token::Token<TokenT>>(
            signer, time_cycle, multiplier, &ext_info.multiplier_cap);

        let (
            _,
            pool_weight,
            no_pool_weight
        ) = TokenSwapMultiPool::query_tvl<PoolTypeSyrup, Token::Token<TokenT>>();

        let new_total_weight = no_pool_weight + pool_weight;
        let syrup = borrow_global_mut<Syrup<TokenT>>(broker);
        YieldFarming::update_pool_weight<PoolTypeSyrup, Token::Token<TokenT>>(
            &syrup.param_cap,
            broker,
            new_total_weight,
            last_total_weight);
    }

    public fun multiplier_from_timecycle<TokenT: store>(time_cycle: u64): u64 {
        let (multiplier, _, _) = TokenSwapMultiPool::query_pool_info<PoolTypeSyrup, Token::Token<TokenT>>(time_cycle);
        multiplier
    }

    /// TODO: OBSOLETED in v1.0.8
    public fun pledage_time_to_multiplier(_pledge_time_sec: u64): u64 {
        abort Errors::invalid_state(ERROR_OBSOLETED_FUNCTION)
    }

    fun get_stake<TokenT: store>(c: &vector<SyrupStake<TokenT>>, id: u64): &SyrupStake<TokenT> {
        let idx = find_idx_by_id<TokenT>(c, id);
        assert!(Option::is_some<u64>(&idx), Errors::invalid_state(ERROR_FARMING_STAKE_NOT_EXISTS));
        Vector::borrow(c, Option::destroy_some<u64>(idx))
    }

    fun pop_stake<TokenT: store>(c: &mut vector<SyrupStake<TokenT>>, id: u64): SyrupStake<TokenT> {
        let idx = find_idx_by_id<TokenT>(c, id);
        assert!(Option::is_some<u64>(&idx), Errors::invalid_state(ERROR_FARMING_STAKE_NOT_EXISTS));
        Vector::remove(c, Option::destroy_some<u64>(idx))
    }

    fun find_idx_by_id<TokenT: store>(c: &vector<SyrupStake<TokenT>>, id: u64): Option::Option<u64> {
        let len = Vector::length(c);
        if (len == 0) {
            return Option::none()
        };
        let idx = len - 1;
        loop {
            let el = Vector::borrow(c, idx);
            if (el.id == id) {
                return Option::some(idx)
            };
            if (idx == 0) {
                return Option::none()
            };
            idx = idx - 1;
        }
    }

    /// Syrup global information
    public fun upgrade_syrup_global(signer: &signer, pool_release_per_second: u128) {
        YieldFarming::initialize_global_pool_info<PoolTypeSyrup>(signer, pool_release_per_second);
    }

    /// Extend syrup pool for type
    public fun extend_syrup_pool<TokenT: store>(signer: &signer, override_update: bool) acquires SyrupExtInfo, SyrupExtInfo2 {
        STAR::assert_genesis_address(signer);

        let broker = Signer::address_of(signer);

        // Upgrade from SyrupExtInfo to SyrupExtInfo2
        let init_alloc_point = if (exists<SyrupExtInfo<TokenT>>(broker)) {
            let SyrupExtInfo<TokenT>{
                multiplier_cap,
                alloc_point
            } = move_from<SyrupExtInfo<TokenT>>(broker);
            YieldFarmingMultiplier::destroy_cap(multiplier_cap);
            alloc_point
        } else {
            50
        };

        let alloc_point = if (!exists<SyrupExtInfo2<TokenT>>(broker)) {
            let (_, _, asset_total_weight, _) = YieldFarming::query_pool_info_v2<PoolTypeSyrup, Token::Token<TokenT>>(broker);
            let multiplier_cap =
                TokenSwapMultiPool::init<PoolTypeSyrup, Token::Token<TokenT>>(signer, asset_total_weight);

            move_to(signer, SyrupExtInfo2<TokenT>{
                alloc_point: init_alloc_point,
                multiplier_cap
            });
            init_alloc_point
        } else {
            let syrup_ext_info = borrow_global<SyrupExtInfo2<TokenT>>(broker);
            syrup_ext_info.alloc_point
        };
        YieldFarming::extend_farming_asset<PoolTypeSyrup, Token::Token<TokenT>>(signer, alloc_point, override_update);
    }

    /// Upgrade all staking resource that
    /// two condition are matched that
    /// the upgrading switch has opened and new resource doesn't exist
    fun maybe_upgrade_all_stake<TokenT: store>(signer: &signer,
                                               cap: &YieldFarming::ParameterModifyCapability<PoolTypeSyrup, Token::Token<TokenT>>) {
        let account_addr = Signer::address_of(signer);

        // Check false if old stakes not exists or new stakes are exist
        if (!YieldFarming::exists_stake_at_address<PoolTypeSyrup, Token::Token<TokenT>>(account_addr) ||
            YieldFarming::exists_stake_list_extend<PoolTypeSyrup, Token::Token<TokenT>>(account_addr)) {
            return
        };

        // Access Control
        let stake_ids = YieldFarming::query_stake_list<PoolTypeSyrup, Token::Token<TokenT>>(account_addr);
        let len = Vector::length(&stake_ids);
        let idx = 0;
        loop {
            if (idx >= len) {
                break
            };

            let stake_id = Vector::borrow(&stake_ids, idx);
            YieldFarming::extend_farm_stake_info<PoolTypeSyrup, Token::Token<TokenT>>(signer, *stake_id, cap);

            idx = idx + 1;
        }
    }
}
}