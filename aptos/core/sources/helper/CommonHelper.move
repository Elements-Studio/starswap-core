module SwapAdmin::CommonHelper {
    use aptos_framework::coin::{Self};
    use aptos_std::math64;

    use std::signer;

    use SwapAdmin::TokenMock;

    const PRECISION_9: u8 = 9;
    const PRECISION_18: u8 = 18;

    public entry fun accept_token_entry<CoinType>(account: &signer) {
        safe_accept_token<CoinType>(account);
    }

    public fun safe_accept_token<CoinType>(account: &signer) {
        if (!coin::is_account_registered<CoinType>(signer::address_of(account))) {
            coin::register<CoinType>(account);
        };
    }

    public fun safe_mint<CoinType>(account: &signer, token_amount: u128) {
        let is_account_registered = coin::is_account_registered<CoinType>(signer::address_of(account));
        if (!is_account_registered) {
            coin::register<CoinType>(account);
        };
        let token = TokenMock::mint_token<CoinType>(token_amount);
        coin::deposit<CoinType>(signer::address_of(account), token);
    }

    public fun transfer<CoinType>(account: &signer, token_address: address, token_amount: u128){
        let token = coin::withdraw<CoinType>(account, (token_amount as u64));
         coin::deposit(token_address, token);
    }

    public fun get_safe_balance<CoinType>(token_address: address): u128{
        let token_balance: u128 = 0;
        if (coin::is_account_registered<CoinType>(token_address)) {
            token_balance = (coin::balance<CoinType>(token_address) as u128);
        };
        token_balance
    }

    public fun register_and_mint<CoinType>(account: &signer, precision: u8, token_amount: u128) {
        TokenMock::register_token<CoinType>(account, precision);
        safe_mint<CoinType>(account, token_amount);
    }

    public fun pow_amount<Token>(amount: u128): u128 {
        let coin_precision = coin::decimals<Token>();
        let scaling_factor = math64::pow(10, (coin_precision as u64));

        amount * (scaling_factor as u128)
    }

    public fun pow_10(exp: u8): u128 {
        pow(10, exp)
    }

    public fun pow(base: u64, exp: u8): u128 {
        let result_val = 1u128;
        let i = 0;
        while (i < exp) {
            result_val = result_val * (base as u128);
            i = i + 1;
        };
        result_val
    }

}