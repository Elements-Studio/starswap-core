// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapFarmBoost {
    use std::signer;

    use aptos_std::type_info;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::event;

    use SwapAdmin::Boost;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwap::LiquidityToken;
    use SwapAdmin::TokenSwapGovPoolType::PoolTypeFarmPool;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::VESTAR::VESTAR;
    use SwapAdmin::VToken::{VToken, Self};
    use SwapAdmin::YieldFarmingV3 as YieldFarming;

    const DEFAULT_BOOST_FACTOR: u64 = 1;
    // user boost factor section is [1,2.5]
    const BOOST_FACTOR_PRECESION: u64 = 100; //two-digit precision

    const ERR_BOOST_VESTAR_BALANCE_NOT_ENOUGH: u64 = 121;


    struct UserInfo<phantom X, phantom Y> has key, store {
        boost_factor: u64,
        locked_vetoken: VToken<VESTAR>,
        user_amount: u128,
    }

    struct VeStarTreasuryCapabilityWrapper has key, store {
        cap: TokenSwapVestarMinter::TreasuryCapability
    }

    /// Event emitted when unboost been called
    struct UnBoostEvent has drop, store {
        /// token code of X type
        x_type_info: type_info::TypeInfo,
        /// token code of X type
        y_type_info: type_info::TypeInfo,
        /// signer of stake user
        signer: address,
        ///  boost unstake amount
        amount: u128,
    }

    /// Event emitted when boost been called
    struct BoostEvent has drop, store {
        /// token code of X type
        x_type_info: type_info::TypeInfo,
        /// token code of X type
        y_type_info: type_info::TypeInfo,
        /// signer of stake user
        signer: address,
        //  boost unstake amount
        amount: u128,
    }

    struct BoostEventStruct has key, store {
        boost_event_handler: event::EventHandle<BoostEvent>,
        unboost_event_handler: event::EventHandle<UnBoostEvent>,
    }

    /// Initialize Boost event
    public fun initialize_boost_event(account: &signer) {
        STAR::assert_genesis_address(account);
        move_to(account, BoostEventStruct {
            boost_event_handler: account::new_event_handle<BoostEvent>(account),
            unboost_event_handler: account::new_event_handle<UnBoostEvent>(account),
        });
    }

    public fun set_treasury_cap(signer: &signer, vestar_treasury_cap: TokenSwapVestarMinter::TreasuryCapability) {
        move_to(signer, VeStarTreasuryCapabilityWrapper {
            cap: vestar_treasury_cap
        });
    }

    public fun get_default_boost_factor_scale(): u64 {
        DEFAULT_BOOST_FACTOR * BOOST_FACTOR_PRECESION
    }


    /// Query user boost factor
    public fun get_boost_factor<X, Y>(account: address): u64 acquires UserInfo {
        if (exists<UserInfo<X, Y>>(account)) {
            let user_info = borrow_global<UserInfo<X, Y>>(account);
            user_info.boost_factor
        } else {
            get_default_boost_factor_scale()
        }
    }

    /// Query user boost locked vestar amount
    public fun get_boost_locked_vestar_amount<X, Y>(account: address): u128 acquires UserInfo {
        if (exists<UserInfo<X, Y>>(account)) {
            let user_info = borrow_global<UserInfo<X, Y>>(account);
            let vestar_value = VToken::value<VESTAR>(&user_info.locked_vetoken);
            vestar_value
        } else {
            0
        }
    }

    /// calculation asset weight for boost
    public fun calculate_boost_weight(amount: u128, boost_factor: u64): u128 {
        amount * (boost_factor as u128) / (BOOST_FACTOR_PRECESION as u128)
    }

    /// predict boost factor before stake
    public fun predict_boost_factor<X, Y>(account: address, user_lp_amount: u128): u64 acquires UserInfo {
        let user_vestar_locked_amount = get_boost_locked_vestar_amount<X, Y>(account);
        let total_farm_amount = YieldFarming::query_total_stake<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
            STAR::token_address()
        );
        let exact_total_farm_amount = total_farm_amount + user_lp_amount;
        let predict_boost_factor = Boost::compute_boost_factor(
            user_vestar_locked_amount,
            user_lp_amount,
            exact_total_farm_amount
        );
        predict_boost_factor
    }

    /// boost for farm
    public fun boost_to_farm_pool<X, Y>(
        cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>,
        account: &signer,
        boost_amount: u128,
        stake_id: u64)
    acquires UserInfo, VeStarTreasuryCapabilityWrapper, BoostEventStruct {
        let user_addr = signer::address_of(account);
        if (!exists<UserInfo<X, Y>>(user_addr)) {
            move_to(account, UserInfo<X, Y> {
                user_amount: 0,
                boost_factor: get_default_boost_factor_scale(),
                locked_vetoken: VToken::zero<VESTAR>(),
            });
        };
        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        let vestar_treasury_cap =
            borrow_global<VeStarTreasuryCapabilityWrapper>(@SwapAdmin);

        // lock boost amount vestar
        let vestar_total_amount = TokenSwapVestarMinter::value(user_addr);
        assert!((boost_amount > 0 && boost_amount <= vestar_total_amount), ERR_BOOST_VESTAR_BALANCE_NOT_ENOUGH);
        let boost_vestar_token = TokenSwapVestarMinter::withdraw_with_cap(
            account,
            boost_amount,
            &vestar_treasury_cap.cap
        );
        VToken::deposit<VESTAR>(&mut user_info.locked_vetoken, boost_vestar_token);

        update_boost_factor<X, Y>(cap, account, stake_id);

        // Emit boost event
        let boost_event = borrow_global_mut<BoostEventStruct>(STAR::token_address());
        event::emit_event(&mut boost_event.boost_event_handler,
            BoostEvent {
                y_type_info: type_info::type_of<X>(),
                x_type_info: type_info::type_of<Y>(),
                signer: user_addr,
                amount: boost_amount
            });
    }

    /// unboost for farm unstake
    public fun unboost_from_farm_pool<X, Y>(
        _cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>,
        account: &signer)
    acquires UserInfo, VeStarTreasuryCapabilityWrapper, BoostEventStruct {
        let user_addr = signer::address_of(account);
        if (!exists<UserInfo<X, Y>>(user_addr)) {
            move_to(account, UserInfo<X, Y> {
                user_amount: 0,
                boost_factor: get_default_boost_factor_scale(),
                locked_vetoken: VToken::zero<VESTAR>(),
            });
        };

        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        let vestar_treasury_cap =
            borrow_global<VeStarTreasuryCapabilityWrapper>(@SwapAdmin);

        // Unlock boost amount vestar
        let vestar_value = VToken::value<VESTAR>(&user_info.locked_vetoken);
        if (vestar_value > 0) {
            let vestar_token = VToken::withdraw<VESTAR>(&mut user_info.locked_vetoken, vestar_value);
            TokenSwapVestarMinter::deposit_with_cap(account, vestar_token, &vestar_treasury_cap.cap);
        };

        user_info.boost_factor = get_default_boost_factor_scale(); // reset to 1


        // Emit unboost event
        let boost_event = borrow_global_mut<BoostEventStruct>(STAR::token_address());
        event::emit_event(&mut boost_event.unboost_event_handler,
            UnBoostEvent {
                y_type_info: type_info::type_of<X>(),
                x_type_info: type_info::type_of<Y>(),
                signer: user_addr,
                amount: vestar_value
            });
    }

    /// update boost info when lp or vestar value change
    public fun update_boost_for_farm_pool<X, Y>(
        cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>,
        account: &signer,
        stake_id: u64
    ) acquires UserInfo {
        let user_addr = signer::address_of(account);
        if (!exists<UserInfo<X, Y>>(user_addr)) {
            move_to(account, UserInfo<X, Y> {
                user_amount: 0,
                boost_factor: get_default_boost_factor_scale(),
                locked_vetoken: VToken::zero<VESTAR>(),
            });
        };

        let boost_factor = get_boost_factor<X, Y>(user_addr);
        // is boost factor valid, then update boost factor
        if (boost_factor > get_default_boost_factor_scale()) {
            update_boost_factor<X, Y>(cap, account, stake_id);
        };
    }

    /// set user boost info
    public fun set_boost_factor<X, Y>(
        _cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>,
        account: &signer,
        new_boost_factor: u64
    ) acquires UserInfo {
        let user_addr = signer::address_of(account);
        if (!exists<UserInfo<X, Y>>(user_addr)) {
            move_to(account, UserInfo<X, Y> {
                user_amount: 0,
                boost_factor: get_default_boost_factor_scale(),
                locked_vetoken: VToken::zero<VESTAR>(),
            });
        };

        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        user_info.boost_factor = new_boost_factor;
    }

    /// boost factor change and triggers
    fun update_boost_factor<X, Y>(
        cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>,
        account: &signer,
        stake_id: u64
    ) acquires UserInfo {
        let user_addr = signer::address_of(account);

        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        let total_locked_vetoken_amount = VToken::value<VESTAR>(&user_info.locked_vetoken);

        let asset_amount = YieldFarming::query_stake<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
            user_addr,
            stake_id
        );

        let total_farm_amount = YieldFarming::query_total_stake<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
            STAR::token_address()
        );
        let new_boost_factor = Boost::compute_boost_factor(
            total_locked_vetoken_amount,
            asset_amount,
            total_farm_amount
        );

        let new_asset_weight = calculate_boost_weight(asset_amount, new_boost_factor);
        let last_asset_weight = calculate_boost_weight(asset_amount, user_info.boost_factor);
        update_pool_and_stake_weight<X, Y>(
            cap,
            account,
            stake_id,
            new_boost_factor,
            new_asset_weight,
            last_asset_weight
        );

        user_info.boost_factor = new_boost_factor;
    }

    fun update_pool_and_stake_weight<X, Y>(
        cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>,
        account: &signer,
        stake_id: u64,
        new_weight_factor: u64, //new stake weight factor
        new_asset_weight: u128, //new stake asset weight
        last_asset_weight: u128, //last stake asset weight)
    ) {
        let account_addr = signer::address_of(account);
        // check if need udpate
        YieldFarming::update_pool_weight<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
            cap,
            @SwapAdmin,
            new_asset_weight,
            last_asset_weight
        );
        YieldFarming::update_pool_stake_weight<PoolTypeFarmPool, coin::Coin<LiquidityToken<X, Y>>>(
            cap,
            @SwapAdmin,
            account_addr,
            stake_id,
            new_weight_factor,
            new_asset_weight,
            last_asset_weight
        );
    }
}