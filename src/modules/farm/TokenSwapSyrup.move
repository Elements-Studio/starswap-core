// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module TokenSwapSyrup {
    use 0x1::Signer;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::YieldFarming;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovPoolType::{PoolTypeSyrup};

    const ERROR_ADD_POOL_REPEATE: u64 = 101;

    /// Syrup pool of token type
    struct Syrup<TokenT> has key, store {
        /// Parameter modify capability for Syrup
        param_cap: YieldFarming::ParameterModifyCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        release_per_second: u128,
        multiple: u64,
    }

    struct SyrupHarvestCapability<TokenT> has key, store {
        /// Harvest capability for Syrup
        harvest_cap: YieldFarming::HarvestCapability<PoolTypeSyrup, Token::Token<TokenT>>,
        /// Time stamp of end staking, user can unstake/harvest after this point
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
    public fun initialze(signer: &signer, token: Token::Token<STAR::STAR>) {
        YieldFarming::initialize<PoolTypeSyrup, STAR::STAR>(account, token);

        move_to(account, SyrupEvent {
            add_pool_event: Event::new_event_handle<AddFarmEvent>(account),
            activation_state_event_handler: Event::new_event_handle<ActivationStateEvent>(account),
            stake_event_handler: Event::new_event_handle<StakeEvent>(account),
            unstake_event_handler: Event::new_event_handle<UnstakeEvent>(account),
        });
    }

    /// Add syrup pool for token type
    public fun add_pool<TokenT: store>(signer: &signer,
                                       release_per_second: u128,
                                       multiple: u64,
                                       delay: u64)
    acquires Syrup, SyrupEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let account = Signer::address_of(signer);
        assert(!exists<Syrup<TokenT>>(account), ERROR_ADD_POOL_REPEATE);

        let param_cap = YieldFarming::add_asset<PoolTypeSyrup, Token::Token<TokenT>>(
            signer,
            release_per_second * multiple,
            0);

        move_to(signer, Syrup<TokenT>{
            param_cap,
            release_per_second,
            multiple,
        });

        let event = borrow_global_mut<SyrupEvent>(account);
        Event::emit_event(&mut event.add_pool_event,
            AddPoolEvent {
                token_code: Token::token_code<TokenT>(),
                signer: Signer::address_of(signer),
                admin: account,
            });
    }

    /// Set farm mutiple of second per releasing
    public fun set_farm_multiple<TokenT: copy + drop + store>(signer: &signer, multiple: u64)
    acquires Syrup {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker = Signer::address_of(signer);
        let syrup = borrow_global<Syrup<TokenT>>(broker);

        let (alive, _, _, _, ) =
            YieldFarming::query_info<PoolTypeSyrup, Token::Token<TokenT>>(broker);

        YieldFarming::modify_parameter<PoolTypeSyrup, STAR::STAR, Token::Token<TokenT>>(
            &syrup.param_cap,
            broker,
            cap.release_per_second * (multiple as u128),
            alive,
        );
        syrup.multiple = multiple;
    }

    /// Get farm mutiple of second per releasing
    public fun get_farm_multiple<TokenT: copy + drop + store>(signer: &signer): u64 acquires Syrup {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker = Signer::address_of(signer);
        let syrup = borrow_global_mut<Syrup<TokenT>>(broker);
        syrup.multiple
    }

    /// Stake token type to
    public fun stake<TokenT: store>(signer: &signer,
                                    locking_time: u64,
                                    amount: u128) acquires SyrupEvent, SyrupHarvestCapability {
        let account_addr = Signer::address_of(signer);
        if (!Account::is_accept_token<STAR::STAR>(account_addr)) {
            Account::do_accept_token<STAR::STAR>(signer);
        };

        // Actual stake
        let syrup = borrow_global<Syrup<TokenT>>>(STAR::token_address());
        let own_token = if (YieldFarming::exists_stake_at_address<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(account_addr)) {
            let FarmHarvestCapability<X, Y>{ cap : unwrap_harvest_cap } =
                move_from<FarmHarvestCapability<X, Y>>(account_addr);

            // Unstake all liquidity token and reward token
            let (own_token, reward_token) = YieldFarming::unstake<
                PoolTypeFarmPool,
                STAR::STAR,
                Token::Token<LiquidityToken<X, Y>>
            >(signer, STAR::token_address(), unwrap_harvest_cap);
            Account::deposit<STAR::STAR>(account_addr, reward_token);
            own_token
        } else {
            Token::zero<LiquidityToken<X, Y>>()
        };

//        // Withdraw addtion token. Addtionally, combine addtion token and own token.
//        let addition_token = TokenSwapRouter::withdraw_liquidity_token<X, Y>(signer, amount);
//        let total_token = Token::join<LiquidityToken<X, Y>>(own_token, addition_token);
//        let total_amount = Token::value<LiquidityToken<X, Y>>(&total_token);

        let new_harvest_cap = YieldFarming::stake<
            PoolTypeFarmPool,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>>(
            signer,
            STAR::token_address(),
            total_token,
            total_amount,
            &farm_cap.cap
        );

        // Store a capability to account
        move_to(account, SyrupHarvestCapability<TokenT>{
            harvest_cap: new_harvest_cap,
            end_time: locking_time
        });

        // Emit stake event
        let event = borrow_global<SyrupEvent>(STAR::token_address());
        Event::emit_event(&mut event.stake_event_handler,
            StakeEvent{
                token_code: Token::token_code<TokenT>(),
                signer: account_addr,
                admin: STAR::token_address(),
                amount,
            });
    }

    public fun unstake<TokenT: store>() {

    }

    public fun harvest<TokenT: store>() {

    }

    public fun total_staked<TokenT: store>() {

    }
}
}