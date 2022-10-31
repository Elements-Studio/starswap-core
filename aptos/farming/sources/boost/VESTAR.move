module SwapAdmin::VESTAR {
    use aptos_std::type_info;

    use std::signer;

    use SwapAdmin::WrapperUtil;

    /// VESTAR token marker.
    struct VESTAR has copy, drop, store {}

    /// precision of VESTAR token.
    const PRECISION: u8 = 9;

    const ERROR_NOT_GENESIS_ACCOUNT: u64 = 10001;

    /// Returns true if `CoinType` is `VESTAR::VESTAR`
    public fun is_vestar<CoinType>(): bool {
        WrapperUtil::is_same_token<VESTAR, CoinType>()
    }

    public fun assert_genesis_address(account: &signer) {
        assert!(signer::address_of(account) == token_address(), ERROR_NOT_GENESIS_ACCOUNT);
    }

    /// Return VESTAR token address.
    public fun token_address(): address {
        let type_info = type_info::type_of<VESTAR>();
        type_info::account_address(&type_info)
    }

    /// Return VESTAR precision.
    public fun precision(): u8 {
        PRECISION
    }
}