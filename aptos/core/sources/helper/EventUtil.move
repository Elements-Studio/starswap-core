module SwapAdmin::EventUtil {
    use std::error;
    use std::signer;

    use aptos_std::event;
    use aptos_framework::account;

    const ERR_INIT_REPEATE: u64 = 101;
    const ERR_RESOURCE_NOT_EXISTS: u64 = 102;

    struct EventHandleWrapper<phantom EventT: store + drop> has key {
        handle: event::EventHandle<EventT>,
    }

    public fun init_event<EventT: store + drop>(sender: &signer) {
        let broker = signer::address_of(sender);
        assert!(!exists<EventHandleWrapper<EventT>>(broker), error::invalid_state(ERR_INIT_REPEATE));
        move_to(sender, EventHandleWrapper<EventT> {
            handle: account::new_event_handle<EventT>(sender)
        });
    }

    public fun uninit_event<EventT: store + drop>(sender: &signer) acquires EventHandleWrapper {
        let broker = signer::address_of(sender);
        assert!(exists<EventHandleWrapper<EventT>>(broker), error::invalid_state(ERR_RESOURCE_NOT_EXISTS));
        let EventHandleWrapper<EventT> { handle } = move_from<EventHandleWrapper<EventT>>(broker);
        event::destroy_handle<EventT>(handle);
    }

    public fun emit_event<EventT: store + drop>(broker: address, event: EventT) acquires EventHandleWrapper {
        let event_handle = borrow_global_mut<EventHandleWrapper<EventT>>(broker);
        event::emit_event(&mut event_handle.handle, event);
    }

    public fun exist_event<EventT: store + drop>(broker: address): bool {
        exists<EventHandleWrapper<EventT>>(broker)
    }
}
