module swap_admin::CommonHelper {

    use std::signer;
    use std::string;

    use starcoin_framework::coin;
    use starcoin_framework::managed_coin;
    use starcoin_std::type_info::type_name;

    const PRECISION_9: u8 = 9;
    const PRECISION_18: u8 = 18;

    public fun safe_mint<T>(account: &signer, token_amount: u128) {
        if (!coin::is_account_registered<T>(signer::address_of(account))) {
            coin::register<T>(account);
        };
        managed_coin::mint<T>(account, signer::address_of(account), (token_amount as u64));
    }

    public fun transfer<T>(account: &signer, token_address: address, token_amount: u128) {
        coin::transfer<T>(account, token_address, (token_amount as u64))
    }

    public fun get_safe_balance<T>(token_address: address): u128 {
        (coin::balance<T>(token_address) as u128)
    }

    public fun register_and_mint<T>(account: &signer, precision: u8, token_amount: u128) {
        let type_name = type_name<T>();
        managed_coin::initialize<T>(
            account,
            *string::bytes(&type_name),
            *string::bytes(&type_name),
            precision,
            true
        );
        managed_coin::mint<T>(account, signer::address_of(account), (token_amount as u64));
    }

    public fun pow_amount<T>(amount: u128): u128 {
        amount * (coin::decimals<T>() as u128)
    }

    public fun pow_10(exp: u8): u128 {
        pow(10, exp)
    }

    public fun pow(base: u64, exp: u8): u128 {
        let result_val = 1u128;
        let i = 0;
        while (i < exp) {
            result_val = result_val * (base as u128);
            i = i + 1;
        };
        result_val
    }
}