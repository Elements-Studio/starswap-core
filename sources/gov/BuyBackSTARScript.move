module SwapAdmin::BuyBackSTARScript {

    use StarcoinFramework::Errors;

    const ERR_DEPRECRATED: u64 = 1;

    struct BuyBackSTAR has store {}

    public fun init_entry(
        _sender: signer,
        _total_amount: u128,
        _begin_time: u64,
        _interval: u64,
        _release_per_time: u128
    ) {
        abort Errors::deprecated(ERR_DEPRECRATED)
    }

    public fun init(
        _sender: &signer,
        _total_amount: u128,
        _begin_time: u64,
        _interval: u64,
        _release_per_time: u128
    ) {
        abort Errors::deprecated(ERR_DEPRECRATED)
    }

    public entry fun uninit_entry(_sender: signer) {
        abort Errors::deprecated(ERR_DEPRECRATED)
    }

    public entry fun buy_back_entry(_sender: signer) {
        abort Errors::deprecated(ERR_DEPRECRATED)
    }

    public entry fun deposit_entry(_sender: signer, _amount: u128) {
        abort Errors::deprecated(ERR_DEPRECRATED)
    }


    public fun query_info(): (u128, u128, u128, u64, u64, u64, u64, u128, u128) {
        abort Errors::deprecated(ERR_DEPRECRATED)
    }

    public fun pool_exists(): bool {
        abort Errors::deprecated(ERR_DEPRECRATED)
    }

    public entry fun set_release_per_time_entry(_sender: signer, _release_per_time: u128) {
        abort Errors::deprecated(ERR_DEPRECRATED)
    }

    public entry fun set_interval_entry(_sender: signer, _interval: u64) {
        abort Errors::deprecated(ERR_DEPRECRATED)
    }
}
