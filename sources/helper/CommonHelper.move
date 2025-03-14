module swap_admin::CommonHelper {

    use std::signer;
    use starcoin_std::math128;

    use starcoin_framework::coin;
    use starcoin_framework::managed_coin;

    public fun safe_mint<T>(account: &signer, token_amount: u128) {
        if (!coin::is_account_registered<T>(signer::address_of(account))) {
            coin::register<T>(account);
        };
        managed_coin::mint<T>(account, signer::address_of(account), (token_amount as u64));
    }

    public fun safe_mint_to<T>(account: &signer, dst_addr: address, token_amount: u128) {
        if (!coin::is_account_registered<T>(signer::address_of(account))) {
            coin::register<T>(account);
        };
        managed_coin::mint<T>(account, dst_addr, (token_amount as u64));
    }

    public fun transfer<T>(account: &signer, token_address: address, token_amount: u128) {
        coin::transfer<T>(account, token_address, (token_amount as u64))
    }

    public fun get_safe_balance<T>(token_address: address): u128 {
        (coin::balance<T>(token_address) as u128)
    }


    public fun pow_amount<T>(amount: u128): u128 {
        amount * Self::pow_10(coin::decimals<T>())
    }

    public fun pow_10(exp: u8): u128 {
        math128::pow(10, (exp as u128))
    }


    #[test]
    public fun test_pow_10() {
        assert!(Self::pow_10(18) == 1_000_000_000_000_000_000, 101);
        assert!(Self::pow_10(21) == 1_000_000_000_000_000_000_000, 102);
        assert!(Self::pow_10(24) == 1_000_000_000_000_000_000_000_000, 103);
        assert!(Self::pow_10(27) == 1_000_000_000_000_000_000_000_000_000, 104);

        assert!(1000 * Self::pow_10(18) == Self::pow_10(21), 105);
        assert!(1000000 * Self::pow_10(18) == Self::pow_10(24), 106);
    }
}