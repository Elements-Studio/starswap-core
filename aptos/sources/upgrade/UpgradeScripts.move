module SwapAdmin::UpgradeScripts {
    use SwapAdmin::TokenSwapFee;
    use SwapAdmin::TokenSwapConfig;

    const DEFAULT_MIN_TIME_LIMIT: u64 = 86400000;// one day

    const ERROR_INVALID_PARAMETER: u64 = 101;

    //two phase upgrade compatible
    public entry fun initialize_token_swap_fee(signer: signer) {
        TokenSwapConfig::assert_admin(&signer);
        TokenSwapFee::initialize_token_swap_fee(&signer);
    }

}