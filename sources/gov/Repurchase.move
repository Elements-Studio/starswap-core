address SwapAdmin {

module Repurchease {

    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Event;

    use SwapAdmin::TimelyReleasePool;
    use SwapAdmin::TokenSwapRouter;

    const ERROR_TREASURY_HAS_EXISTS: u64 = 1001;
    const ERROR_NO_PERMISSION: u64 = 1002;

    struct RepurchaseCap<phantom PoolT, phantom TokenT> has key {
        cap: TimelyReleasePool::WithdrawCapability<PoolT, TokenT>
    }

    struct AcceptEvent has key, store, drop {
        from_token_code: Token::TokenCode,
        to_token_code: Token::TokenCode,
        total_amount: u128,
        user: address,
    }

    struct PurchaseEvent has key, store, drop {
        from_token_code: Token::TokenCode,
        to_token_code: Token::TokenCode,
        from_amount: u128,
        to_amount: u128,
        user: address,
    }

    struct EventStore has key {
        /// event stream for withdraw
        accept_event_handle: Event::EventHandle<AcceptEvent>,
        /// event stream for deposit
        purchease_event_handle: Event::EventHandle<PurchaseEvent>,
    }

    public fun init_event(sender: &signer) {
        assert!(Signer::address_of(sender) == @RepurcheseAccount, Errors::invalid_state(ERROR_NO_PERMISSION));

        move_to(sender, EventStore {
            accept_event_handle: Event::new_event_handle<AcceptEvent>(sender),
            purchease_event_handle: Event::new_event_handle<PurchaseEvent>(sender),
        });
    }

    /// Accept with token type
    public fun accept<PoolT: store, FromTokenT: store, ToTokenT: store>(
        sender: &signer,
        total_amount: u128,
        begin_time: u64,
        interval: u64,
        release_per_time: u128
    ) acquires EventStore {
        let sender_address = Signer::address_of(sender);
        assert!(sender_address == @RepurcheseAccount, Errors::invalid_state(ERROR_NO_PERMISSION));
        assert!(
            exists<RepurchaseCap<PoolT, ToTokenT>>(Signer::address_of(sender)),
            Errors::invalid_state(ERROR_TREASURY_HAS_EXISTS)
        );

        let token = Account::withdraw<ToTokenT>(sender, total_amount);
        let cap =
            TimelyReleasePool::init<PoolT, ToTokenT>(
                sender,
                token,
                begin_time,
                interval,
                release_per_time);

        move_to(sender, RepurchaseCap<PoolT, ToTokenT> {
            cap
        });

        if (Account::is_accept_token<FromTokenT>(sender_address)) {
            Account::do_accept_token<FromTokenT>(sender);
        };

        let event_store = borrow_global_mut<EventStore>(@RepurcheseAccount);
        Event::emit_event(&mut event_store.accept_event_handle, AcceptEvent {
            from_token_code: Token::token_code<FromTokenT>(),
            to_token_code: Token::token_code<ToTokenT>(),
            total_amount,
            user: sender_address,
        });
    }

    /// Release per time
    public fun set_release_per_time<PoolT: store, TokenT: store>(sender: &signer, release_per_time: u128)
    acquires RepurchaseCap {
        let sender_address = Signer::address_of(sender);
        assert!(sender_address == @RepurcheseAccount, Errors::invalid_state(ERROR_NO_PERMISSION));

        let cap = borrow_global_mut<RepurchaseCap<PoolT, TokenT>>(Signer::address_of(sender));
        set_release_per_time_with_cap<PoolT, TokenT>(cap, release_per_time);
    }

    public fun set_release_per_time_with_cap<PoolT: store, TokenT: store>(cap: &RepurchaseCap<PoolT, TokenT>, release_per_time: u128) {
        TimelyReleasePool::set_release_per_time<PoolT, TokenT>(@RepurcheseAccount, release_per_time, &cap.cap);
    }

    /// Interval value
    public fun set_interval<PoolT: store, TokenT: store>(sender: &signer, interval: u64)
    acquires RepurchaseCap {
        let sender_address = Signer::address_of(sender);
        assert!(sender_address == @RepurcheseAccount, Errors::invalid_state(ERROR_NO_PERMISSION));

        let cap = borrow_global_mut<RepurchaseCap<PoolT, TokenT>>(Signer::address_of(sender));
        set_interval_with_cap<PoolT, TokenT>(cap, interval);
    }

    public fun set_interval_with_cap<PoolT: store, TokenT: store>(cap: &RepurchaseCap<PoolT, TokenT>, interval: u64) {
        TimelyReleasePool::set_interval<PoolT, TokenT>(@RepurcheseAccount, interval, &cap.cap);
    }

    /// Extract capability if need DAO to propose config parameter
    public fun extract_cap<PoolT: store, TokenT: store>(sender: &signer): RepurchaseCap<PoolT, TokenT> acquires RepurchaseCap {
        let cap = move_from<RepurchaseCap<PoolT, TokenT>>(Signer::address_of(sender));
        cap
    }

    /// Purchease from a token type to a token
    public fun purchase<PoolT: store,
                        FromTokenT: copy + drop + store,
                        ToTokenT: copy + drop + store>(
        sender: &signer,
        broker: address,
        slipper: u128,
    ): Token::Token<ToTokenT> acquires RepurchaseCap, EventStore {
        let cap = borrow_global<RepurchaseCap<PoolT, ToTokenT>>(broker);
        let to_token = TimelyReleasePool::withdraw(broker, &cap.cap);
        let to_token_val = Token::value<ToTokenT>(&to_token);
        let y_out = TokenSwapRouter::compute_y_out<ToTokenT, FromTokenT>(to_token_val, to_token_val + slipper);

        Account::deposit<FromTokenT>(@RepurcheseAccount, Account::withdraw<FromTokenT>(sender, y_out));

        let event_store = borrow_global_mut<EventStore>(@RepurcheseAccount);
        Event::emit_event(&mut event_store.purchease_event_handle, PurchaseEvent {
            from_token_code: Token::token_code<FromTokenT>(),
            to_token_code: Token::token_code<ToTokenT>(),
            from_amount: y_out,
            to_amount: to_token_val,
            user: Signer::address_of(sender),
        });

        to_token
    }
}
}