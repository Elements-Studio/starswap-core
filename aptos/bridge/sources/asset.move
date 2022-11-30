module bridge::asset {
    struct USDC {}
    struct USDT {}
    struct BUSD {}
    struct USDD {}

    struct WETH {}
    struct WBTC {}



    #[test_only]
    use aptos_framework::coin::{Self};
    #[test_only]
    use aptos_framework::managed_coin;
    #[test_only]
    use std::signer;

    #[test_only]
    /// precision of USDT token.
    const PRECISION: u8 = 6;


    #[test_only]
    public fun init(account: &signer) {
        managed_coin::initialize<USDT>(
            account,
            b"USDT Coin",
            b"USDT",
            PRECISION,
            true,
        );
        coin::register<USDT>(account);
    }

    #[test_only]
    public fun mint(account: &signer, amount: u128) {
        let dst_addr = signer::address_of(account);
        managed_coin::mint<USDT>(account, dst_addr, (amount as u64))
    }

    #[test_only]
    public fun init_usdc(account: &signer) {
        managed_coin::initialize<USDC>(
            account,
            b"USDC Coin",
            b"USDC",
            PRECISION,
            true,
        );
        coin::register<USDC>(account);
    }

    #[test_only]
    public fun mint_usdc(account: &signer, amount: u128) {
        let dst_addr = signer::address_of(account);
        managed_coin::mint<USDC>(account, dst_addr, (amount as u64))
    }

}