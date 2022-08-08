address SwapAdmin {

module BuyBack {

    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Event;

    use SwapAdmin::TimelyReleasePool;
    use SwapAdmin::TokenSwapRouter;

    const ERROR_TREASURY_HAS_EXISTS: u64 = 1001;
    const ERROR_NO_PERMISSION: u64 = 1002;

    struct BuyBackCap<phantom PoolT, phantom TokenT> has key {
        cap: TimelyReleasePool::WithdrawCapability<PoolT, TokenT>
    }

    struct AcceptEvent has key, store, drop {
        sell_token_code: Token::TokenCode,
        buy_token_code: Token::TokenCode,
        total_amount: u128,
        user: address,
    }

    struct BuyBackEvent has key, store, drop {
        sell_token_code: Token::TokenCode,
        buy_token_code: Token::TokenCode,
        sell_amount: u128,
        buy_amount: u128,
        user: address,
    }

    struct EventStore has key {
        /// event stream for withdraw
        accept_event_handle: Event::EventHandle<AcceptEvent>,
        /// event stream for deposit
        purchease_event_handle: Event::EventHandle<BuyBackEvent>,
    }

    public fun init_event(sender: &signer) {
        let sender_addr = Signer::address_of(sender);
        assert!(sender_addr == @BuyBackAccount, Errors::invalid_state(ERROR_NO_PERMISSION));

        move_to(sender, EventStore {
            accept_event_handle: Event::new_event_handle<AcceptEvent>(sender),
            purchease_event_handle: Event::new_event_handle<BuyBackEvent>(sender),
        });
    }

    /// Accept with token type
    public fun accept<PoolT: store, SellTokenT: store, BuyTokenT: store>(
        sender: &signer,
        total_amount: u128,
        begin_time: u64,
        interval: u64,
        release_per_time: u128
    ) acquires EventStore {
        let sender_address = Signer::address_of(sender);
        assert!(sender_address == @BuyBackAccount, Errors::invalid_state(ERROR_NO_PERMISSION));
        assert!(
            !exists<BuyBackCap<PoolT, BuyTokenT>>(Signer::address_of(sender)),
            Errors::invalid_state(ERROR_TREASURY_HAS_EXISTS)
        );

        // Deposit buy token to treasury
        let token = Account::withdraw<BuyTokenT>(sender, total_amount);
        let cap =
            TimelyReleasePool::init<PoolT, BuyTokenT>(
                sender,
                token,
                begin_time,
                interval,
                release_per_time);

        move_to(sender, BuyBackCap<PoolT, BuyTokenT> {
            cap
        });

        // Auto accept sell token
        if (!Account::is_accept_token<SellTokenT>(sender_address)) {
            Account::do_accept_token<SellTokenT>(sender);
        };

        let event_store = borrow_global_mut<EventStore>(@BuyBackAccount);
        Event::emit_event(&mut event_store.accept_event_handle, AcceptEvent {
            buy_token_code: Token::token_code<BuyTokenT>(),
            sell_token_code: Token::token_code<SellTokenT>(),
            total_amount,
            user: sender_address,
        });
    }

    /// buy back from a token type to a token type
    public fun buy_back<PoolT: store,
                        SellTokenT: copy + drop + store,
                        BuyTokenT: copy + drop + store>(
        sender: &signer,
        broker: address,
        slipper: u128,
    ): Token::Token<BuyTokenT> acquires BuyBackCap, EventStore {
        let cap = borrow_global<BuyBackCap<PoolT, BuyTokenT>>(broker);
        let buy_token = TimelyReleasePool::withdraw(broker, &cap.cap);
        let buy_token_val = Token::value<BuyTokenT>(&buy_token);
        let y_out = TokenSwapRouter::compute_y_out<SellTokenT, BuyTokenT>(
            buy_token_val,
            buy_token_val + slipper);

        let sender_addr = Signer::address_of(sender);
        let sell_token = Account::withdraw<SellTokenT>(sender, y_out);

        Account::deposit<SellTokenT>(@BuyBackAccount, sell_token);

        let event_store = borrow_global_mut<EventStore>(@BuyBackAccount);
        Event::emit_event(&mut event_store.purchease_event_handle, BuyBackEvent {
            sell_token_code: Token::token_code<SellTokenT>(),
            buy_token_code: Token::token_code<BuyTokenT>(),
            sell_amount: y_out,
            buy_amount: buy_token_val,
            user: sender_addr,
        });

        buy_token
    }

    /// Release per time
    public fun set_release_per_time<PoolT: store, TokenT: store>(sender: &signer, release_per_time: u128)
    acquires BuyBackCap {
        let sender_address = Signer::address_of(sender);
        assert!(sender_address == @BuyBackAccount, Errors::invalid_state(ERROR_NO_PERMISSION));

        let cap = borrow_global_mut<BuyBackCap<PoolT, TokenT>>(Signer::address_of(sender));
        set_release_per_time_with_cap<PoolT, TokenT>(cap, release_per_time);
    }

    public fun set_release_per_time_with_cap<PoolT: store, TokenT: store>(cap: &BuyBackCap<PoolT, TokenT>, release_per_time: u128) {
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
}
}