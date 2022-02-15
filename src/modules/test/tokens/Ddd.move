address 0x2b3d5bd6d0f8a957e6a4abe986056ba7 {
/// Ddd is a test token of Starcoin blockchain.
/// It uses apis defined in the `Token` module.
module Ddd {
    // use 0x1::Token::{Self, Token};
    // use 0x1::Dao;

    use 0x1::Token;
    use 0x1::Account;

    /// Ddd token marker.
    struct Ddd has copy, drop, store { }

    /// precision of Ddd token.
    const PRECISION: u8 = 18;

    /// Ddd initialization.
    public(script) fun init(account: signer) {
         Token::register_token<Ddd>(&account, PRECISION);
         Account::do_accept_token<Ddd>(&account);
    }

    public(script) fun mint(account: signer, amount: u128) {
        let token = Token::mint<Ddd>(&account, amount);
        Account::deposit_to_self<Ddd>(&account, token)
    }

    /// Returns true if `TokenType` is `Ddd::Ddd`
    public fun is_ddd<TokenType: store>(): bool {
        Token::is_same_token<Ddd, TokenType>()
    }

   spec is_ddd {
   }

    /// Return Ddd token address.
    public fun token_address(): address {
        Token::token_address<Ddd>()
    }

   spec token_address {
   }
}
}