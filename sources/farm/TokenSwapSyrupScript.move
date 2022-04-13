// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapSyrupScript {

    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;

    use SwapAdmin::STAR;
    use SwapAdmin::VESTAR;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::TokenSwapFarmBoost;

    const ERROR_UPGRADE_NOT_READY_NOW: u64 = 101;

    struct VestarMintCapabilityWrapper has key, store {
        cap: TokenSwapVestarMinter::MintCapability,
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
                                            amount: u128) acquires VestarMintCapabilityWrapper {
        TokenSwapSyrup::stake<TokenT>(&signer, pledge_time_sec, amount);

        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            let cap = borrow_global<VestarMintCapabilityWrapper>(VESTAR::token_address());
            TokenSwapVestarMinter::mint_with_cap(&signer,
                TokenSwapSyrup::get_global_stake_id<TokenT>(Signer::address_of(&signer)),
                pledge_time_sec,
                amount,
                &cap.cap);
        };
    }

    public(script) fun unstake<TokenT: store>(signer: signer, id: u64) acquires VestarMintCapabilityWrapper {
        let user_addr = Signer::address_of(&signer);
        let (start_time, end_time, _, amount) = TokenSwapSyrup::get_stake_info<TokenT>(user_addr, id);
        let (asset_token, reward_token) = TokenSwapSyrup::unstake<TokenT>(&signer, id);
        Account::deposit<TokenT>(user_addr, asset_token);
        Account::deposit<STAR::STAR>(user_addr, reward_token);

        if (TokenSwapConfig::get_alloc_mode_upgrade_switch()) {
            let pledge_time_sec = end_time - start_time;
            let cap = borrow_global<VestarMintCapabilityWrapper>(VESTAR::token_address());
            TokenSwapVestarMinter::burn_with_cap(&signer, id, pledge_time_sec, amount, &cap.cap);
        };
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

    public fun query_stake_list<TokenT: store>(user_addr: address): vector<u64> {
        TokenSwapSyrup::query_stake_list<TokenT>(user_addr)
    }

    public fun upgrade_for_init(signer: &signer, pool_release_per_second: u128) {
        TokenSwapSyrup::upgrade_syrup_global(signer, pool_release_per_second);

        let (
            issuer_cap,
            treasury_cap
        ) = TokenSwapVestarMinter::init(signer);

        TokenSwapFarmBoost::set_treasury_cap(signer, treasury_cap);
        move_to(signer, VestarMintCapabilityWrapper{
            cap: issuer_cap,
        });
    }
}
}
