address SwapAdmin {
module TimelyReleasePool {

    use StarcoinFramework::Errors;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Token;

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


    public fun init<PoolT: store, TokenT: store>(
        sender: &signer,
        init_token: Token::Token<TokenT>,
        begin_time: u64,
        interval: u64,
        release_per_time: u128
    ): WithdrawCapability<PoolT, TokenT> {
        let sender_addr = Signer::address_of(sender);
        assert!(
            !exists<TimelyReleasePool<PoolT, TokenT>>(sender_addr),
            Errors::invalid_state(ERROR_LINEAR_RELEASE_EXISTS)
        );

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
    public fun deposit<PoolT: store, TokenT: store>(
        broker: address,
        token: Token::Token<TokenT>
    ) acquires TimelyReleasePool {
        // Deposit into treasury
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, TokenT>>(broker);
        pool.total_treasury_amount = pool.total_treasury_amount + Token::value(&token);
        Token::deposit<TokenT>(&mut pool.treasury, token);

        // Update latest release time and latest withdraw time
        update_pool_times(pool, Timestamp::now_seconds());
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

    public fun set_interval<PoolT: store, TokenT: store>(
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
        let now_seconds = Timestamp::now_seconds();
        let pool = borrow_global_mut<TimelyReleasePool<PoolT, TokenT>>(broker);
        assert!(Token::value(&pool.treasury) > 0, Errors::invalid_state(ERROR_TRESURY_IS_EMPTY));
        assert!(now_seconds > pool.begin_time, Errors::invalid_state(ERROR_EVENT_NOT_START_YET));

        let rounds = calculate_rounds(now_seconds, pool.latest_release_time, pool.interval);

        // Calculate withdraw amount
        let withdraw_amount = (rounds as u128) * pool.release_per_time;
        let treasury_balance = Token::value(&pool.treasury);
        if (withdraw_amount > treasury_balance) {
            withdraw_amount = treasury_balance;
        };
        let token = Token::withdraw(&mut pool.treasury, withdraw_amount);

        // Update latest release time and latest withdraw time
        pool.latest_withdraw_time = now_seconds;
        pool.latest_release_time = pool.latest_release_time + (rounds * pool.interval);

        token
    }

    /// Update latest withdraw time and latest release time of pool
    fun update_pool_times<PoolT: store, TokenT: store>(
        pool: &mut TimelyReleasePool<PoolT, TokenT>,
        now_seconds: u64
    ) {
        let rounds = calculate_rounds(
            now_seconds,
            pool.latest_release_time,
            pool.interval
        );
        pool.latest_withdraw_time = now_seconds;
        pool.latest_release_time = pool.latest_release_time + (rounds * pool.interval);
    }

    /// Calculate rounds between two time point
    /// @return rounds
    fun calculate_rounds(now_seconds: u64, latest_release_time: u64, round_interval: u64): u64 {
        let time_interval = now_seconds - latest_release_time;
        assert!(time_interval >= round_interval, Errors::invalid_state(ERROR_LINEAR_NOT_READY_YET));
        time_interval / round_interval
    }

    /// query pool info
    public fun query_pool_info<PoolT: store, TokenT: store>(
        broker: address
    ): (u128, u128, u128, u64, u64, u64, u64, u128)
    acquires TimelyReleasePool {
        let pool = borrow_global<TimelyReleasePool<PoolT, TokenT>>(broker);
        let now = Timestamp::now_seconds();

        let (current_time_amount, current_time_stamp) = if (pool.latest_release_time < now) {
            // The pool has started
            let rounds = (now - pool.latest_release_time) / pool.interval;
            if (rounds == 0) { rounds = 1 }; // One time minimized

            let current_time_stamp = pool.latest_release_time + ((rounds + 1) * pool.interval);
            let current_time_amount = (rounds as u128) * pool.release_per_time;

            let treasury_balance = Token::value(&pool.treasury);
            if (current_time_amount > treasury_balance) {
                (treasury_balance, current_time_stamp)
            } else {
                (current_time_amount, current_time_stamp)
            }
        } else {
            // The pool not start yet
            (pool.release_per_time, 0)
        };

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

