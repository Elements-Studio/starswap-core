// address 0x2 {
address 0x2b3d5bd6d0f8a957e6a4abe986056ba7 {
/// Bob is a test token of Starcoin blockchain.
/// It uses apis defined in the `Token` module.
module Bob {
    // use 0x1::Token::{Self, Token};
    // use 0x1::Dao;

    use 0x1::Token;
    use 0x1::Account;

    /// Bob token marker.
    struct Bob has copy, drop, store { }

    /// precision of Bob token.
    const PRECISION: u8 = 18;

    /// Bob initialization.
    public(script) fun init(account: signer) {
         Token::register_token<Bob>(&account, PRECISION);
         Account::do_accept_token<Bob>(&account);
    }

    public(script) fun mint(account: signer, amount: u128) {
        let token = Token::mint<Bob>(&account, amount);
        Account::deposit_to_self<Bob>(&account, token)
    }

    /// Returns true if `TokenType` is `Bob::Bob`
    public fun is_bob<TokenType: store>(): bool {
        Token::is_same_token<Bob, TokenType>()
    }

    spec is_bob {
    }

    /// Return Bob token address.
    public fun token_address(): address {
        Token::token_address<Bob>()
    }

    spec token_address {
    }
}
 }