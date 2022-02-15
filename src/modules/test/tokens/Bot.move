address 0x2b3d5bd6d0f8a957e6a4abe986056ba7 {
/// Bot is a test token of Starcoin blockchain.
/// It uses apis defined in the `Token` module.
module Bot {
    // use 0x1::Token::{Self, Token};
    // use 0x1::Dao;

    use 0x1::Token;
    use 0x1::Account;

    /// Bot token marker.
    struct Bot has copy, drop, store { }

    /// precision of Bot token.
    const PRECISION: u8 = 18;

    /// Bot initialization.
    public(script) fun init(account: signer) {
         Token::register_token<Bot>(&account, PRECISION);
         Account::do_accept_token<Bot>(&account);
    }

    public(script) fun mint(account: signer, amount: u128) {
        let token = Token::mint<Bot>(&account, amount);
        Account::deposit_to_self<Bot>(&account, token)
    }

    /// Returns true if `TokenType` is `Bot::Bot`
    public fun is_bot<TokenType: store>(): bool {
        Token::is_same_token<Bot, TokenType>()
    }

    spec is_bot {
    }

    /// Return Bot token address.
    public fun token_address(): address {
        Token::token_address<Bot>()
    }

    spec token_address {
    }
}
}