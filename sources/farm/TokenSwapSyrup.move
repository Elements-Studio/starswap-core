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
    use SwapAdmin::EventUtil;

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
    const ERROR_TOKEN_POOL_NOT_EXIST: u64 = 111;

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

    /// TODO: DEPRECATED Call
    /// Event emitted when farm been added
    struct AddPoolEvent has drop, store {
        /// token code of X type
        token_code: Token::TokenCode,
        /// signer of farm add
        signer: address,
        /// admin address
        admin: address,
    }

    /// TODO: DEPRECATED Call
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

    /// TODO: DEPRECATED Call
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

    /// TODO: DEPRECATED Call
    /// Event emitted when unstake been called
    struct UnstakeEvent has drop, store {
        /// token code of X type
        token_code: Token::TokenCode,
        /// signer of stake user
        signer: address,
        /// admin address
        admin: address,
    }

    /// TODO: DEPRECATED Call
    struct SyrupEvent has key, store {
        add_pool_event: Event::EventHandle<AddPoolEvent>,
        activation_state_event_handler: Event::EventHandle<ActivationStateEvent>,
        stake_event_handler: Event::EventHandle<StakeEvent>,
        unstake_event_handler: Event::EventHandle<UnstakeEvent>,
    }

    struct AddPoolEventV2 has drop, store {
        /// token code of X type
        token_code: Token::TokenCode,
        /// admin address
        admin: address,
        /// Alloc point
        alloc_point: u128,
        /// delay
        delay: u64,
    }

    struct AddPoolStepwiseEvent has drop, store {
        /// token code of X type
        token_code: Token::TokenCode,
        /// admin address
        admin: address,
        /// alloc point
        pledge_time: u64,
        /// multiplier
        multiplier: u64,
    }

    struct ModifyReleasePerSecondEvent has drop, store {
        /// token code of X type
        token_code: Token::TokenCode,
        /// admin address
        admin: address,
        /// release per second
        pool_release_per_second: u128,
    }

    struct UpdateAllocPointEvent has drop, store {
        /// token code of X type
        token_code: Token::TokenCode,
        /// admin address
        admin: address,
        /// alloc point
        alloc_point: u128,
    }

    /// Event emitted when stake been called
    struct StakeEventV2 has drop, store {
        /// token code of X type
        token_code: Token::TokenCode,
        /// signer of stake user
        signer: address,
        // value of stake user
        amount: u128,
        // admin address
        admin: address,
        // Amount
        pledge_time: u64,
        // Amount
        multiplier: u64,
    }

    /// Event emitted when unstake been called
    struct UnstakeEventV2 has drop, store {
        // token code of X type
        token_code: Token::TokenCode,
        // signer of stake user
        signer: address,
        // admin address
        admin: address,
        amount: u128,
        pledge_time: u64,
        multiplier: u64,
    }

    struct AddStepwiseEvent has drop, store {
        token_code: Token::TokenCode,
        admin: address,
        pledge_time: u64,
        multiplier: u64,
    }

    /// Initialize for Syrup pool
    public fun initialize(
        account: &signer,
        token: Token::Token<STAR::STAR>
    ) {
        YieldFarming::initialize<PoolTypeSyrup, STAR::STAR>(account, token);

        EventUtil::init_event<AddPoolEventV2>(account);
        EventUtil::init_event<UpdateAllocPointEvent>(account);
        EventUtil::init_event<StakeEventV2>(account);
        EventUtil::init_event<UnstakeEventV2>(account);
        EventUtil::init_event<AddStepwiseEvent>(account);
        EventUtil::init_event<AddPoolStepwiseEvent>(account);
        EventUtil::init_event<ModifyReleasePerSecondEvent>(account);
    }

    /// Initialized global pool
    public fun initialize_global_pool_info(
        account: &signer,
        pool_release_per_second: u128
    ) {
        YieldFarming::initialize_global_pool_info<PoolTypeSyrup>(account, pool_release_per_second);
    }

    /// TODO: DEPRECATED call
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
    ) {
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
        EventUtil::emit_event(
            broker_addr(),
            AddPoolEventV2 {
                token_code: Token::token_code<TokenT>(),
                admin: account,
                alloc_point,
                delay,
            }
        );
    }

    /// Set release per second for syrup pool
    public fun set_pool_release_per_second(
        signer: &signer,
        pool_release_per_second: u128
    ) {
        STAR::assert_genesis_address(signer);

        // Updated release per second for `PoolTypeSyrup`
        YieldFarming::modify_global_release_per_second_by_admin<PoolTypeSyrup>(
            signer,
            pool_release_per_second
        );
    }

    public fun update_token_pool_index<TokenT>(signer: &signer) acquires Syrup {
        STAR::assert_genesis_address(signer);

        assert!(
            exists<Syrup<TokenT>>(broker_addr()),
            Errors::invalid_state(ERROR_TOKEN_POOL_NOT_EXIST)
        );

        // Updated harvest index of token type
        let syrup = borrow_global_mut<Syrup<TokenT>>(broker_addr());
        YieldFarming::update_pool_index<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            &syrup.param_cap,
            broker_addr(),
        );
    }

    /// Set release per second for token type pool
    public fun set_release_per_second<TokenT: copy + drop + store>(
        _signer: &signer,
        _release_per_second: u128
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // // Only called by the genesis
        // STAR::assert_genesis_address(signer);
        //
        // let syrup = borrow_global_mut<Syrup<TokenT>>(broker_addr());
        // syrup.release_per_second = release_per_second;
        //
        // YieldFarming::modify_global_release_per_second_by_admin<PoolTypeSyrup>(
        //     signer,
        //     release_per_second
        // );
        //
        // let syrup_ext = borrow_global_mut<SyrupExtInfoV2<TokenT>>(broker_addr());
        // syrup.release_per_second = release_per_second;
        // YieldFarmingV3::update_pool<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
        //     &syrup.param_cap,
        //     broker_addr(),
        //     syrup_ext.alloc_point,
        //     syrup_ext.alloc_point,
        // );
        //
        // EventUtil::emit_event(
        //     broker_addr(),
        //     ModifyReleasePerSecondEvent {
        //         token_code: Token::token_code<TokenT>(),
        //         admin: broker_addr(),
        //         pool_release_per_second: release_per_second,
        //     }
        // );
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
        let ext_v2 = borrow_global<SyrupExtInfoV2<TokenT>>(broker_addr);

        // TokenSwapConfig::put_stepwise_multiplier(signer, interval_sec, multiplier);
        TokenSwapSyrupMultiplierPool::add_pool<PoolTypeSyrup, Token::Token<TokenT>>(
            &ext_v2.multiplier_pool_cap,
            broker_addr(),
            &pledge_time_to_key(interval_sec),
            multiplier,
        );

        EventUtil::emit_event<AddPoolStepwiseEvent>(
            broker_addr,
            AddPoolStepwiseEvent {
                token_code: Token::token_code<TokenT>(),
                admin: broker_addr,
                pledge_time: interval_sec,
                multiplier,
            }
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

        EventUtil::emit_event<UpdateAllocPointEvent>(
            broker,
            UpdateAllocPointEvent {
                token_code: Token::token_code<TokenT>(),
                admin: broker,
                alloc_point,
            }
        );
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
    ) acquires Syrup, SyrupStakeList, SyrupExtInfoV2 {
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
        EventUtil::emit_event(broker_addr,
            StakeEventV2 {
                token_code: Token::token_code<TokenT>(),
                signer: user_addr,
                amount,
                admin: broker_addr,
                pledge_time: pledge_time_sec,
                multiplier: stepwise_multiplier,
            });
    }

    /// Unstake from list
    /// @param: id, start with 1
    public fun unstake<TokenT: store>(signer: &signer, id: u64): (
        Token::Token<TokenT>,
        Token::Token<STAR::STAR>
    ) acquires SyrupStakeList, Syrup, SyrupExtInfoV2 {
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
            stepwise_multiplier,
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

        EventUtil::emit_event(
            broker_addr,
            UnstakeEventV2 {
                signer: user_addr,
                token_code: Token::token_code<TokenT>(),
                admin: broker_addr,
                amount: token_amount,
                pledge_time: end_time - start_time,
                multiplier: stepwise_multiplier,
            }
        );
        (unstaken_token, reward_token)
    }


    /// Get the pledge information represented by the specified id under the specified user in the pool
    /// @return (stake.start_time, stake.end_time, stake.stepwise_multiplier, stake.token_amount)
    ///
    public fun get_stake_info<TokenT: store>(
        user_addr: address,
        id: u64
    ): (u64, u64, u64, u128) acquires SyrupStakeList {
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

    /// Query the information of a certain pledge time in the multiplier pool
    /// (multiplier, asset_weight, asset_amount)
    public fun query_multiplier_pool_info<TokenT: store>(pledge_time: u64): (u64, u128, u128) {
        TokenSwapSyrupMultiplierPool::query_pool_by_key<PoolTypeSyrup, Token::Token<TokenT>>(
            broker_addr(),
            &pledge_time_to_key(pledge_time),
        )
    }

    /// Query all multiplier pools information
    public fun query_all_multiplier_pools<TokenT: store>(): (
        vector<u8>,
        vector<u64>,
        vector<u128>
    ) {
        TokenSwapSyrupMultiplierPool::query_all_pools<
            PoolTypeSyrup,
            Token::Token<TokenT>
        >(
            broker_addr(),
        )
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
            let (multiplier, _, _) = TokenSwapSyrupMultiplierPool::query_pool_by_key<
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

    /// TODO DEPRECATED
    /// Syrup global information
    public fun upgrade_syrup_global(_signer: &signer, _pool_release_per_second: u128) {
        // YieldFarming::initialize_global_pool_info<PoolTypeSyrup>(signer, pool_release_per_second);
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// TODO DEPRECATED
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

    /// Calculate the Total Weight and Total Amount from the multiplier pool and
    /// update them to YieldFarming
    ///
    public fun update_total_from_multiplier_pool<TokenT: store>(
        account: &signer,
    ) acquires Syrup {
        STAR::assert_genesis_address(account);
        let broker_addr = broker_addr();
        let (
            total_amount,
            total_weight
        ) = TokenSwapSyrupMultiplierPool::query_total_amount<
            PoolTypeSyrup,
            Token::Token<TokenT>
        >(
            broker_addr
        );

        let syrup = borrow_global<Syrup<TokenT>>(broker_addr);
        YieldFarming::adjust_total_amount<
            PoolTypeSyrup,
            Token::Token<TokenT>
        >(
            &syrup.param_cap,
            broker_addr,
            total_amount,
            total_weight
        );
    }

    /// Set amount for every Pledge time in multiplier pool
    /// This function will be forbidden in next version
    public fun set_multiplier_pool_amount<TokenT: store>(
        account: &signer,
        pledge_time: u64,
        amount: u128
    ) acquires SyrupExtInfoV2 {
        STAR::assert_genesis_address(account);

        let ext_v2 =
            borrow_global_mut<SyrupExtInfoV2<TokenT>>(broker_addr());

        TokenSwapSyrupMultiplierPool::set_pool_amount<PoolTypeSyrup, Token::Token<TokenT>>(
            broker_addr(),
            &ext_v2.multiplier_pool_cap,
            &pledge_time_to_key(pledge_time),
            amount,
        );
    }


    /// Upgrade from 1.0.11 to 1.0.12 Added the implementation of Multiplierpool,
    /// which is convenient for off-chain query values to calculate APR
    /// 1. Due to the addition of Multiplierpool,
    ///     all the pledge multipliers need to be transferred from Config to Multiplierpool
    /// 2. In addition, some event strcut have been transfered in to the `EventUtil` module
    ///     to ensure the extensibility of its code
    public fun upgrade_from_v1_0_11_to_v1_0_12<TokenT: store>(
        account: &signer
    ) acquires SyrupExtInfo, SyrupEvent, SyrupExtInfoV2 {
        STAR::assert_genesis_address(account);
        let broker_addr = Signer::address_of(account);

        //------------------------------------------//
        let alloc_point = if (exists<SyrupExtInfo<TokenT>>(broker_addr)) {
            let SyrupExtInfo<TokenT> {
                multiplier_cap,
                alloc_point,
            } = move_from<SyrupExtInfo<TokenT>>(broker_addr);

            // Convert to new capability
            YieldFarmingMultiplier::uninitialize(multiplier_cap);
            alloc_point
        } else {
            50
        };
        //------------------------------------------//

        //------------------------------------------//
        // Process syrup ext info
        if (!exists<SyrupExtInfoV2<TokenT>>(broker_addr)) {
            let new_cap =
                TokenSwapSyrupMultiplierPool::initialize<
                    PoolTypeSyrup,
                    Token::Token<TokenT>
                >(account);
            // Construct new struct of syrup info
            move_to(account, SyrupExtInfoV2<TokenT> {
                alloc_point,
                multiplier_pool_cap: new_cap
            });
        };
        let cap =
            &borrow_global_mut<SyrupExtInfoV2<TokenT>>(
                Signer::address_of(account)
            ).multiplier_pool_cap;

        //------------------------------------------//
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

            TokenSwapSyrupMultiplierPool::add_pool<PoolTypeSyrup, Token::Token<TokenT>>(
                cap,
                broker_addr,
                &pledge_time_to_key(time),
                multiplier
            );
        };
        //------------------------------------------//

        //------------------------------------------//
        // process event
        if (exists<SyrupEvent>(broker_addr)) {
            let SyrupEvent {
                add_pool_event,
                activation_state_event_handler,
                stake_event_handler,
                unstake_event_handler,
            } = move_from<SyrupEvent>(broker_addr);

            Event::destroy_handle(add_pool_event);
            Event::destroy_handle(activation_state_event_handler);
            Event::destroy_handle(stake_event_handler);
            Event::destroy_handle(unstake_event_handler);
        };

        // upgrade event
        if (!EventUtil::exist_event<AddPoolEventV2>(broker_addr)) {
            EventUtil::init_event<AddPoolEventV2>(account);
        };

        if (!EventUtil::exist_event<UpdateAllocPointEvent>(broker_addr)) {
            EventUtil::init_event<UpdateAllocPointEvent>(account);
        };

        if (!EventUtil::exist_event<StakeEventV2>(broker_addr)) {
            EventUtil::init_event<StakeEventV2>(account);
        };

        if (!EventUtil::exist_event<UnstakeEventV2>(broker_addr)) {
            EventUtil::init_event<UnstakeEventV2>(account);
        };

        if (!EventUtil::exist_event<AddStepwiseEvent>(broker_addr)) {
            EventUtil::init_event<AddStepwiseEvent>(account);
        };

        if (!EventUtil::exist_event<AddPoolStepwiseEvent>(broker_addr)) {
            EventUtil::init_event<AddPoolStepwiseEvent>(account);
        };

        if (!EventUtil::exist_event<ModifyReleasePerSecondEvent>(broker_addr)) {
            EventUtil::init_event<ModifyReleasePerSecondEvent>(account);
        };
        //------------------------------------------//
    }


    fun broker_addr(): address {
        @SwapAdmin
    }
}
}