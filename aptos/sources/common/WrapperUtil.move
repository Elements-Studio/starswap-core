module SwapAdmin::WrapperUtil {

    use aptos_std::type_info;

    public fun is_same_token<CoinType1: store, CoinType2: store>(): bool {
        return type_info::type_of<CoinType1>() == type_info::type_of<CoinType2>()
    }

    /// A helper function that returns the address of CoinType.
    public fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

}