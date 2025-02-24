module swap_admin::VESTAR {

    use std::signer;

    use starcoin_std::type_info;

    /// VESTAR token marker.
    struct VESTAR has copy, drop, store {}

    /// precision of VESTAR token.
    const PRECISION: u8 = 9;

    const ERROR_NOT_GENESIS_ACCOUNT: u64 = 10001;

    /// Returns true if `TokenType` is `VESTAR::VESTAR`
    public fun is_vestar<TokenType: store>(): bool {
        type_info::type_name<TokenType>() == type_info::type_name<VESTAR>()
    }

    public fun assert_genesis_address(account: &signer) {
        assert!(signer::address_of(account) == token_address(), ERROR_NOT_GENESIS_ACCOUNT);
    }

    /// Return VESTAR token address.
    public fun token_address(): address {
        type_info::account_address(&type_info::type_of<VESTAR>())
    }

    /// Return VESTAR precision.
    public fun precision(): u8 {
        PRECISION
    }
}