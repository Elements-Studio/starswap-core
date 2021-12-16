// address 0x2 {
address 0x4783d08fb16990bd35d83f3e23bf93b8 {
/// STAR is a governance token of Starcoin blockchain DAPP.
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

    // Mint function, block ability of mint and burn after execution
    public fun mint(account: &signer, amount: u128): (Token::MintCapability<STAR>, Token::BurnCapability<STAR>) {
        let token = Token::mint<STAR>(account, amount);
        Account::deposit_to_self<STAR>(account, token);

        let mint_cap = Token::remove_mint_capability(account);
        let burn_cap = Token::remove_burn_capability(account);
        (mint_cap, burn_cap)
    }

    /// Returns true if `TokenType` is `STAR::STAR`
    public fun is_star<TokenType: store>(): bool {
        Token::is_same_token<STAR, TokenType>()
    }

    spec is_abc {
    }

    public fun assert_genesis_address(account : &signer) {
        assert(Signer::address_of(account) == token_address(), ERROR_NOT_GENESIS_ACCOUNT);
    }

    /// Return STAR token address.
    public fun token_address(): address {
        Token::token_address<STAR>()
    }

    spec token_address {
    }

    /// Return STAR precision.
    public fun precision(): u8 {
        PRECISION
    }

    spec precision {
    }
}
}