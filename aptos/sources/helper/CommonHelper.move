module SwapAdmin::CommonHelper {
    use aptos_framework::coin::{Self};
    use aptos_std::math64;

    use std::signer;

    use SwapAdmin::TokenMock;

    const PRECISION_9: u8 = 9;
    const PRECISION_18: u8 = 18;

    public fun safe_accept_token<TokenType: store>(account: &signer) {
        if (!coin::is_account_registered<TokenType>(signer::address_of(account))) {
            coin::register<TokenType>(account);
        };
    }

    public fun safe_mint<TokenType: store>(account: &signer, token_amount: u128) {
        let is_account_registered = coin::is_account_registered<TokenType>(signer::address_of(account));
        if (!is_account_registered) {
            coin::register<TokenType>(account);
        };
        let token = TokenMock::mint_token<TokenType>(token_amount);
        coin::deposit<TokenType>(signer::address_of(account), token);
    }

    public fun transfer<TokenType: store>(account: &signer, token_address: address, token_amount: u128){
        let token = coin::withdraw<TokenType>(account, (token_amount as u64));
         coin::deposit(token_address, token);
    }

    public fun get_safe_balance<TokenType: store>(token_address: address): u128{
        let token_balance: u128 = 0;
        if (coin::is_account_registered<TokenType>(token_address)) {
            token_balance = (coin::balance<TokenType>(token_address) as u128);
        };
        token_balance
    }

    public fun register_and_mint<TokenType: store>(account: &signer, precision: u8, token_amount: u128) {
        TokenMock::register_token<TokenType>(account, precision);
        safe_mint<TokenType>(account, token_amount);
    }

    public fun pow_amount<Token: store>(amount: u128): u128 {
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