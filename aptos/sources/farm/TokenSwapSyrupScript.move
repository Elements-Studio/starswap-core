// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapSyrupScript {
    use aptos_framework::coin;
    use std::signer;

    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::TokenSwapVestarRouter;
    // use SwapAdmin::TokenSwapGov;

    ///  TODO: Deprecated on mainnet
    struct VestarMintCapabilityWrapper has key, store {
        cap: TokenSwapVestarMinter::MintCapability,
    }

    struct VestarRouterCapabilityWrapper has key, store {
        cap: TokenSwapVestarRouter::VestarRouterCapability,
    }

    public entry fun add_pool<CoinT: store>(signer: signer,
                                               release_per_second: u128,
                                               delay: u64) {
        TokenSwapSyrup::add_pool<CoinT>(&signer, release_per_second, delay);
    }

    /// Set release per second for token type pool
    public entry fun set_release_per_second<
        CoinT: copy + drop + store>(signer: signer,
                                     release_per_second: u128) {
        TokenSwapSyrup::set_release_per_second<CoinT>(&signer, release_per_second);
    }

    /// Set alivestate for token type pool
    public entry fun set_alive<
        CoinT: copy + drop + store>(signer: signer, alive: bool) {
        TokenSwapSyrup::set_alive<CoinT>(&signer, alive);
    }

    public entry fun stake<CoinT: store>(signer: signer,
                                            pledge_time_sec: u64,
                                            amount: u128) acquires VestarRouterCapabilityWrapper {
        TokenSwapSyrup::stake<CoinT>(&signer, pledge_time_sec, amount);

        let broker = @SwapAdmin;
        let cap_wrapper = borrow_global<VestarRouterCapabilityWrapper>(broker);
        TokenSwapVestarRouter::stake_hook<CoinT>(&signer, pledge_time_sec, amount, &cap_wrapper.cap);
    }

    public entry fun unstake<CoinT: store>(signer: signer, id: u64) acquires VestarRouterCapabilityWrapper {
        let user_addr = signer::address_of(&signer);
        // TODO: uncomment this once TokenSwapGov::linear_withdraw_syrup is available.
        // TokenSwapGov::linear_withdraw_syrup(&signer, 0);
        let (asset_token, reward_token) = TokenSwapSyrup::unstake<CoinT>(&signer, id);
        coin::deposit<CoinT>(user_addr, asset_token);
        coin::deposit<STAR::STAR>(user_addr, reward_token);

        let broker = @SwapAdmin;
        let cap_wrapper = borrow_global<VestarRouterCapabilityWrapper>(broker);
        TokenSwapVestarRouter::unstake_hook<CoinT>(&signer, id, &cap_wrapper.cap);
    }

    /// Boost stake that had staked before the boost function online
    public entry fun take_vestar_by_stake_id<CoinT: store>(signer: signer, id: u64) acquires VestarRouterCapabilityWrapper {
        let user_addr = signer::address_of(&signer);

        // if there not have stake id then report error
        let (
            start_time,
            end_time,
            _,
            token_amount
        ) = TokenSwapSyrup::get_stake_info<CoinT>(user_addr, id);

        let pledge_time_sec = end_time - start_time;
        let broker = @SwapAdmin;
        let cap_wrapper = borrow_global<VestarRouterCapabilityWrapper>(broker);

        // if the stake has staked hook vestar then report error
        TokenSwapVestarRouter::stake_hook_with_id<CoinT>(&signer, id, pledge_time_sec, token_amount, &cap_wrapper.cap);
    }

    public entry fun put_stepwise_multiplier(signer: signer,
                                               interval_sec: u64,
                                               multiplier: u64) {
        TokenSwapConfig::put_stepwise_multiplier(&signer, interval_sec, multiplier);
    }

    public fun get_stake_info<CoinT: store>(user_addr: address, id: u64): (u64, u64, u64, u128) {
        TokenSwapSyrup::get_stake_info<CoinT>(user_addr, id)
    }

    public fun query_total_stake<CoinT: store>(): u128 {
        TokenSwapSyrup::query_total_stake<CoinT>()
    }

    public fun query_stake_list<CoinT: store>(user_addr: address): vector<u64> {
        TokenSwapSyrup::query_stake_list<CoinT>(user_addr)
    }

    public fun query_vestar_amount(user_addr: address): u128 {
        TokenSwapVestarMinter::value(user_addr)
    }

    public fun query_vestar_amount_by_staked_id(user_addr: address, id: u64): u128 {
        TokenSwapVestarMinter::value_of_id(user_addr, id)
    }

    public fun query_vestar_amount_by_staked_id_tokentype<CoinT: store>(user_addr: address, id: u64): u128 {
        let old_value = TokenSwapVestarMinter::value_of_id(user_addr, id);
        if (old_value > 0) {
            old_value
        } else {
            TokenSwapVestarMinter::value_of_id_by_token<CoinT>(user_addr, id)
        }
    }

    public fun initialize_global_syrup_info(signer: &signer, pool_release_per_second: u128) {
        let cap = TokenSwapVestarRouter::initialize_global_syrup_info(signer, pool_release_per_second);
        move_to(signer, VestarRouterCapabilityWrapper {
            cap
        });
    }

    ///TODO: Turn over capability from script to syrup boost on barnard
    public entry fun turnover_vestar_mintcap_for_barnard(signer: signer) acquires VestarMintCapabilityWrapper {
        STAR::assert_genesis_address(&signer);

        let broker = signer::address_of(&signer);

        TokenSwapVestarMinter::maybe_init_event_handler_barnard(&signer);

        if (exists<VestarRouterCapabilityWrapper>(broker) ||
            !exists<VestarMintCapabilityWrapper>(broker)) {
            return
        };

        let VestarMintCapabilityWrapper {
            cap: mint_cap
        } = move_from<VestarMintCapabilityWrapper>(signer::address_of(&signer));

        move_to(&signer, VestarRouterCapabilityWrapper {
            cap: TokenSwapVestarRouter::turnover_vestar_mintcap_for_barnard(mint_cap),
        });
    }
}
}
