// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
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
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeSyrup};
    use SwapAdmin::TokenSwapConfig;

    const ERROR_ADD_POOL_REPEATE: u64 = 101;
    const ERROR_PLEDAGE_TIME_INVALID: u64 = 102;
    const ERROR_STAKE_ID_INVALID: u64 = 103;
    const ERROR_HARVEST_STILL_LOCKING: u64 = 104;
    const ERROR_FARMING_STAKE_NOT_EXISTS: u64 = 105;
    const ERROR_FARMING_STAKE_TIME_NOT_EXISTS: u64 = 106;

    /// Syrup pool of token type
    struct Syrup<phantom TokenT> has key, store {
        /// Parameter modify capability for Syrup
        param_cap: YieldFarming::ParameterModifyCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        release_per_second: u128,
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

    /// Add syrup pool for token type
    public fun add_pool<TokenT: store>(signer: &signer,
                                       release_per_second: u128,
                                       delay: u64)
    acquires SyrupEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let account = Signer::address_of(signer);
        assert!(!exists<Syrup<TokenT>>(account), ERROR_ADD_POOL_REPEATE);

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

    /// Set release per second for token type pool
    public fun set_release_per_second<TokenT: copy + drop + store>(signer: &signer,
                                                                   release_per_second: u128) acquires Syrup {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

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

        let broker_addr = Signer::address_of(signer);
        let syrup = borrow_global_mut<Syrup<TokenT>>(broker_addr);

        YieldFarming::modify_parameter<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            &syrup.param_cap,
            broker_addr,
            syrup.release_per_second,
            alive,
        );
    }

    /// Stake token type to syrup
    /// @param: pledege_time per second
    public fun stake<TokenT: store>(signer: &signer,
                                    pledge_time_sec: u64,
                                    amount: u128) acquires Syrup, SyrupStakeList, SyrupEvent {
        TokenSwapConfig::assert_global_freeze();
        assert!(pledge_time_sec > 0, Errors::invalid_state(ERROR_PLEDAGE_TIME_INVALID));

        let user_addr = Signer::address_of(signer);
        let broker_addr = STAR::token_address();

        if (!Account::is_accept_token<STAR::STAR>(user_addr)) {
            Account::do_accept_token<STAR::STAR>(signer);
        };

        let stake_token = Account::withdraw<TokenT>(signer, amount);
        let stepwise_multiplier = pledage_time_to_multiplier(pledge_time_sec);

        let now_seconds = Timestamp::now_seconds();
        let start_time = now_seconds;
        let end_time = start_time + pledge_time_sec;

        let syrup = borrow_global<Syrup<TokenT>>(broker_addr);
        let (harvest_cap, id) = YieldFarming::stake<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            signer,
            broker_addr,
            stake_token,
            amount,
            stepwise_multiplier,
            pledge_time_sec,
            &syrup.param_cap);

        if (!exists<SyrupStakeList<TokenT>>(user_addr)) {
            move_to(signer, SyrupStakeList<TokenT>{
                items: Vector::empty<SyrupStake<TokenT>>(),
            });
        };

        let stake_list = borrow_global_mut<SyrupStakeList<TokenT>>(user_addr);

        Vector::push_back<SyrupStake<TokenT>>(&mut stake_list.items, SyrupStake<TokenT>{
            id,
            harvest_cap,
            token_amount: amount,
            stepwise_multiplier,
            start_time,
            end_time,
        });

        // Publish stake event to chain
        let event = borrow_global_mut<SyrupEvent>(broker_addr);
        Event::emit_event(&mut event.stake_event_handler,
            StakeEvent {
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
    ) acquires SyrupStakeList, SyrupEvent {
        TokenSwapConfig::assert_global_freeze();

        let user_addr = Signer::address_of(signer);
        let broker_addr = STAR::token_address();
        assert!(id > 0, Errors::invalid_state(ERROR_STAKE_ID_INVALID));

        let stake_list = borrow_global_mut<SyrupStakeList<TokenT>>(user_addr);
        let stake = get_stake<TokenT>(&stake_list.items, id);

        assert!(stake.id == id, Errors::invalid_state(ERROR_STAKE_ID_INVALID));
        assert!(stake.end_time < Timestamp::now_seconds(), Errors::invalid_state(ERROR_HARVEST_STILL_LOCKING));

        let SyrupStake<TokenT> {
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
        ) = YieldFarming::unstake<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(signer, broker_addr, harvest_cap);

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

    public fun query_expect_gain<TokenT: store>(user_addr: address, id: u64): u128 acquires SyrupStakeList  {
        let stake_list = borrow_global<SyrupStakeList<TokenT>>(user_addr);
        let stake = get_stake(&stake_list.items, id);
        YieldFarming::query_expect_gain<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            user_addr,
            STAR::token_address(),
            &stake.harvest_cap
        )
    }

    /// Query stake id list from user
    public fun query_stake_list<TokenT: store>(user_addr: address) : vector<u64> {
        YieldFarming::query_stake_list<PoolTypeSyrup, Token::Token<TokenT>>(user_addr)
    }

    /// query info for syrup pool
    public fun query_release_per_second<TokenT: store>(): u128 acquires Syrup {
        let syrup = borrow_global<Syrup<TokenT>>(STAR::token_address());
        syrup.release_per_second
    }

    public fun pledage_time_to_multiplier(pledge_time_sec: u64): u64 {
        // 1. Check the time has in config
        assert!(TokenSwapConfig::has_in_stepwise(pledge_time_sec),
            Errors::invalid_state(ERROR_FARMING_STAKE_TIME_NOT_EXISTS));

        // 2. return multiplier of time
        TokenSwapConfig::get_stepwise_multiplier(pledge_time_sec)
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
}
}