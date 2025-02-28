/// STAR is a governance token of Starswap DAPP.
/// It uses apis defined in the `Token` module.
module swap_admin::STAR {
    use std::signer;
    use std::string;

    use starcoin_framework::coin;
    use starcoin_framework::managed_coin;

    use starcoin_std::type_info;

    /// STAR token marker.
    struct STAR has copy, drop, store {}

    /// precision of STAR token.
    const PRECISION: u8 = 9;

    const ERROR_NOT_GENESIS_ACCOUNT: u64 = 10001;

    /// STAR initialization.
    public fun init(swap_admin_signer: &signer) {
        managed_coin::initialize<STAR>(
            swap_admin_signer,
            *string::bytes(&string::utf8(b"STAR")),
            *string::bytes(&string::utf8(b"STAR")),
            PRECISION,
            true,
        );
    }

    public fun mint(account: &signer, amount: u128) {
        managed_coin::mint<STAR>(account, signer::address_of(account), (amount as u64));
    }

    /// Burn STAR with account signer
    public fun burn(account: &signer, amount: u128) {
        managed_coin::burn<STAR>(account, (amount as u64));
    }

    /// Burn STAR by passed in coin structure
    public fun burn_coin(account: &signer, coin: coin::Coin<STAR>) {
        let coin_amount = coin::value(&coin);
        coin::deposit(signer::address_of(account), coin);
        managed_coin::burn<STAR>(account, coin_amount);
    }

    /// Returns true if `TokenType` is `STAR::STAR`
    public fun is_star<Coin: store>(): bool {
        type_info::type_name<Coin>() == string::utf8(b"0x8c109349c6bd91411d6bc962e080c4a3::STAR::STAR")
    }

    public fun assert_genesis_address(account: &signer) {
        assert!(signer::address_of(account) == token_address(), ERROR_NOT_GENESIS_ACCOUNT);
    }

    /// Return STAR token address.
    public fun token_address(): address {
        // Token::token_address<STAR>()
        @swap_admin
    }

    /// Return STAR precision.
    public fun precision(): u8 {
        PRECISION
    }
}
