// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapSyrupScript {

    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;

    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::TokenSwapVestarRouter;
    use SwapAdmin::TokenSwapGov;
    use StarcoinFramework::Errors;

    const ERR_DEPRECATED: u64 = 1;

    ///  TODO: DEPRECATED on mainnet
    struct VestarMintCapabilityWrapper has key, store {
        cap: TokenSwapVestarMinter::MintCapability,
    }

    struct VestarRouterCapabilityWrapper has key, store {
        cap: TokenSwapVestarRouter::VestarRouterCapability,
    }

    public(script) fun add_pool<TokenT: store>(signer: signer,
                                               release_per_second: u128,
                                               delay: u64) {
        TokenSwapSyrup::add_pool<TokenT>(&signer, release_per_second, delay);
    }

    /// Set release per second for token type pool
    public(script) fun set_release_per_second<
        TokenT: copy + drop + store>(signer: signer,
                                     release_per_second: u128) {
        TokenSwapSyrup::set_release_per_second<TokenT>(&signer, release_per_second);
    }

    /// Set alivestate for token type pool
    public(script) fun set_alive<
        TokenT: copy + drop + store>(signer: signer, alive: bool) {
        TokenSwapSyrup::set_alive<TokenT>(&signer, alive);
    }

    public(script) fun stake<TokenT: store>(signer: signer,
                                            pledge_time_sec: u64,
                                            amount: u128) acquires VestarRouterCapabilityWrapper {
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

    public(script) fun put_stepwise_multiplier<TokenT: store>(
        signer: signer,
        interval_sec: u64,
        multiplier: u64
    ) {
        TokenSwapSyrup::put_stepwise_multiplier<TokenT>(&signer, interval_sec, multiplier);
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

    ///TODO: Turn over capability from script to syrup boost on barnard
    public(script) fun turnover_vestar_mintcap_for_barnard(_signer: signer) {
        abort Errors::invalid_state(ERR_DEPRECATED)
        // STAR::assert_genesis_address(&signer);
        //
        // let broker = Signer::address_of(&signer);
        //
        // TokenSwapVestarMinter::maybe_init_event_handler_barnard(&signer);
        //
        // if (exists<VestarRouterCapabilityWrapper>(broker) ||
        //     !exists<VestarMintCapabilityWrapper>(broker)) {
        //     return
        // };
        //
        // let VestarMintCapabilityWrapper {
        //     cap: mint_cap
        // } = move_from<VestarMintCapabilityWrapper>(Signer::address_of(&signer));
        //
        // move_to(&signer, VestarRouterCapabilityWrapper {
        //     cap: TokenSwapVestarRouter::turnover_vestar_mintcap_for_barnard(mint_cap),
        // });
    }

    public(script) fun set_multiplier_pool_amount<TokenT: store>(
        account: signer,
        pledge_time: u64,
        amount: u128
    ) {
        TokenSwapSyrup::set_multiplier_pool_amount<TokenT>(&account, pledge_time, amount);
    }
}
}
