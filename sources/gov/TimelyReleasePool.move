address SwapAdmin {
module TimelyReleasePool {

    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Token;
    use StarcoinFramework::Timestamp;

    const ERROR_LINEAR_RELEASE_EXISTS: u64 = 2001;
    const ERROR_LINEAR_NOT_READY_YET: u64 = 2002;
    const ERROR_EVENT_INIT_REPEATE: u64 = 3003;
    const ERROR_EVENT_NOT_START_YET: u64 = 3004;
    const ERROR_TRESURY_IS_EMPTY: u64 = 3005;

    struct TimelyReleasePool<phantom PoolT, phantom TokenT> has key {
        // Total treasury amount
        total_treasury_amount: u128,
        // Treasury total amount
        treasury: Token::Token<TokenT>,
        // Release amount in each time
        release_per_time: u128,
        // Begin of release time
        begin_time: u64,
        // latest withdraw time
        latest_withdraw_time: u64,
        // latest release time
        latest_release_time: u64,
        // How long the user can withdraw in each period, 0 is every seconds
        interval: u64,
    }

    struct WithdrawCapability<phantom PoolT, phantom TokenT> has key, store {}


    public fun init<PoolT: store, TokenT: store>(sender: &signer,
                                                 init_token: Token::Token<TokenT>,
                                                 begin_time: u64,
                                                 interval: u64,
                                                 release_per_time: u128): WithdrawCapability<PoolT, TokenT> {
        let sender_addr = Signer::address_of(sender);
        assert!(!exists<TimelyReleasePool<PoolT, TokenT>>(sender_addr), Errors::invalid_state(ERROR_LINEAR_RELEASE_EXISTS));

        let total_treasury_amount = Token::value<TokenT>(&init_token);
        move_to(sender, TimelyReleasePool<PoolT, TokenT> {
            treasury: init_token,
            total_treasury_amount,
            release_per_time,
            begin_time,
            latest_withdraw_time: begin_time,
            latest_release_time: begin_time,
            interval,
        });

        WithdrawCapability<PoolT, TokenT> {}
    }

    /// Uninitialize a timely pool
    public fun uninit<PoolT: store, TokenT: store>(cap: WithdrawCapability<PoolT, TokenT>, broker: address)
    : Token::Token<TokenT> acquires TimelyReleasePool {
        let WithdrawCapability<PoolT, TokenT> {} = cap;
        let TimelyReleasePool<PoolT, TokenT> {
            total_treasury_amount: _,
            treasury,
            release_per_time: _,
            begin_time: _,
            latest_withdraw_time: _,
            latest_release_time: _,
            interval: _,
        } = move_from<TimelyReleasePool<PoolT, TokenT>>(broker);

        treasury
    }

    /// Deposit token to treasury
    public fun deposit<PoolT: store, TokenT: store>(broker: address,
                                                    token: Token::Token<TokenT>) acquires TimelyReleasePool {
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, TokenT>>(broker);
        pool.total_treasury_amount = pool.total_treasury_amount + Token::value(&token);
        Token::deposit<TokenT>(&mut pool.treasury, token);
    }

    /// Set release per time
    public fun set_release_per_time<PoolT: store, TokenT: store>(
        broker: address,
        release_per_time: u128,
        _cap: &WithdrawCapability<PoolT, TokenT>
    ) acquires TimelyReleasePool {
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, TokenT>>(broker);
        pool.release_per_time = release_per_time;
    }

    public fun set_interval<PoolT: store,
                            TokenT: store>(
        broker: address,
        interval: u64,
        _cap: &WithdrawCapability<PoolT, TokenT>
    ) acquires TimelyReleasePool {
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, TokenT>>(broker);
        pool.interval = interval;
    }

    /// Withdraw from treasury
    public fun withdraw<PoolT: store, TokenT: store>(broker: address, _cap: &WithdrawCapability<PoolT, TokenT>)
    : Token::Token<TokenT> acquires TimelyReleasePool {
        let now_time = Timestamp::now_seconds();
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, TokenT>>(broker);
        assert!(Token::value(&pool.treasury) > 0, Errors::invalid_state(ERROR_TRESURY_IS_EMPTY));
        assert!(now_time > pool.begin_time, Errors::invalid_state(ERROR_EVENT_NOT_START_YET));

        let time_interval = now_time - pool.latest_release_time;
        assert!(time_interval >= pool.interval, Errors::invalid_state(ERROR_LINEAR_NOT_READY_YET));
        let times = time_interval / pool.interval;

        let withdraw_amount = (times as u128) * pool.release_per_time;
        let treasury_balance = Token::value(&pool.treasury);
        if (withdraw_amount > treasury_balance) {
            withdraw_amount = treasury_balance;
        };

        let token = Token::withdraw(&mut pool.treasury, withdraw_amount);

        // Update latest release time and latest withdraw time
        pool.latest_withdraw_time = now_time;
        pool.latest_release_time = pool.latest_release_time + (times * pool.interval);

        token
    }

    /// query pool info
    public fun query_pool_info<PoolT: store, TokenT: store>(broker: address): (u128, u128, u128, u64, u64, u64, u64, u128)
    acquires TimelyReleasePool {
        let pool = borrow_global<TimelyReleasePool<PoolT, TokenT>>(broker);

        let now = Timestamp::now_seconds();
        let current_time_amount = if (pool.latest_release_time < now) {
            let time = (((now - pool.latest_release_time) / pool.interval) as u128);
            if (time == 0) { time = 1 }; // One time minimized

            let ret = time * pool.release_per_time;
            let treasury_balance = Token::value(&pool.treasury);
            if (ret > treasury_balance) {
                treasury_balance
            } else {
                ret
            }
        } else {
            pool.release_per_time
        };

        let diff = (now - pool.latest_release_time) / pool.interval;
        let current_time_stamp = pool.latest_release_time + ((diff + 1) * pool.interval);
        (
            Token::value<TokenT>(&pool.treasury),
            pool.total_treasury_amount,
            pool.release_per_time,
            pool.begin_time,
            pool.latest_withdraw_time,
            pool.interval,
            current_time_stamp,
            current_time_amount,
        )
    }
}
}

