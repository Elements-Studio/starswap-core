module SwapAdmin::SwapTestHelper {

    const PRECISION_9: u8 = 9;
    const PRECISION_18: u8 = 18;
    const TOKEN_HOLDER_ADDRESS: address = @SwapAdmin;
    const ADMIN_ADDRESS: address = @SwapAdmin;
    const USDT_ADDRESS: address = @bridge;
    const FEE_ADDRESS: address = @SwapFeeAdmin;

    public fun get_admin_address(): address {
        ADMIN_ADDRESS
    }

    public fun get_token_holder_address(): address {
        TOKEN_HOLDER_ADDRESS
    }

    public fun get_xusdt_address(): address {
        USDT_ADDRESS
    }

    public fun get_fee_address(): address {
        FEE_ADDRESS
    }

    public fun init_token_pairs_register(_account: &signer) {
    }

    public fun init_token_pairs_liquidity(_account: &signer) {
    }

    public fun init_fee_token(_account: &signer) {
    }
}