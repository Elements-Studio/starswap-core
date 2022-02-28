// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address SwapAdmin {
module TokenSwapSyrupScript {

    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;

    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapConfig;

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
                                            amount: u128) {
        TokenSwapSyrup::stake<TokenT>(&signer, pledge_time_sec, amount);
    }

    public(script) fun unstake<TokenT: store>(signer: signer, id: u64) {
        let user_addr = Signer::address_of(&signer);
        let (asset_token, reward_token) = TokenSwapSyrup::unstake<TokenT>(&signer, id);
        Account::deposit<TokenT>(user_addr, asset_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);
    }

    public(script) fun put_stepwise_multiplier(signer: signer,
                                               interval_sec: u64,
                                               multiplier: u64) {
        TokenSwapConfig::put_stepwise_multiplier(&signer, interval_sec, multiplier);
    }

    public fun get_stake_info<TokenT: store>(user_addr: address, id: u64): (u64, u64, u64, u128) {
        TokenSwapSyrup::get_stake_info<TokenT>(user_addr, id)
    }

    public fun query_total_stake<TokenT: store>(): u128 {
        TokenSwapSyrup::query_total_stake<TokenT>()
    }

    public fun query_stake_list<TokenT: store>(user_addr: address) : vector<u64> {
        TokenSwapSyrup::query_stake_list<TokenT>(user_addr)
    }
}
}
