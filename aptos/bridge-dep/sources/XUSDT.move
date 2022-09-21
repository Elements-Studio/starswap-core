
module Bridge::XUSDT {
    use aptos_framework::managed_coin;
    use std::signer;

    /// XUSDT token marker.
    struct XUSDT has copy, drop, store {}

    /// precision of XUSDT token.
    const PRECISION: u8 = 6;

    /// XUSDT initialization.
    public entry fun init(account: &signer) {
//        Token::register_token<XUSDT>(account, PRECISION);
//        Account::do_accept_token<XUSDT>(account);

        managed_coin::initialize<XUSDT>(
            account,
            b"XUSDT Coin",
            b"XUSDT",
            PRECISION,
            false,
        );
    }

    public entry fun mint(account: &signer, amount: u128) {
        let dst_addr = signer::address_of(account);
        managed_coin::mint<XUSDT>(account, dst_addr, (amount as u64))
    }

}
