// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapSyrupScript {

    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::Errors;

    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::TokenSwapVestarRouter;
    use SwapAdmin::TokenSwapGov;

    const ERR_DEPRECATED: u64 = 1;

    ///  TODO: DEPRECATED on mainnet
    struct VestarMintCapabilityWrapper has key, store {
        cap: TokenSwapVestarMinter::MintCapability,
    }

    struct VestarRouterCapabilityWrapper has key, store {
        cap: TokenSwapVestarRouter::VestarRouterCapability,
    }

    public(script) fun add_pool<TokenT: store>(
        signer: signer,
        alloc_point: u128,
        delay: u64
    ) {
        TokenSwapSyrup::add_pool_v2<TokenT>(&signer, alloc_point, delay);
    }

    public(script) fun update_allocation_point<TokenT: store>(
        signer: signer,
        alloc_point: u128
    ) {
        TokenSwapSyrup::update_allocation_point<TokenT>(&signer, alloc_point);
    }

    /// Set release per second for token type pool
    public(script) fun set_pool_release_per_second(
        signer: signer,
        release_per_second: u128
    ) {
        TokenSwapSyrup::set_pool_release_per_second(&signer, release_per_second);

        TokenSwapSyrup::update_token_pool_index<STAR::STAR>(&signer);
        // TODO: to add other token type except STAR::STAR
        // Note that it is necessary to enumerate update index operation of all Token type pools here
        // It should be update harvest index after `pool_release_per_second` changed,
        // Otherwise, It will cause a calculation errors
    }

    /// DEPRECATED
    /// Set release per second for token type pool
    public(script) fun set_release_per_second<TokenT: copy + drop + store>(
        _signer: signer,
        _release_per_second: u128
    ) {
        //TokenSwapSyrup::set_release_per_second<TokenT>(&signer, release_per_second);
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// Set alivestate for token type pool
    public(script) fun set_alive<TokenT: copy + drop + store>(
        _signer: signer,
        _alive: bool
    ) {
        //TokenSwapSyrup::set_alive<TokenT>(&signer, alive);
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    public(script) fun stake<TokenT: store>(
        signer: signer,
        pledge_time_sec: u64,
        amount: u128
    ) acquires VestarRouterCapabilityWrapper {
        TokenSwapSyrup::stake<TokenT>(&signer, pledge_time_sec, amount);

        let broker = @SwapAdmin;
        let cap_wrapper = borrow_global<VestarRouterCapabilityWrapper>(broker);
        TokenSwapVestarRouter::stake_hook<TokenT>(&signer, pledge_time_sec, amount, &cap_wrapper.cap);
    }

    public(script) fun unstake<TokenT: store>(signer: signer, id: u64) acquires VestarRouterCapabilityWrapper {
        let user_addr = Signer::address_of(&signer);
        TokenSwapGov::linear_withdraw_syrup(&signer, 0);
        let (asset_token, reward_token) = TokenSwapSyrup::unstake<TokenT>(&signer, id);
        Account::deposit<TokenT>(user_addr, asset_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);

        let broker = @SwapAdmin;
        let cap_wrapper = borrow_global<VestarRouterCapabilityWrapper>(broker);
        TokenSwapVestarRouter::unstake_hook<TokenT>(&signer, id, &cap_wrapper.cap);
    }

    /// Boost stake that had staked before the boost function online
    public(script) fun take_vestar_by_stake_id<TokenT: store>(signer: signer, id: u64) acquires VestarRouterCapabilityWrapper {
        let user_addr = Signer::address_of(&signer);

        // if there not have stake id then report error
        let (
            start_time,
            end_time,
            _,
            token_amount
        ) = TokenSwapSyrup::get_stake_info<TokenT>(user_addr, id);

        let pledge_time_sec = end_time - start_time;
        let broker = @SwapAdmin;
        let cap_wrapper = borrow_global<VestarRouterCapabilityWrapper>(broker);

        // if the stake has staked hook vestar then report error
        TokenSwapVestarRouter::stake_hook_with_id<TokenT>(&signer, id, pledge_time_sec, token_amount, &cap_wrapper.cap);
    }

    /// TODO: DEPRECATED on mainnet
    public(script) fun put_stepwise_multiplier(
        _signer: signer,
        _interval_sec: u64,
        _multiplier: u64
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// Set the multiplier of each pledge time in the multiplier pool corresponding to TokenT
    /// It will abort while calling this function if the pool has exists,
    public(script) fun put_stepwise_multiplier_with_token_type<TokenT: store>(
        signer: signer,
        interval_sec: u64,
        multiplier: u64
    ) {
        TokenSwapSyrup::put_stepwise_multiplier<TokenT>(&signer, interval_sec, multiplier);
    }

    /// Set amount for every Pledge time in multiplier pool
    /// This function will be forbidden in next version
    public(script) fun set_multiplier_pool_amount<TokenT: store>(
        account: signer,
        pledge_time: u64,
        amount: u128
    ) {
        TokenSwapSyrup::set_multiplier_pool_amount<TokenT>(&account, pledge_time, amount);
    }

    public(script) fun adjust_total_amount_entry<TokenT: store>(
        account: signer,
        total_amount: u128,
        total_weight: u128,
    ) {
        TokenSwapSyrup::adjust_total_amount<TokenT>(&account, total_amount, total_weight);
    }

    /// Calculate the Total Weight and Total Amount from the multiplier pool and
    /// update them to YieldFarming
    ///
    public(script) fun update_total_from_multiplier_pool<TokenT: store>(
        account: signer,
    ) {
        TokenSwapSyrup::update_total_from_multiplier_pool<TokenT>(&account);
    }

    public fun get_stake_info<TokenT: store>(user_addr: address, id: u64): (u64, u64, u64, u128) {
        TokenSwapSyrup::get_stake_info<TokenT>(user_addr, id)
    }

    public fun query_total_stake<TokenT: store>(): u128 {
        TokenSwapSyrup::query_total_stake<TokenT>()
    }

    public fun query_stake_list<TokenT: store>(user_addr: address): vector<u64> {
        TokenSwapSyrup::query_stake_list<TokenT>(user_addr)
    }

    public fun query_vestar_amount(user_addr: address): u128 {
        TokenSwapVestarMinter::value(user_addr)
    }

    public fun query_vestar_amount_by_staked_id(user_addr: address, id: u64): u128 {
        TokenSwapVestarMinter::value_of_id(user_addr, id)
    }

    public fun query_vestar_amount_by_staked_id_tokentype<TokenT: store>(user_addr: address, id: u64): u128 {
        let old_value = TokenSwapVestarMinter::value_of_id(user_addr, id);
        if (old_value > 0) {
            old_value
        } else {
            TokenSwapVestarMinter::value_of_id_by_token<TokenT>(user_addr, id)
        }
    }

    public fun initialize_global_syrup_info(signer: &signer, pool_release_per_second: u128) {
        TokenSwapSyrup::initialize_global_pool_info(signer, pool_release_per_second);

        let cap =
            TokenSwapVestarRouter::initialize_global_syrup_info(
                signer,
                pool_release_per_second
            );

        move_to(signer, VestarRouterCapabilityWrapper {
            cap
        });
    }

    ///TODO: DEPRECATED, Turn over capability from script to syrup boost on barnard
    public(script) fun turnover_vestar_mintcap_for_barnard(_signer: signer) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    public(script) fun update_token_pool_index<X: copy + drop>(signer: signer) {
        TokenSwapSyrup::update_token_pool_index<X>(&signer);
    }
}
}
