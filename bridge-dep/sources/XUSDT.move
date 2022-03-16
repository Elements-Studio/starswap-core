
address Bridge {
module XUSDT {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;

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
    use Bridge::XUSDT;

    public(script) fun init(account: signer) {
        XUSDT::init(&account);
    }

    public(script) fun mint(account: signer, amount: u128) {
        XUSDT::mint(&account, amount);
    }
}

}