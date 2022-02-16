
address 0xb6d69dd935edf7f2054acf12eb884df8 {
module XUSDT {
    use 0x1::Token;
    use 0x1::Account;

    /// XUSDT token marker.
    struct XUSDT has copy, drop, store {}

    /// precision of XUSDT token.
    const PRECISION: u8 = 9;

    /// XUSDT initialization.
    public fun init(account: &signer) {
        Token::register_token<XUSDT>(account, PRECISION);
        Account::do_accept_token<XUSDT>(account);
    }

    public fun mint(account: &signer, amount: u128) {
        let token = Token::mint<XUSDT>(account, amount);
        Account::deposit_to_self<XUSDT>(account, token)
    }
}

module XUSDTScripts {
    use 0xb6d69dd935edf7f2054acf12eb884df8::XUSDT;

    public(script) fun init(account: signer) {
        XUSDT::init(&account);
    }

    public(script) fun mint(account: signer, amount: u128) {
        XUSDT::mint(&account, amount);
    }
}

}