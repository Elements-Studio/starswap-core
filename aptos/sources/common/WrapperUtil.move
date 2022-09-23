module SwapAdmin::WrapperUtil {
    use aptos_std::type_info;
    use aptos_framework::coin::{Self, Coin};

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

}