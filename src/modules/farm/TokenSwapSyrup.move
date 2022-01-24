// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module TokenSwapSyrup {
    use 0x1::Signer;
    use 0x1::Token;
    use 0x1::Event;
    use 0x1::Account;
    use 0x1::Errors;
    use 0x1::Timestamp;
    use 0x1::Vector;
    use 0x1::Option;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovPoolType::{PoolTypeSyrup};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::YieldFarmingV3 as YieldFarming;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;

    const ERROR_ADD_POOL_REPEATE: u64 = 101;
    const ERROR_PLEDAGE_TIME_INVALID: u64 = 102;
    const ERROR_STAKE_ID_INVALID: u64 = 103;
    const ERROR_HARVEST_STILL_LOCKING: u64 = 104;
    const ERR_FARMING_STAKE_NOT_EXISTS: u64 = 105;

    /// Syrup pool of token type
    struct Syrup<TokenT> has key, store {
        /// Parameter modify capability for Syrup
        param_cap: YieldFarming::ParameterModifyCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        release_per_second: u128,
        multiplier: u64,
    }

    struct SyrupStakeList<TokenT> has key, store {
        items: vector<SyrupStake<TokenT>>,
    }

    struct SyrupStake<TokenT> has key, store {
        id: u64,
        /// Harvest capability for Syrup
        harvest_cap: YieldFarming::HarvestCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        /// Ladder multiplier
        ladder_multiplier: u64,
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
                                       multiplier: u64,
                                       delay: u64)
    acquires SyrupEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let account = Signer::address_of(signer);
        assert(!exists<Syrup<TokenT>>(account), ERROR_ADD_POOL_REPEATE);

        let param_cap = YieldFarming::add_asset<PoolTypeSyrup, Token::Token<TokenT>>(
            signer,
            release_per_second * (multiplier as u128),
            delay);

        move_to(signer, Syrup<TokenT>{
            param_cap,
            release_per_second,
            multiplier,
        });

        let event = borrow_global_mut<SyrupEvent>(account);
        Event::emit_event(&mut event.add_pool_event,
            AddPoolEvent{
                token_code: Token::token_code<TokenT>(),
                signer: Signer::address_of(signer),
                admin: account,
            });
    }

    /// Set farm mutiple of second per releasing
    public fun set_pool_multiplier<TokenT: copy + drop + store>(signer: &signer, multiplier: u64) acquires Syrup {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker_addr = Signer::address_of(signer);
        let syrup = borrow_global_mut<Syrup<TokenT>>(broker_addr);

        let (alive, _, _, _, ) =
            YieldFarming::query_info<PoolTypeSyrup, Token::Token<TokenT>>(broker_addr);

        YieldFarming::modify_parameter<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            &syrup.param_cap,
            broker_addr,
            syrup.release_per_second * (multiplier as u128),
            alive,
        );
        syrup.multiplier = multiplier;
    }

    /// Get farm mutiple of second per releasing
    public fun get_pool_multiplier<TokenT: copy + drop + store>(signer: &signer): u64 acquires Syrup {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);
        let syrup = borrow_global_mut<Syrup<TokenT>>(Signer::address_of(signer));
        syrup.multiplier
    }

    /// Stake token type to syrup
    public fun stake<TokenT: store>(signer: &signer,
                                    pledge_time: u64,
                                    amount: u128) acquires Syrup, SyrupStakeList, SyrupEvent {
        assert(pledge_time > 0, Errors::invalid_state(ERROR_PLEDAGE_TIME_INVALID));

        let user_addr = Signer::address_of(signer);
        let broker_addr = STAR::token_address();

        if (!Account::is_accept_token<STAR::STAR>(user_addr)) {
            Account::do_accept_token<STAR::STAR>(signer);
        };

        let stake_token = Account::withdraw<TokenT>(signer, amount);
        let ladder_multiplier = pledage_time_to_multiplier(pledge_time);

        let syrup = borrow_global<Syrup<TokenT>>(broker_addr);
        let (harvest_cap, id) = YieldFarming::stake<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            signer,
            broker_addr,
            stake_token,
            amount,
            ladder_multiplier,
            &syrup.param_cap);

        if (!exists<SyrupStakeList<TokenT>>(user_addr)) {
            move_to(signer, SyrupStakeList<TokenT>{
                items: Vector::empty<SyrupStake<TokenT>>(),
            });
        };

        let stake_list = borrow_global_mut<SyrupStakeList<TokenT>>(user_addr);
        let now_seconds = Timestamp::now_seconds();

        Vector::push_back<SyrupStake<TokenT>>(&mut stake_list.items, SyrupStake<TokenT>{
            id,
            harvest_cap,
            ladder_multiplier,
            start_time: now_seconds,
            end_time: now_seconds + pledge_time,
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

    public fun unstake<TokenT: store>(signer: &signer, id: u64) acquires SyrupStakeList, SyrupEvent {
        let user_addr = Signer::address_of(signer);
        let broker_addr = STAR::token_address();

        let stake_list = borrow_global_mut<SyrupStakeList<TokenT>>(broker_addr);
        let stake = get_stake<TokenT>(&stake_list.items, id);

        assert(stake.id == id, Errors::invalid_state(ERROR_STAKE_ID_INVALID));
        assert(stake.end_time < Timestamp::now_seconds(), Errors::invalid_state(ERROR_HARVEST_STILL_LOCKING));

        let SyrupStake<TokenT> {
            id: _,
            harvest_cap,
            ladder_multiplier: _,
            start_time: _,
            end_time: _,
        } = pop_stake<TokenT>(&mut stake_list.items, id);

        let (
            unstaken_token,
            reward_token
        ) = YieldFarming::unstake<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(signer, broker_addr, harvest_cap);

        Account::deposit<TokenT>(user_addr, unstaken_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);

        let event = borrow_global_mut<SyrupEvent>(broker_addr);
        Event::emit_event(&mut event.unstake_event_handler,
            UnstakeEvent{
                signer: user_addr,
                token_code: Token::token_code<TokenT>(),
                admin: broker_addr,
            });
    }

    public fun get_stake_info<TokenT: store>(signer: &signer, id: u64): (u64, u64, u64) acquires SyrupStakeList {
        let stake_list = borrow_global<SyrupStakeList<TokenT>>(Signer::address_of(signer));
        let stake = get_stake(&stake_list.items, id);
        (stake.start_time, stake.end_time, stake.ladder_multiplier)
    }

    public fun get_total_stake_amount<TokenT: store>(): u128 {
        YieldFarming::query_total_stake<PoolTypeSyrup, Token::Token<TokenT>>(STAR::token_address())
    }

    public fun pledage_time_to_multiplier(_pledge: u64): u64 {
        // TODO(9191stc): Load from config
        1
    }

    fun get_stake<TokenT: store>(c: &vector<SyrupStake<TokenT>>, id: u64): &SyrupStake<TokenT> {
        let idx = find_idx_by_id<TokenT>(c, id);
        assert(Option::is_none<u64>(&idx), Errors::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
        Vector::borrow(c, Option::destroy_some<u64>(idx))
    }

    fun pop_stake<TokenT: store>(c: &mut vector<SyrupStake<TokenT>>, id: u64): SyrupStake<TokenT> {
        let idx = find_idx_by_id<TokenT>(c, id);
        assert(Option::is_none<u64>(&idx), Errors::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
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