module SwapAdmin::SwapUpgradeScripts {
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFee;

    const ERROR_INVALID_PARAMETER: u64 = 101;

    //two phase upgrade compatible
    public entry fun initialize_token_swap_fee(signer: &signer) {
        TokenSwapConfig::assert_admin(signer);
        TokenSwapFee::initialize_token_swap_fee(signer);
    }
}