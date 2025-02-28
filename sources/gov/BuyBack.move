module swap_admin::BuyBack {

    use std::error;
    use std::signer;
    use std::string;

    use starcoin_framework::account;
    use starcoin_framework::coin;
    use starcoin_framework::event;

    use starcoin_std::type_info;

    use swap_admin::TimelyReleasePool;
    use swap_admin::TokenSwapRouter;

    const ERROR_TREASURY_HAS_EXISTS: u64 = 1001;
    const ERROR_NO_PERMISSION: u64 = 1002;
    const ERROR_INIT_REPEATE: u64 = 1003;

    struct BuyBackCap<phantom PoolT, phantom TokenT> has key {
        cap: TimelyReleasePool::WithdrawCapability<PoolT, TokenT>
    }

    struct AcceptEvent has key, store, drop {
        sell_token_code: string::String,
        buy_token_code: string::String,
        total_amount: u128,
        user: address,
    }

    struct DissmissEvent has key, store, drop {
        buy_token_code: string::String,
        user: address,
    }

    struct BuyBackEvent has key, store, drop {
        sell_token_code: string::String,
        buy_token_code: string::String,
        sell_amount: u128,
        buy_amount: u128,
        user: address,
    }

    struct EventStore has key {
        accept_event_handle: event::EventHandle<AcceptEvent>,
        payback_event_handle: event::EventHandle<BuyBackEvent>,
        dismiss_event_handle: event::EventHandle<DissmissEvent>,
    }

    public fun init_event(account: &signer) {
        let account_addr = signer::address_of(account);
        assert!(account_addr == @buy_back_account, error::invalid_state(ERROR_NO_PERMISSION));

        // assert!(!event_util::exist_event<AcceptEvent>(sender_addr), error::invalid_state(ERROR_INIT_REPEATE));
        if (exists<EventStore>(@buy_back_account)) {
            return
        };

        move_to(account, EventStore {
            accept_event_handle: account::new_event_handle<AcceptEvent>(account),
            payback_event_handle: account::new_event_handle<BuyBackEvent>(account),
            dismiss_event_handle: account::new_event_handle<DissmissEvent>(account),
        });
    }

    /// Check pool has exists
    public fun pool_exists<PoolT: store, BuyTokenT>(broker: address): bool {
        exists<BuyBackCap<PoolT, BuyTokenT>>(broker)
    }

    /// Accept with token type
    public fun accept<PoolT: store, SellTokenT, BuyTokenT>(
        sender: &signer,
        total_amount: u128,
        begin_time: u64,
        interval: u64,
        release_per_time: u128
    ) acquires EventStore {
        let broker = signer::address_of(sender);
        assert!(!exists<BuyBackCap<PoolT, BuyTokenT>>(broker), error::invalid_state(ERROR_TREASURY_HAS_EXISTS));

        // Deposit buy token to treasury
        let token = coin::withdraw<BuyTokenT>(sender, (total_amount as u64));
        let cap =
            TimelyReleasePool::init<PoolT, BuyTokenT>(sender, token, begin_time, interval, release_per_time);
        move_to(sender, BuyBackCap<PoolT, BuyTokenT> {
            cap
        });

        // Auto accept sell token
        if (!coin::is_account_registered<SellTokenT>(broker)) {
            coin::register<SellTokenT>(sender);
        };

        let event_store = borrow_global_mut<EventStore>(@buy_back_account);
        event::emit_event(&mut event_store.accept_event_handle, AcceptEvent {
            buy_token_code: type_info::type_name<BuyTokenT>(),
            sell_token_code: type_info::type_name<SellTokenT>(),
            total_amount,
            user: broker,
        });
    }

    /// Dismiss the token type
    public fun dismiss<PoolT: store, BuyTokenT>(sender: &signer) acquires BuyBackCap, EventStore {
        let sender_addr = signer::address_of(sender);
        assert!(sender_addr == @buy_back_account, error::invalid_state(ERROR_NO_PERMISSION));

        let BuyBackCap<PoolT, BuyTokenT> { cap } =
            move_from<BuyBackCap<PoolT, BuyTokenT>>(sender_addr);

        let treasury_token = TimelyReleasePool::uninit<PoolT, BuyTokenT>(cap, @buy_back_account);
        coin::deposit(sender_addr, treasury_token);

        // Emit dissmiss event
        let event_store = borrow_global_mut<EventStore>(@buy_back_account);
        event::emit_event(&mut event_store.dismiss_event_handle, DissmissEvent {
            buy_token_code: type_info::type_name<BuyTokenT>(),
            user: sender_addr,
        })
    }

    /// Deposit into
    public fun deposit<PoolT: store, BuyTokenT>(broker: address, token: coin::Coin<BuyTokenT>) {
        TimelyReleasePool::deposit<PoolT, BuyTokenT>(broker, token);
    }

    /// buy back from a token type to a token type
    public fun buy_back<PoolT: store, SellTokenT, BuyTokenT>(
        sender: &signer,
        broker: address,
    ) acquires BuyBackCap, EventStore {
        let sender_addr = signer::address_of(sender);
        assert!(exists<BuyBackCap<PoolT, BuyTokenT>>(broker), error::invalid_state(ERROR_NO_PERMISSION));

        let cap = borrow_global<BuyBackCap<PoolT, BuyTokenT>>(broker);

        // Withdraw from timely release pool
        let buy_token = TimelyReleasePool::withdraw(broker, &cap.cap);
        let amount_x_in = (coin::value<BuyTokenT>(&buy_token) as u128);

        // Deposit to trigger account
        let amount_y_out = TokenSwapRouter::compute_y_out<BuyTokenT, SellTokenT>(amount_x_in);

        coin::deposit<BuyTokenT>(sender_addr, buy_token);

        // User do swap from swap pool
        TokenSwapRouter::swap_exact_token_for_token<BuyTokenT, SellTokenT>(sender, amount_x_in, amount_y_out);

        // Withdraw SellToken from swap trigger account
        coin::deposit<SellTokenT>(broker, coin::withdraw<SellTokenT>(sender, (amount_y_out as u64)));

        let event_store = borrow_global_mut<EventStore>(@buy_back_account);
        event::emit_event(&mut event_store.payback_event_handle, BuyBackEvent {
            sell_token_code: type_info::type_name<SellTokenT>(),
            buy_token_code: type_info::type_name<BuyTokenT>(),
            sell_amount: amount_y_out,
            buy_amount: amount_x_in,
            user: sender_addr,
        });
    }

    /// Release per time
    public fun set_release_per_time<PoolT: store, TokenT>(
        sender: &signer,
        release_per_time: u128
    ) acquires BuyBackCap {
        let sender_address = signer::address_of(sender);
        assert!(sender_address == @buy_back_account, error::invalid_state(ERROR_NO_PERMISSION));

        let cap = borrow_global_mut<BuyBackCap<PoolT, TokenT>>(signer::address_of(sender));
        set_release_per_time_with_cap<PoolT, TokenT>(cap, release_per_time);
    }

    /// Reset release per time
    fun set_release_per_time_with_cap<PoolT: store, TokenT>(
        cap: &BuyBackCap<PoolT, TokenT>,
        release_per_time: u128
    ) {
        TimelyReleasePool::set_release_per_time<PoolT, TokenT>(@buy_back_account, release_per_time, &cap.cap);
    }

    /// Interval value
    public fun set_interval<PoolT: store, TokenT>(sender: &signer, interval: u64) acquires BuyBackCap {
        let sender_address = signer::address_of(sender);
        assert!(sender_address == @buy_back_account, error::invalid_state(ERROR_NO_PERMISSION));

        let cap = borrow_global_mut<BuyBackCap<PoolT, TokenT>>(signer::address_of(sender));
        set_interval_with_cap<PoolT, TokenT>(cap, interval);
    }

    public fun set_interval_with_cap<PoolT: store, TokenT>(cap: &BuyBackCap<PoolT, TokenT>, interval: u64) {
        TimelyReleasePool::set_interval<PoolT, TokenT>(@buy_back_account, interval, &cap.cap);
    }

    /// Extract capability if need DAO to propose config parameter
    public fun extract_cap<PoolT: store, TokenT>(
        sender: &signer
    ): BuyBackCap<PoolT, TokenT> acquires BuyBackCap {
        let cap = move_from<BuyBackCap<PoolT, TokenT>>(signer::address_of(sender));
        cap
    }

    // /// DEPRECRETED
    // public fun upgrade_event_struct(_account: &signer) {
    //     abort error::invalid_state(1)
    // }
}