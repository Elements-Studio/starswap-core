address SwapAdmin {
module BuyBackSTAR {

    use StarcoinFramework::STC;
    use StarcoinFramework::Account;

    use SwapAdmin::BuyBack;
    use SwapAdmin::STAR;
    use SwapAdmin::TimelyReleasePool;
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::Errors;

    struct BuyBackSTAR has store {}

    public fun init(
        sender: signer,
        total_amount: u128,
        begin_time: u64,
        interval: u64,
        release_per_time: u128
    ) {
        init_func(&sender, total_amount, begin_time, interval, release_per_time);
    }

    public entry fun uninit(sender: signer) {
        BuyBack::dismiss<BuyBackSTAR, STC::STC>(&sender);
    }

    public entry fun buy_back(sender: signer) {
        BuyBack::buy_back<BuyBackSTAR, STAR::STAR, STC::STC>(&sender, @BuyBackAccount);
    }

    public entry fun deposit(sender: signer, amount: u128) {
        let token = Account::withdraw<STC::STC>(&sender, amount);
        BuyBack::deposit<BuyBackSTAR, STC::STC>(@BuyBackAccount, token);
    }

    public fun init_func(
        sender: &signer,
        total_amount: u128,
        begin_time: u64,
        interval: u64,
        release_per_time: u128
    ) {
        BuyBack::init_event(sender);
        BuyBack::accept<BuyBackSTAR, STAR::STAR, STC::STC>(
            sender,
            total_amount,
            begin_time,
            interval,
            release_per_time
        );
    }

    public fun query_info(): (u128, u128, u128, u64, u64, u64, u64, u128, u128) {
        let (
            treasury_balance,
            total_treasury_amount,
            release_per_time,
            begin_time,
            latest_withdraw_time,
            interval,
            current_time_stamp,
            current_time_amount,
        ) = TimelyReleasePool::query_pool_info<BuyBackSTAR, STC::STC>(@BuyBackAccount);

        let amount_y_out = if (current_time_amount > 0) {
            TokenSwapRouter::compute_y_out<STC::STC, STAR::STAR>(current_time_amount)
        } else {
            0
        };

        (
            treasury_balance,
            total_treasury_amount,
            release_per_time,
            begin_time,
            latest_withdraw_time,
            interval,
            current_time_stamp,
            current_time_amount,
            amount_y_out,
        )
    }

    public fun pool_exists(): bool {
        BuyBack::pool_exists<BuyBackSTAR, STC::STC>(@BuyBackAccount)
    }

    public entry fun set_release_per_time(sender: signer, release_per_time: u128) {
        BuyBack::set_release_per_time<BuyBackSTAR, STC::STC>(&sender, release_per_time);
    }

    public entry fun set_interval(sender: signer, interval: u64) {
        BuyBack::set_interval<BuyBackSTAR, STC::STC>(&sender, interval);
    }

    /// DEPRECRATED
    public entry fun upgrade_event_store_for_barnard(_account: signer) {
        abort Errors::deprecated(1)
    }
}
}
