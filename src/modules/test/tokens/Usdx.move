address 0x2b3d5bd6d0f8a957e6a4abe986056ba7 {
/// USDx is a test token of Starcoin blockchain.
/// It uses apis defined in the `Token` module.
module Usdx {
    // use 0x1::Token::{Self, Token};
    // use 0x1::Dao;

    use 0x1::Token;
    use 0x1::Account;

    /// USDx token marker.
    struct Usdx has copy, drop, store {}

    /// precision of USDx token.
    const PRECISION: u8 = 9;

    /// USDx initialization.
    public (script) fun init(account: signer) {
        Token::register_token<Usdx>(&account, PRECISION);
        Account::do_accept_token<Usdx>(&account);
    }

    public (script) fun mint(account: signer, amount: u128) {
        let token = Token::mint<Usdx>(&account, amount);
        Account::deposit_to_self<Usdx>(&account, token)
    }

    /// Returns true if `TokenType` is `USDx::USDx`
    public fun is_usdx<TokenType: store>(): bool {
        Token::is_same_token<Usdx, TokenType>()
    }

    spec is_usdx {}

    /// Return USDx token address.
    public fun token_address(): address {
        Token::token_address<Usdx>()
    }

    spec token_address {}
}
}