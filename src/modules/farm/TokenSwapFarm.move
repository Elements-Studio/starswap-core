// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module TokenSwapFarm {
    use 0x1::Signer;
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Event;
    use 0x1::Errors;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::YieldFarmingV3 as YieldFarming;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwap::LiquidityToken;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovPoolType::{PoolTypeLiquidityMint};

    const ERR_FARM_PARAM_ERROR: u64 = 101;

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

    struct FarmCapability<X, Y> has key, store {
        cap: YieldFarming::ParameterModifyCapability<PoolTypeLiquidityMint, Token::Token<LiquidityToken<X, Y>>>,
        release_per_seconds: u128,
    }

    struct FarmMultiplier<X, Y> has key, store {
        multiplier: u64,
    }

    struct FarmStake<X, Y> has key, store {
        id: u64,
        /// Harvest capability for Farm
        cap: YieldFarming::HarvestCapability<PoolTypeLiquidityMint, Token::Token<LiquidityToken<X, Y>>>,
    }

    /// Initialize farm big pool
    public fun initialize_farm_pool(account: &signer, token: Token::Token<STAR::STAR>) {
        YieldFarming::initialize<
            PoolTypeLiquidityMint,
            STAR::STAR>(account, token);

        move_to(account, FarmPoolEvent{
            add_farm_event_handler: Event::new_event_handle<AddFarmEvent>(account),
            activation_state_event_handler: Event::new_event_handle<ActivationStateEvent>(account),
            stake_event_handler: Event::new_event_handle<StakeEvent>(account),
            unstake_event_handler: Event::new_event_handle<UnstakeEvent>(account),
        });
    }

    /// Initialize Liquidity pair gov pool, only called by token issuer
    public fun add_farm<X: copy + drop + store,
                        Y: copy + drop + store>(
        signer: &signer,
        release_per_seconds: u128) acquires FarmPoolEvent {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        // To determine how many amount release in every period
        let cap = YieldFarming::add_asset<PoolTypeLiquidityMint, Token::Token<LiquidityToken<X, Y>>>(
            signer,
            release_per_seconds,
            0);

        move_to(signer, FarmCapability<X, Y>{
            cap,
            release_per_seconds,
        });

        move_to(signer, FarmMultiplier<X, Y>{
            multiplier: 1
        });

        //// TODO (9191stc): Add to DAO
        // GovernanceDaoProposal::plugin<
        //    PoolTypeProposal<X, Y, GovTokenT>,
        //    GovTokenT>(account, modify_cap);

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

    /// Set farm mutiple of second per releasing
    public fun set_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>(signer: &signer, multiplier: u64)
    acquires FarmCapability, FarmMultiplier {
        // Only called by the genesis
        STAR::assert_genesis_address(signer);

        let broker = Signer::address_of(signer);
        let cap = borrow_global<FarmCapability<X, Y>>(broker);
        let farm_mult = borrow_global_mut<FarmMultiplier<X, Y>>(broker);

        let (alive, _, _, _, ) =
            YieldFarming::query_info<PoolTypeLiquidityMint, Token::Token<LiquidityToken<X, Y>>>(broker);

        let relese_per_sec_mul = cap.release_per_seconds * (multiplier as u128);
        YieldFarming::modify_parameter<PoolTypeLiquidityMint, STAR::STAR, Token::Token<LiquidityToken<X, Y>>>(
            &cap.cap,
            broker,
            relese_per_sec_mul,
            alive,
        );
        farm_mult.multiplier = multiplier;
    }

    /// Get farm mutiple of second per releasing
    public fun get_farm_multiplier<X: copy + drop + store,
                                   Y: copy + drop + store>(): u64 acquires FarmMultiplier {
        let farm_mult = borrow_global_mut<FarmMultiplier<X, Y>>(STAR::token_address());
        farm_mult.multiplier
    }

    /// Reset activation of farm from token type X and Y
    public fun reset_farm_activation<X: copy + drop + store, Y: copy + drop + store>(
        account: &signer,
        active: bool) acquires FarmPoolEvent, FarmCapability {
        STAR::assert_genesis_address(account);
        let admin_addr = Signer::address_of(account);
        let cap = borrow_global_mut<FarmCapability<X, Y>>(admin_addr);

        YieldFarming::modify_parameter<
            PoolTypeLiquidityMint,
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
    acquires FarmCapability, FarmStake, FarmPoolEvent {
        let account_addr = Signer::address_of(account);
        if (!Account::is_accept_token<STAR::STAR>(account_addr)) {
            Account::do_accept_token<STAR::STAR>(account);
        };

        // Actual stake
        let farm_cap = borrow_global_mut<FarmCapability<X, Y>>(STAR::token_address());
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

    /// Unstake liquidity Token pair
    public fun unstake<X: copy + drop + store,
                       Y: copy + drop + store>(account: &signer,
                                               amount: u128)
    acquires FarmCapability, FarmStake, FarmPoolEvent {
        let account_addr = Signer::address_of(account);
        // Actual stake
        let farm_cap = borrow_global_mut<FarmCapability<X, Y>>(STAR::token_address());
        let farm_harvest_cap = move_from<FarmStake<X, Y>>(account_addr);
        let harvest_cap = inner_unstake<X, Y>(account, amount, farm_cap, farm_harvest_cap);

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
                       Y: copy + drop + store>(account: &signer, amount: u128) acquires FarmStake {
        let account_addr = Signer::address_of(account);
        let farm_harvest_cap = borrow_global_mut<FarmStake<X, Y>>(account_addr);

        let token = YieldFarming::harvest<
            PoolTypeLiquidityMint,
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
    public fun lookup_gain<X: copy + drop + store, Y: copy + drop + store>(account: address): u128 acquires FarmStake {
        let farm = borrow_global<FarmStake<X, Y>>(account);
        YieldFarming::query_expect_gain<
            PoolTypeLiquidityMint,
            STAR::STAR,
            Token::Token<LiquidityToken<X, Y>>
        >(account, STAR::token_address(), &farm.cap)
    }

    /// Query all stake amount
    public fun query_info<X: copy + drop + store, Y: copy + drop + store>(): (bool, u128, u128, u128) {
        YieldFarming::query_info<PoolTypeLiquidityMint, Token::Token<LiquidityToken<X, Y>>>(STAR::token_address())
    }

    /// Query all stake amount
    public fun query_total_stake<X: copy + drop + store, Y: copy + drop + store>(): u128 {
        YieldFarming::query_total_stake<
            PoolTypeLiquidityMint,
            Token::Token<LiquidityToken<X, Y>>
        >(STAR::token_address())
    }

    /// Query stake amount from user
    public fun query_stake<X: copy + drop + store, Y: copy + drop + store>(account: address): u128 acquires FarmStake {
        let farm = borrow_global<FarmStake<X, Y>>(account);
        YieldFarming::query_stake<
            PoolTypeLiquidityMint,
            Token::Token<LiquidityToken<X, Y>>
        >(account, farm.id)
    }

    /// Query release per second
    public fun query_release_per_second<X: copy + drop + store, Y: copy + drop + store>(): u128 acquires FarmCapability {
        let cap = borrow_global<FarmCapability<X, Y>>(STAR::token_address());
        cap.release_per_seconds
    }

    /// Inner stake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_stake<X: copy + drop + store,
                    Y: copy + drop + store>(account: &signer,
                                            amount: u128,
                                            farm_cap: &FarmCapability<X, Y>)
    : FarmStake<X, Y> acquires FarmStake {
        let account_addr = Signer::address_of(account);
        // If stake exist, unstake all withdraw staking, and set reward token to buffer pool
        let own_token = if (YieldFarming::exists_stake_at_address<PoolTypeLiquidityMint, Token::Token<LiquidityToken<X, Y>>>(account_addr)) {
            let FarmStake<X, Y>{
                id: _,
                cap : unwrap_harvest_cap
            } = move_from<FarmStake<X, Y>>(account_addr);

            // Unstake all liquidity token and reward token
            let (own_token, reward_token) = YieldFarming::unstake<
                PoolTypeLiquidityMint,
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
            PoolTypeLiquidityMint,
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
        FarmStake<X, Y>{
            cap: new_harvest_cap,
            id: stake_id,
        }
    }

    /// Inner unstake operation that unstake all from pool and combind new amount to total asset, then restake.
    fun inner_unstake<X: copy + drop + store,
                      Y: copy + drop + store>(account: &signer,
                                              amount: u128,
                                              farm_cap: &FarmCapability<X, Y>,
                                              harvest_cap: FarmStake<X, Y>)
    : FarmStake<X, Y> {
        let account_addr = Signer::address_of(account);
        let FarmStake{
            cap: unwrap_harvest_cap,
            id: _,
        } = harvest_cap;
        assert(amount > 0, Errors::invalid_state(ERR_FARM_PARAM_ERROR));

        // unstake all from pool
        let (own_asset_token, reward_token) = YieldFarming::unstake<
            PoolTypeLiquidityMint,
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
            PoolTypeLiquidityMint,
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
        FarmStake<X, Y>{
            cap: new_harvest_cap,
            id: stake_id,
        }
    }

    /// Upgrade strcuts
    public fun init_for_upgrade<X: copy + drop + store, Y: copy + drop + store>(signer: &signer) {
        STAR::assert_genesis_address(signer);

        let account_addr = Signer::address_of(signer);
        if (!exists<FarmMultiplier<X, Y>>(account_addr)) {
            move_to(signer, FarmMultiplier<X, Y>{
                multiplier: 1
            });
        }
    }
}
}