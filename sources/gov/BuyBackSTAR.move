address SwapAdmin {

/// Deprecrated module, see instead module `BuyBackSTARScript`
module BuyBackSTAR {

    use StarcoinFramework::Errors;

    struct BuyBackSTAR has store {}

    const ERR_DEPRECRATED: u64 = 1;

    public(script) fun init(
        _sender: signer,
        _total_amount: u128,
        _begin_time: u64,
        _interval: u64,
        _release_per_time: u128
    ) {
        //init_func(&sender, total_amount, begin_time, interval, release_per_time);
        abort Errors::invalid_state(ERR_DEPRECRATED)
    }

    public(script) fun uninit(_sender: signer) {
        // BuyBack::dismiss<BuyBackSTAR, STC::STC>(&sender);
        abort Errors::invalid_state(ERR_DEPRECRATED)
    }

    public(script) fun buy_back(_sender: signer) {
        // BuyBack::buy_back<BuyBackSTAR, STAR::STAR, STC::STC>(&sender, @BuyBackAccount);
        abort Errors::invalid_state(ERR_DEPRECRATED)
    }

    public(script) fun deposit(_sender: signer, _amount: u128) {
        abort Errors::invalid_state(ERR_DEPRECRATED)
    }


    public fun query_info(): (u128, u128, u128, u64, u64, u64, u64, u128, u128) {
        abort Errors::invalid_state(ERR_DEPRECRATED)
    }

    public fun pool_exists(): bool {
        //BuyBack::pool_exists<BuyBackSTAR, STC::STC>(@BuyBackAccount)
        abort Errors::invalid_state(ERR_DEPRECRATED)
    }

    public(script) fun set_release_per_time(_sender: signer, _release_per_time: u128) {
        //BuyBack::set_release_per_time<BuyBackSTAR, STC::STC>(&sender, release_per_time);
        abort Errors::invalid_state(ERR_DEPRECRATED)
    }

    public(script) fun set_interval(_sender: signer, _interval: u64) {
        abort Errors::invalid_state(ERR_DEPRECRATED)
    }

    /// DEPRECRATED
    public (script) fun upgrade_event_store_for_barnard(_account: signer) {
        abort Errors::invalid_state(ERR_DEPRECRATED)
    }
}
}
