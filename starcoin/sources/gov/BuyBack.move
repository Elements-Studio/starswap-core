address SwapAdmin {

module BuyBack {

    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Event;

    use SwapAdmin::EventUtil;
    use SwapAdmin::TimelyReleasePool;
    use SwapAdmin::TokenSwapRouter;

    const ERROR_TREASURY_HAS_EXISTS: u64 = 1001;
    const ERROR_NO_PERMISSION: u64 = 1002;
    const ERROR_INIT_REPEATE: u64 = 1003;

    struct BuyBackCap<phantom PoolT, phantom TokenT> has key {
        cap: TimelyReleasePool::WithdrawCapability<PoolT, TokenT>
    }

    struct AcceptEvent has key, store, drop {
        sell_token_code: Token::TokenCode,
        buy_token_code: Token::TokenCode,
        total_amount: u128,
        user: address,
    }

    struct DissmissEvent has key, store, drop {
        buy_token_code: Token::TokenCode,
        user: address,
    }

    struct BuyBackEvent has key, store, drop {
        sell_token_code: Token::TokenCode,
        buy_token_code: Token::TokenCode,
        sell_amount: u128,
        buy_amount: u128,
        user: address,
    }

    /// DEPRECRATED
    struct EventHandleWrapper<phantom EventT: store + drop> has key {
        handle: Event::EventHandle<EventT>,
    }

    /// DEPRECRATED
    struct EventStore has key {
        /// event stream for withdraw
        accept_event_handle: Event::EventHandle<AcceptEvent>,
        /// event stream for deposit
        payback_event_handle: Event::EventHandle<BuyBackEvent>,
    }

    public fun init_event(sender: &signer) {
        let sender_addr = Signer::address_of(sender);
        assert!(sender_addr == @BuyBackAccount, Errors::invalid_state(ERROR_NO_PERMISSION));
        assert!(!EventUtil::exist_event<AcceptEvent>(sender_addr), Errors::invalid_state(ERROR_INIT_REPEATE));

        EventUtil::init_event<AcceptEvent>(sender);
        EventUtil::init_event<BuyBackEvent>(sender);
        EventUtil::init_event<DissmissEvent>(sender);
    }

    /// Check pool has exists
    public fun pool_exists<PoolT: store, BuyTokenT: store>(broker: address): bool {
        exists<BuyBackCap<PoolT, BuyTokenT>>(broker)
    }

    /// Accept with token type
    public fun accept<PoolT: store, SellTokenT: store, BuyTokenT: store>(
        sender: &signer,
        total_amount: u128,
        begin_time: u64,
        interval: u64,
        release_per_time: u128
    ) {
        let broker = Signer::address_of(sender);
        assert!(!exists<BuyBackCap<PoolT, BuyTokenT>>(broker), Errors::invalid_state(ERROR_TREASURY_HAS_EXISTS));

        // Deposit buy token to treasury
        let token = Account::withdraw<BuyTokenT>(sender, total_amount);
        let cap =
            TimelyReleasePool::init<PoolT, BuyTokenT>(sender, token, begin_time, interval, release_per_time);
        move_to(sender, BuyBackCap<PoolT, BuyTokenT> {
            cap
        });

        // Auto accept sell token
        if (!Account::is_accept_token<SellTokenT>(broker)) {
            Account::do_accept_token<SellTokenT>(sender);
        };

        EventUtil::emit_event(@BuyBackAccount, AcceptEvent {
            buy_token_code: Token::token_code<BuyTokenT>(),
            sell_token_code: Token::token_code<SellTokenT>(),
            total_amount,
            user: broker,
        });
    }

    /// Dismiss the token type
    public fun dismiss<PoolT: store, BuyTokenT: store>(sender: &signer) acquires BuyBackCap {
        let sender_addr = Signer::address_of(sender);
        assert!(sender_addr == @BuyBackAccount, Errors::invalid_state(ERROR_NO_PERMISSION));

        let BuyBackCap<PoolT, BuyTokenT> { cap } =
            move_from<BuyBackCap<PoolT, BuyTokenT>>(sender_addr);

        let treasury_token = TimelyReleasePool::uninit<PoolT, BuyTokenT>(cap, @BuyBackAccount);
        Account::deposit(sender_addr, treasury_token);

        // Emit dissmiss event
        EventUtil::emit_event(@BuyBackAccount, DissmissEvent {
            buy_token_code: Token::token_code<BuyTokenT>(),
            user: sender_addr,
        })
    }

    /// Deposit into
    public fun deposit<PoolT: store, BuyTokenT: store>(broker: address, token: Token::Token<BuyTokenT>) {
        TimelyReleasePool::deposit<PoolT, BuyTokenT>(broker, token);
    }

    /// buy back from a token type to a token type
    public fun buy_back<PoolT: store,
                        SellTokenT: copy + drop + store,
                        BuyTokenT: copy + drop + store>(
        sender: &signer,
        broker: address,
    ) acquires BuyBackCap {
        let sender_addr = Signer::address_of(sender);
        assert!(exists<BuyBackCap<PoolT, BuyTokenT>>(broker), Errors::invalid_state(ERROR_NO_PERMISSION));

        let cap = borrow_global<BuyBackCap<PoolT, BuyTokenT>>(broker);

        // Withdraw from timely release pool
        let buy_token = TimelyReleasePool::withdraw(broker, &cap.cap);
        let amount_x_in = Token::value<BuyTokenT>(&buy_token);

        // Deposit to trigger account
        let amount_y_out = TokenSwapRouter::compute_y_out<BuyTokenT, SellTokenT>(amount_x_in);

        Account::deposit<BuyTokenT>(sender_addr, buy_token);

        // User do swap from swap pool
        TokenSwapRouter::swap_exact_token_for_token<BuyTokenT, SellTokenT>(sender, amount_x_in, amount_y_out);

        // Withdraw SellToken from swap trigger account
        Account::deposit<SellTokenT>(broker, Account::withdraw<SellTokenT>(sender, amount_y_out));

        EventUtil::emit_event(@BuyBackAccount, BuyBackEvent {
            sell_token_code: Token::token_code<SellTokenT>(),
            buy_token_code: Token::token_code<BuyTokenT>(),
            sell_amount: amount_y_out,
            buy_amount: amount_x_in,
            user: sender_addr,
        });
    }

    /// Release per time
    public fun set_release_per_time<PoolT: store, TokenT: store>(sender: &signer, release_per_time: u128)
    acquires BuyBackCap {
        let sender_address = Signer::address_of(sender);
        assert!(sender_address == @BuyBackAccount, Errors::invalid_state(ERROR_NO_PERMISSION));

        let cap = borrow_global_mut<BuyBackCap<PoolT, TokenT>>(Signer::address_of(sender));
        set_release_per_time_with_cap<PoolT, TokenT>(cap, release_per_time);
    }

    public fun set_release_per_time_with_cap<PoolT: store, TokenT: store>(cap: &BuyBackCap<PoolT, TokenT>,
                                                                          release_per_time: u128) {
        TimelyReleasePool::set_release_per_time<PoolT, TokenT>(@BuyBackAccount, release_per_time, &cap.cap);
    }

    /// Interval value
    public fun set_interval<PoolT: store, TokenT: store>(sender: &signer, interval: u64)
    acquires BuyBackCap {
        let sender_address = Signer::address_of(sender);
        assert!(sender_address == @BuyBackAccount, Errors::invalid_state(ERROR_NO_PERMISSION));

        let cap = borrow_global_mut<BuyBackCap<PoolT, TokenT>>(Signer::address_of(sender));
        set_interval_with_cap<PoolT, TokenT>(cap, interval);
    }

    public fun set_interval_with_cap<PoolT: store, TokenT: store>(cap: &BuyBackCap<PoolT, TokenT>, interval: u64) {
        TimelyReleasePool::set_interval<PoolT, TokenT>(@BuyBackAccount, interval, &cap.cap);
    }

    /// Extract capability if need DAO to propose config parameter
    public fun extract_cap<PoolT: store, TokenT: store>(sender: &signer): BuyBackCap<PoolT, TokenT> acquires BuyBackCap {
        let cap = move_from<BuyBackCap<PoolT, TokenT>>(Signer::address_of(sender));
        cap
    }

    /// DEPRECRETED
    public fun upgrade_event_struct(_account: &signer) {
        abort Errors::invalid_state(1)
    }
}
}