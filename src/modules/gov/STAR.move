address 0x8c109349c6bd91411d6bc962e080c4a3 {
/// STAR is a governance token of Starswap DAPP.
/// It uses apis defined in the `Token` module.
module STAR {
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Signer;

    /// STAR token marker.
    struct STAR has copy, drop, store {}

    /// precision of STAR token.
    const PRECISION: u8 = 9;

    const ERROR_NOT_GENESIS_ACCOUNT: u64 = 10001;

    /// STAR initialization.
    public fun init(account: &signer) {
        Token::register_token<STAR>(account, PRECISION);
        Account::do_accept_token<STAR>(account);
    }

    public fun mint(account: &signer, amount: u128) {
        let token = Token::mint<STAR>(account, amount);
        Account::deposit_to_self<STAR>(account, token);
    }

    /// Returns true if `TokenType` is `STAR::STAR`
    public fun is_star<TokenType: store>(): bool {
        Token::is_same_token<STAR, TokenType>()
    }

    public fun assert_genesis_address(account : &signer) {
        assert(Signer::address_of(account) == token_address(), ERROR_NOT_GENESIS_ACCOUNT);
    }

    /// Return STAR token address.
    public fun token_address(): address {
        Token::token_address<STAR>()
    }


    /// Return STAR precision.
    public fun precision(): u8 {
        PRECISION
    }
}
}