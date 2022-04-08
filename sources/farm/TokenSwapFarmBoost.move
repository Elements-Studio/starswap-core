// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {

module TokenSwapFarmBoost {
    use StarcoinFramework::Token;
    use StarcoinFramework::Signer;

    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeFarmPool};
    use SwapAdmin::TokenSwap::LiquidityToken;
    use SwapAdmin::TokenSwapVestarIssuer;
    use SwapAdmin::TokenSwapBoost;
    use SwapAdmin::VToken::{VToken, Self};
    use SwapAdmin::VESTAR::{VESTAR};

    const DEFAULT_BOOST_FACTOR: u64 = 1;
    // user boost factor section is [1,2.5]
    const BOOST_FACTOR_PRECESION: u64 = 100; //two-digit precision


    struct UserInfo<phantom X, phantom Y> has key, store {
        boost_factor: u64,
        locked_vetoken: VToken<VESTAR>,
        user_amount: u128,
    }

    struct VeStarTreasuryCapabilityWrapper has key, store {
        cap: TokenSwapVestarIssuer::TreasuryCapability
    }

    public fun set_treasury_cap(signer: &signer, vestar_treasury_cap: TokenSwapVestarIssuer::TreasuryCapability) {
        move_to(signer, VeStarTreasuryCapabilityWrapper{
            cap: vestar_treasury_cap
        });
    }

    public fun get_default_boost_factor_scale(): u64 {
        DEFAULT_BOOST_FACTOR * BOOST_FACTOR_PRECESION
    }


    /// Query user boost factor
    public fun get_boost_factor<X: copy + drop + store, Y: copy + drop + store>(account: address): u64 acquires UserInfo {
        if(exists<UserInfo<X, Y>>(account)){
            let user_info = borrow_global<UserInfo<X, Y>>(account);
            user_info.boost_factor
        } else {
            get_default_boost_factor_scale()
        }
    }

    /// calculation asset weight for boost
    public fun calculate_boost_weight(amount: u128, boost_factor: u64): u128 {
        amount * (boost_factor as u128) / (BOOST_FACTOR_PRECESION as u128)
    }

    /// boost for farm
    public fun boost_to_farm_pool<X: copy + drop + store, Y: copy + drop + store>(
        cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
        account: &signer,
        boost_amount: u128,
        stake_id: u64 )
    acquires UserInfo, VeStarTreasuryCapabilityWrapper {
        let user_addr = Signer::address_of(account);
        if(!exists<UserInfo<X, Y>>(user_addr)){
            move_to(account, UserInfo<X, Y>{
                user_amount: 0,
                boost_factor: get_default_boost_factor_scale(),
                locked_vetoken: VToken::zero<VESTAR>(),
            });
        };
        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        let vestar_treasury_cap = borrow_global<VeStarTreasuryCapabilityWrapper>(@SwapAdmin);

        // lock boost amount vestar
        boost_amount = TokenSwapVestarIssuer::value(user_addr);
        let boost_vestar_token = TokenSwapVestarIssuer::withdraw_with_cap(account, boost_amount, &vestar_treasury_cap.cap);
        VToken::deposit<VESTAR>(&mut user_info.locked_vetoken, boost_vestar_token);

        update_boost_factor<X, Y>(cap, account, stake_id);
    }

    /// unboost for farm unstake
    public fun unboost_from_farm_pool<X: copy + drop + store, Y: copy + drop + store>(
        _cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
        account: &signer)
    acquires UserInfo, VeStarTreasuryCapabilityWrapper {
        let user_addr = Signer::address_of(account);
        if(!exists<UserInfo<X, Y>>(user_addr)){
            move_to(account, UserInfo<X, Y>{
                user_amount: 0,
                boost_factor: get_default_boost_factor_scale(),
                locked_vetoken: VToken::zero<VESTAR>(),
            });
        };
        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        let vestar_treasury_cap = borrow_global<VeStarTreasuryCapabilityWrapper>(@SwapAdmin);
        //unlock boost amount vestar
        let vestar_value = TokenSwapVestarIssuer::value(user_addr);
        let vestar_token = VToken::withdraw<VESTAR>(&mut user_info.locked_vetoken, vestar_value);
        TokenSwapVestarIssuer::deposit_with_cap(account, vestar_token, &vestar_treasury_cap.cap);

        user_info.boost_factor = get_default_boost_factor_scale(); // reset to 1
    }

    /// boost factor change and triggers
    fun update_boost_factor<X: copy + drop + store, Y: copy + drop + store>(
        cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
        account: &signer,
        stake_id: u64,
    ) acquires UserInfo {
        let user_addr = Signer::address_of(account);

        let user_info = borrow_global_mut<UserInfo<X, Y>>(user_addr);
        let total_locked_vetoken_amount = VToken::value<VESTAR>(&user_info.locked_vetoken);
        let new_boost_factor = TokenSwapBoost::compute_boost_factor(total_locked_vetoken_amount);

        let asset_amount = YieldFarming::query_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(user_addr, stake_id);

        let new_asset_weight = calculate_boost_weight(asset_amount, new_boost_factor);
        let last_asset_weight = calculate_boost_weight(asset_amount, user_info.boost_factor);
        update_pool_and_stake_weight<X, Y>(cap, account, stake_id, new_boost_factor, new_asset_weight, last_asset_weight);

        user_info.boost_factor = new_boost_factor;

    }

    fun update_pool_and_stake_weight<X: copy + drop + store, Y: copy + drop + store>(
        cap: &YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
        account: &signer,
        stake_id: u64,
        new_weight_factor: u64, //new stake weight factor
        new_asset_weight: u128, //new stake asset weight
        last_asset_weight: u128, //last stake asset weight)
    )  {
        let account_addr = Signer::address_of(account);
        // check if need udpate
        YieldFarming::update_pool_weight<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(cap,
            @SwapAdmin, new_asset_weight, last_asset_weight);
        YieldFarming::update_pool_stake_weight<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(cap,
            @SwapAdmin, account_addr, stake_id, new_weight_factor, new_asset_weight, last_asset_weight);

    }

}
}