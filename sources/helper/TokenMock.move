// token holder address, not admin address
address SwapAdmin {
module TokenMock {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;

    struct TokenSharedCapability<phantom TokenType> has key, store {
        mint: Token::MintCapability<TokenType>,
        burn: Token::BurnCapability<TokenType>,
    }

    // mock ETH token
    struct WETH has copy, drop, store {}

    // mock USDT token
    struct WUSDT has copy, drop, store {}

    // mock DAI token
    struct WDAI has copy, drop, store {}

    // mock BTC token
    struct WBTC has copy, drop, store {}

    // mock DOT token
    struct WDOT has copy, drop, store {}


    public fun register_token<TokenType: store>(account: &signer, precision: u8){
        Token::register_token<TokenType>(account, precision);
        Account::do_accept_token<TokenType>(account);

        let mint_capability = Token::remove_mint_capability<TokenType>(account);
        let burn_capability = Token::remove_burn_capability<TokenType>(account);
        move_to(account, TokenSharedCapability { mint: mint_capability, burn: burn_capability });
    }

    public fun mint_token<TokenType: store>(amount: u128): Token::Token<TokenType> acquires TokenSharedCapability{
        //token holder address
        let cap = borrow_global<TokenSharedCapability<TokenType>>(Token::token_address<TokenType>());
        Token::mint_with_capability<TokenType>(&cap.mint, amount)
    }

    public fun burn_token<TokenType: store>(tokens: Token::Token<TokenType>) acquires TokenSharedCapability{
        //token holder address
        let cap = borrow_global<TokenSharedCapability<TokenType>>(Token::token_address<TokenType>());
        Token::burn_with_capability<TokenType>(&cap.burn, tokens);
    }
}

}

