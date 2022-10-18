module SwapAdmin::EventUtil {
    use aptos_framework::account;
    use aptos_std::event;
    use std::signer;

    struct EventHandleWrapper<phantom EventT: store + drop> has key {
        handle: event::EventHandle<EventT>,
    }

    public fun init_event_with_T<EventT: store + drop>(sender: &signer) {
        let broker = signer::address_of(sender);
        if (exists<EventHandleWrapper<EventT>>(broker)) {
            return
        };
        move_to(sender, EventHandleWrapper<EventT> {
            handle: account::new_event_handle<EventT>(sender)
        });
    }

    public fun uninit_event_with_T<EventT: store + drop>(sender: &signer) acquires EventHandleWrapper {
        let broker = signer::address_of(sender);
        if (!exists<EventHandleWrapper<EventT>>(broker)) {
            return
        };
        let EventHandleWrapper<EventT> { handle } = move_from<EventHandleWrapper<EventT>>(broker);
        event::destroy_handle<EventT>(handle);
    }

    public fun emit_event<EventT: store + drop>(broker: address, event: EventT) acquires EventHandleWrapper {
        let event_handle = borrow_global_mut<EventHandleWrapper<EventT>>(broker);
        event::emit_event(&mut event_handle.handle, event);
    }

    public fun exist_event_T<EventT: store + drop>(broker: address): bool {
        exists<EventHandleWrapper<EventT>>(broker)
    }
}
