module SwapAdmin::WrapperUtil {
    use aptos_std::type_info;
    use aptos_framework::coin::{Self, Coin};

    use std::vector;

    public fun is_same_token<CoinType1: store, CoinType2: store>(): bool {
        return type_info::type_of<CoinType1>() == type_info::type_of<CoinType2>()
    }

    /// A helper function that returns the address of CoinType.
    public fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    /// wrapper the `value` passed in `coin` to u128
    public fun coin_value<CoinType>(coin: &Coin<CoinType>): u128 {
        (coin::value<CoinType>(coin) as u128)
    }

    /// wrapper the balance of `owner` for provided `CoinType` to u128
    public fun coin_balance<CoinType>(owner: address): u128 {
        (coin::balance<CoinType>(owner) as u128)
    }

    public fun slice(data: &vector<u8>, start: u64, end: u64): vector<u8> {
        let i = start;
        let result = vector::empty<u8>();
        let data_len = vector::length(data);
        let actual_end = if (end < data_len) {
            end
        } else {
            data_len
        };
        while (i < actual_end) {
            vector::push_back(&mut result, *vector::borrow(data, i));
            i = i + 1;
        };
        result
    }

}