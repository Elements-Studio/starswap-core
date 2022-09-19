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
    use StarcoinFramework::BCS;

    use SwapAdmin::YieldFarmingMultiplier;
    use SwapAdmin::STAR;
    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::TokenSwapSyrupMultiplierPool;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeSyrup};
    use SwapAdmin::TokenSwapConfig;

    const ERR_DEPRECATED: u64 = 1;

    const ERROR_ADD_POOL_REPEATE: u64 = 101;
    const ERROR_PLEDAGE_TIME_INVALID: u64 = 102;
    const ERROR_STAKE_ID_INVALID: u64 = 103;
    const ERROR_HARVEST_STILL_LOCKING: u64 = 104;
    const ERROR_FARMING_STAKE_NOT_EXISTS: u64 = 105;
    const ERROR_FARMING_STAKE_TIME_NOT_EXISTS: u64 = 106;
    const ERROR_ALLOC_MODE_UPGRADE_SWITCH_NOT_TURNED_ON: u64 = 107;
    const ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON: u64 = 108;
    const ERROR_UPGRADE_EXTEND_INFO_HAS_EXISTS: u64 = 109;
    const ERROR_CONFIG_ERROR: u64 = 110;

    /// Syrup pool of token type
    struct Syrup<phantom TokenT> has key, store {
        /// Parameter modify capability for Syrup
        param_cap: YieldFarming::ParameterModifyCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        release_per_second: u128,
    }

    /// DEPRECATED
    /// Syrup pool extend information,
    struct SyrupExtInfo<phantom TokenT> has key, store {
        multiplier_cap: YieldFarmingMultiplier::PoolCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        alloc_point: u128,
    }

    /// Syrup pool extend information
    struct SyrupExtInfoV2<phantom TokenT> has key, store {
        multiplier_pool_cap: TokenSwapSyrupMultiplierPool::PoolCapability<PoolTypeSyrup, Token::Token<TokenT>>,
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

        move_to(signer, SyrupEvent {
            add_pool_event: Event::new_event_handle<AddPoolEvent>(signer),
            activation_state_event_handler: Event::new_event_handle<ActivationStateEvent>(signer),
            stake_event_handler: Event::new_event_handle<StakeEvent>(signer),
            unstake_event_handler: Event::new_event_handle<UnstakeEvent>(signer),
        });
    }

    /// TODO: Deprecated call
    /// Add syrup pool for token type
    public fun add_pool<TokenT: store>(
        _signer: &signer,
        _release_per_second: u128,
        _delay: u64
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // // Only called by the genesis
        // STAR::assert_genesis_address(signer);
        //
        // let account = Signer::address_of(signer);
        // assert!(!exists<Syrup<TokenT>>(account), ERROR_ADD_POOL_REPEATE);
        //
        // // Check alloc mode not turn on
        // assert!(!TokenSwapConfig::get_alloc_mode_upgrade_switch(),
        //     Errors::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_HAS_TURN_ON));
        //
        // let param_cap = YieldFarming::add_asset<PoolTypeSyrup, Token::Token<TokenT>>(
        //     signer,
        //     release_per_second,
        //     delay);
        //
        // move_to(signer, Syrup<TokenT>{
        //     param_cap,
        //     release_per_second,
        // });
        //
        // let event = borrow_global_mut<SyrupEvent>(account);
        // Event::emit_event(&mut event.add_pool_event,
        //     AddPoolEvent{
        //         token_code: Token::token_code<TokenT>(),
        //         signer: Signer::address_of(signer),
        //         admin: account,
        //     });
    }

    /// Add syrup pool for token type v2
    public fun add_pool_v2<TokenT: store>(
        signer: &signer,
        alloc_point: u128,
        delay: u64
    ) acquires SyrupEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let account = Signer::address_of(signer);
        assert!(!exists<Syrup<TokenT>>(account), ERROR_ADD_POOL_REPEATE);

        let param_cap =
            YieldFarming::add_asset_v2<PoolTypeSyrup, Token::Token<TokenT>>(signer, alloc_point, delay);

        move_to(signer, Syrup<TokenT> {
            param_cap,
            release_per_second: 0,
        });

        // Extend multiplier
        let multiplier_pool_cap =
            TokenSwapSyrupMultiplierPool::initialize<PoolTypeSyrup, Token::Token<TokenT>>(signer);
        move_to(signer, SyrupExtInfoV2<TokenT> {
            alloc_point,
            multiplier_pool_cap
        });

        // Publish event
        let event = borrow_global_mut<SyrupEvent>(account);
        Event::emit_event(&mut event.add_pool_event,
            AddPoolEvent {
                token_code: Token::token_code<TokenT>(),
                signer: Signer::address_of(signer),
                admin: account,
            });
    }

    /// Set release per second for token type pool
    public fun set_release_per_second<TokenT: copy + drop + store>(
        signer: &signer,
        release_per_second: u128
    ) acquires Syrup {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let syrup = borrow_global_mut<Syrup<TokenT>>(broker_addr());
        syrup.release_per_second = release_per_second;

        YieldFarming::modify_global_release_per_second<PoolTypeSyrup, Token::Token<TokenT>>(
            &syrup.param_cap, broker_addr(), release_per_second);
    }

    /// TODO: DEPRECATED call
    /// Set alivestate for token type pool
    public fun set_alive<TokenT: copy + drop + store>(_signer: &signer, _alive: bool) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// Set the each stepwise pool for statistical APR
    /// and subsequent calculations
    public fun put_stepwise_multiplier<TokenT: store>(
        signer: &signer,
        interval_sec: u64,
        multiplier: u64
    ) acquires SyrupExtInfoV2 {
        STAR::assert_genesis_address(signer);

        let broker_addr = broker_addr();
        let ext_v2  = borrow_global<SyrupExtInfoV2<TokenT>>(broker_addr);

        // TokenSwapConfig::put_stepwise_multiplier(signer, interval_sec, multiplier);
        TokenSwapSyrupMultiplierPool::add_pool<PoolTypeSyrup, Token::Token<TokenT>>(
            &ext_v2.multiplier_pool_cap,
            broker_addr(),
            &pledge_time_to_key(interval_sec),
            multiplier,
        );
    }

    /// Update pool allocation point
    /// Only called by admin
    public fun update_allocation_point<TokenT: store>(
        signer: &signer,
        alloc_point: u128
    ) acquires Syrup, SyrupExtInfoV2 {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        assert!(
            TokenSwapConfig::get_alloc_mode_upgrade_switch(),
            Errors::invalid_state(ERROR_ALLOC_MODE_UPGRADE_SWITCH_NOT_TURNED_ON)
        );

        let broker = Signer::address_of(signer);
        let syrup = borrow_global<Syrup<TokenT>>(broker);
        let syrup_ext_info = borrow_global_mut<SyrupExtInfoV2<TokenT>>(broker);

        YieldFarming::update_pool<
            PoolTypeSyrup,
            STAR::STAR,
            Token::Token<TokenT>
        >(
            &syrup.param_cap,
            broker,
            alloc_point,
            syrup_ext_info.alloc_point
        );
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
    public fun stake<TokenT: store>(
        signer: &signer,
        pledge_time_sec: u64,
        amount: u128
    ) acquires Syrup, SyrupStakeList, SyrupEvent, SyrupExtInfoV2 {
        TokenSwapConfig::assert_global_freeze();
        assert!(pledge_time_sec > 0, Errors::invalid_state(ERROR_PLEDAGE_TIME_INVALID));

        let user_addr = Signer::address_of(signer);
        let broker_addr = broker_addr();

        // Auto accept if not accept
        if (!Account::is_accept_token<STAR::STAR>(user_addr)) {
            Account::do_accept_token<STAR::STAR>(signer);
        };

        if (!exists<SyrupStakeList<TokenT>>(user_addr)) {
            move_to(signer, SyrupStakeList<TokenT> {
                items: Vector::empty<SyrupStake<TokenT>>(),
            });
        };

        let stake_token = Account::withdraw<TokenT>(signer, amount);
        let stepwise_multiplier = pledge_time_to_mulitplier<TokenT>(pledge_time_sec);
        let now_seconds = Timestamp::now_seconds();
        let start_time = now_seconds;
        let end_time = start_time + pledge_time_sec;

        let syrup = borrow_global<Syrup<TokenT>>(broker_addr);
        let syrup_ext = borrow_global<SyrupExtInfoV2<TokenT>>(broker_addr);

        // Add to multiplier pool
        TokenSwapSyrupMultiplierPool::add_amount<PoolTypeSyrup, Token::Token<TokenT>>(
            broker_addr,
            &syrup_ext.multiplier_pool_cap,
            &pledge_time_to_key(pledge_time_sec),
            amount,
        );

        let (
            harvest_cap,
            id
        ) = if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            // maybe upgrade under the upgrading switch turned on
            maybe_upgrade_all_stake<TokenT>(signer, &syrup.param_cap);

            YieldFarming::stake_v2<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
                signer,
                broker_addr,
                stake_token,
                amount * (stepwise_multiplier as u128),
                amount,
                stepwise_multiplier,
                pledge_time_sec,
                &syrup.param_cap
            )
        } else {
            YieldFarming::stake<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
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
        Vector::push_back<SyrupStake<TokenT>>(&mut stake_list.items, SyrupStake<TokenT> {
            id,
            harvest_cap,
            token_amount: amount,
            stepwise_multiplier,
            start_time,
            end_time,
        });

        // Publish stake event to chain
        let event = borrow_global_mut<SyrupEvent>(broker_addr());
        Event::emit_event(&mut event.stake_event_handler,
            StakeEvent {
                token_code: Token::token_code<TokenT>(),
                signer: user_addr,
                amount,
                admin: broker_addr(),
            });
    }

    /// Unstake from list
    /// @param: id, start with 1
    public fun unstake<TokenT: store>(signer: &signer, id: u64): (
        Token::Token<TokenT>,
        Token::Token<STAR::STAR>
    ) acquires SyrupStakeList, SyrupEvent, Syrup, SyrupExtInfoV2 {
        TokenSwapConfig::assert_global_freeze();

        let user_addr = Signer::address_of(signer);
        let broker_addr = broker_addr();
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

        let SyrupStake<TokenT> {
            id: _,
            harvest_cap,
            stepwise_multiplier: _,
            start_time,
            end_time,
            token_amount,
        } = pop_stake<TokenT>(&mut stake_list.items, id);

        let (
            unstaken_token,
            reward_token
        ) = YieldFarming::unstake<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            signer,
            broker_addr,
            harvest_cap
        );

        let syrup_ext = borrow_global_mut<SyrupExtInfoV2<TokenT>>(broker_addr);
        let key = pledge_time_to_key(end_time - start_time);
        TokenSwapSyrupMultiplierPool::remove_amount<PoolTypeSyrup, Token::Token<TokenT>>(
            broker_addr,
            &syrup_ext.multiplier_pool_cap,
            &key,
            token_amount,
        );

        let event = borrow_global_mut<SyrupEvent>(broker_addr);
        Event::emit_event(&mut event.unstake_event_handler,
            UnstakeEvent {
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
    public fun query_release_per_second<TokenT: store>(): u128 {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // let syrup = borrow_global<Syrup<TokenT>>(STAR::token_address());
        // syrup.release_per_second
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

    public fun pledage_time_to_multiplier(_pledge_time_sec: u64): u64 {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // // 1. Check the time has in config
        // assert!(TokenSwapConfig::has_in_stepwise(pledge_time_sec),
        //     Errors::invalid_state(ERROR_FARMING_STAKE_TIME_NOT_EXISTS));
        //
        // // 2. return multiplier of time
        // TokenSwapConfig::get_stepwise_multiplier(pledge_time_sec)
    }

    /// Query the magnification if the magnification statistics pool cannot be found,
    /// then go to the configuration to query the old one.
    public fun pledge_time_to_mulitplier<TokenT>(pledge_time_sec: u64): u64 {
        let key = pledge_time_to_key(pledge_time_sec);
        if (TokenSwapSyrupMultiplierPool::has<PoolTypeSyrup, Token::Token<TokenT>>(broker_addr(), &key)) {
            let (multiplier, _, _) = TokenSwapSyrupMultiplierPool::query_pool<
                PoolTypeSyrup,
                Token::Token<TokenT>
            >(broker_addr(), &key);
            multiplier
        } else {
            assert!(TokenSwapConfig::has_in_stepwise(pledge_time_sec),
                Errors::invalid_state(ERROR_FARMING_STAKE_TIME_NOT_EXISTS));
            TokenSwapConfig::get_stepwise_multiplier(pledge_time_sec)
        }
    }

    public fun pledge_time_to_key(pledge_time_sec: u64): vector<u8> {
        BCS::to_bytes<u64>(&pledge_time_sec)
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

    /// DEPRECATED
    /// Extend syrup pool for type
    public fun extend_syrup_pool<TokenT: store>(_signer: &signer, _override_update: bool) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // STAR::assert_genesis_address(signer);
        //
        // let broker = Signer::address_of(signer);
        //
        // let alloc_point = if (!exists<SyrupExtInfo<TokenT>>(broker)) {
        //     let multiplier_cap =
        //         YieldFarmingMultiplier::init<PoolTypeSyrup, Token::Token<TokenT>>(signer);
        //
        //     let alloc_point = 50;
        //     move_to(signer, SyrupExtInfo<TokenT>{
        //         alloc_point,
        //         multiplier_cap
        //     });
        //     alloc_point
        // } else {
        //     let syrup_ext_info = borrow_global<SyrupExtInfo<TokenT>>(broker);
        //     syrup_ext_info.alloc_point
        // };
        //
        // YieldFarming::extend_farming_asset<PoolTypeSyrup, Token::Token<TokenT>>(signer, alloc_point, override_update);
    }

    /// Upgrade all staking resource that
    /// two condition are matched that
    /// the upgrading switch has opened and new resource doesn't exist
    fun maybe_upgrade_all_stake<TokenT: store>(
        signer: &signer,
        cap: &YieldFarming::ParameterModifyCapability<PoolTypeSyrup, Token::Token<TokenT>>
    ) {
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

    public fun upgrade_from_v1_0_11_to_v1_0_12(account: &signer) acquires SyrupExtInfo {
        STAR::assert_genesis_address(account);
        let broker_addr = broker_addr();

        let SyrupExtInfo<STAR::STAR> {
            multiplier_cap,
            alloc_point,
        } = move_from<SyrupExtInfo<STAR::STAR>>(broker_addr);

        // Convert to new capability
        YieldFarmingMultiplier::uninitialize(multiplier_cap);

        let new_cap = TokenSwapSyrupMultiplierPool::initialize<
            PoolTypeSyrup,
            Token::Token<STAR::STAR>
        >(account);

        // Add pools from config
        let (
            time_list,
            multiplier_list
        ) = TokenSwapConfig::get_stepwise_multiplier_list();

        assert!(
            Vector::length(&time_list) == Vector::length(&multiplier_list),
            Errors::invalid_state(ERROR_CONFIG_ERROR)
        );

        loop {
            if (Vector::is_empty(&time_list)) {
                break
            };
            let time = Vector::pop_back(&mut time_list);
            let multiplier = Vector::pop_back(&mut multiplier_list);
            TokenSwapSyrupMultiplierPool::add_pool(
                &new_cap,
                broker_addr,
                &pledge_time_to_key(time),
                multiplier);
        };

        // Construct new struct of syrup info
        move_to(account, SyrupExtInfoV2<STAR::STAR> {
            alloc_point,
            multiplier_pool_cap: new_cap
        });
    }

    /// Initial Addtion multiplier amount for upgrade
    public fun addtion_pool_amount<TokenT: store>(
        account: &signer,
        key: &vector<u8>,
        amount: u128
    ) acquires SyrupExtInfoV2 {
        STAR::assert_genesis_address(account);

        let ext_v2 =
            borrow_global_mut<SyrupExtInfoV2<TokenT>>(broker_addr());
        TokenSwapSyrupMultiplierPool::addtion_pool_amount<PoolTypeSyrup, Token::Token<TokenT>>(
            broker_addr(),
            &ext_v2.multiplier_pool_cap,
            key,
            amount,
        );
    }

    fun broker_addr(): address {
        @SwapAdmin
    }
}
}