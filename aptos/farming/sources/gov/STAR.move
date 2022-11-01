/// STAR is a governance token of Starswap DAPP.
/// It uses apis defined in the `Token` module.
module SwapAdmin::STAR {
    use std::signer;

    use aptos_framework::managed_coin;

    use SwapAdmin::WrapperUtil;

    /// STAR token marker.
    struct STAR has copy, drop, store {}

    /// precision of STAR token.
    const PRECISION: u8 = 9;

    const ERROR_NOT_GENESIS_ACCOUNT: u64 = 10001;

    /// STAR initialization.
    public fun init(account: &signer) {
        managed_coin::initialize<STAR>(
            account,
            b"STAR Coin",
            b"STAR",
            PRECISION,
            true,
        );
    }

    public entry fun mint(account: &signer, amount: u128) {
        let dst_addr = signer::address_of(account);
        managed_coin::mint<STAR>(account, dst_addr, (amount as u64))
    }

    /// Returns true if `CoinType` is `STAR::STAR`
    public fun is_star<CoinType>(): bool {
        WrapperUtil::is_same_token<STAR, CoinType>()
    }

    public fun assert_genesis_address(account: &signer) {
        assert!(signer::address_of(account) == token_address(), ERROR_NOT_GENESIS_ACCOUNT);
    }

    /// Return STAR token address.
    public fun token_address(): address {
        WrapperUtil::coin_address<STAR>()
    }


    /// Return STAR precision.
    public fun precision(): u8 {
        PRECISION
    }
}