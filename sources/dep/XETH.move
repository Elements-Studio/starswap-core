
address 0x2d81a0427d64ff61b11ede9085efa5ad {
module XETH {
    use 0x1::Token;
    use 0x1::Account;

    /// XETH token marker.
    struct XETH has copy, drop, store {}

    /// precision of XETH token.
    const PRECISION: u8 = 9;

    /// XETH initialization.
    public fun init(account: &signer) {
        Token::register_token<XETH>(account, PRECISION);
        Account::do_accept_token<XETH>(account);
    }

    public fun mint(account: &signer, amount: u128) {
        let token = Token::mint<XETH>(account, amount);
        Account::deposit_to_self<XETH>(account, token)
    }
}

module XETHScripts {
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XETH;

    public(script) fun init(account: signer) {
        XETH::init(&account);
    }

    public(script) fun mint(account: signer, amount: u128) {
        XETH::mint(&account, amount);
    }
}

}