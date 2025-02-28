module swap_admin::BuyBackSTAR {

    use starcoin_framework::coin;
    use starcoin_framework::starcoin_coin::STC;

    use swap_admin::BuyBack;
    use swap_admin::STAR::STAR;
    use swap_admin::TimelyReleasePool;
    use swap_admin::TokenSwapRouter;

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
        BuyBack::dismiss<BuyBackSTAR, STC>(&sender);
    }

    public entry fun buy_back(sender: signer) {
        BuyBack::buy_back<BuyBackSTAR, STAR, STC>(&sender, @buy_back_account);
    }

    public entry fun deposit(sender: signer, amount: u128) {
        let token = coin::withdraw<STC>(&sender, (amount as u64));
        BuyBack::deposit<BuyBackSTAR, STC>(@buy_back_account, token);
    }

    public fun init_func(
        sender: &signer,
        total_amount: u128,
        begin_time: u64,
        interval: u64,
        release_per_time: u128
    ) {
        BuyBack::init_event(sender);
        BuyBack::accept<BuyBackSTAR, STAR, STC>(
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
        ) = TimelyReleasePool::query_pool_info<BuyBackSTAR, STC>(@buy_back_account);

        let amount_y_out = if (current_time_amount > 0) {
            TokenSwapRouter::compute_y_out<STC, STAR>(current_time_amount)
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
        BuyBack::pool_exists<BuyBackSTAR, STC>(@buy_back_account)
    }

    public entry fun set_release_per_time(sender: signer, release_per_time: u128) {
        BuyBack::set_release_per_time<BuyBackSTAR, STC>(&sender, release_per_time);
    }

    public entry fun set_interval(sender: signer, interval: u64) {
        BuyBack::set_interval<BuyBackSTAR, STC>(&sender, interval);
    }
}
