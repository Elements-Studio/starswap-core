address SwapAdmin {

module Repurchease {

    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;

    use SwapAdmin::TimelyReleasePool;
    use StarcoinFramework::Token;
    use SwapAdmin::TokenSwapRouter;

    const ERROR_TREASURY_HAS_EXISTS: u64 = 1001;

    struct LinearReleaseCap<phantom PoolT, phantom TokenT> has key {
        cap: TimelyReleasePool::WithdrawCapability<PoolT, TokenT>
    }

    struct RecycledPool<phantom TokenT> has key {
        token: Token::Token<TokenT>,
    }

    public fun accept<PoolT: store, TokenT: store>(sender: &signer,
                                                   amount: u128,
                                                   begin_time: u64,
                                                   release_per_second: u128) {
        assert!(
            exists<LinearReleaseCap<PoolT, TokenT>>(Signer::address_of(sender)),
            Errors::invalid_state(ERROR_TREASURY_HAS_EXISTS)
        );

        let token = Account::withdraw<TokenT>(sender, amount);
        let cap = TimelyReleasePool::init<PoolT, TokenT>(sender, token, begin_time, release_per_second);
        move_to(sender, LinearReleaseCap<PoolT, TokenT> {
            cap
        });
    }

    /// Purchease from a token type to a token
    public fun purchease<PoolT: store,
                         FromTokenT: copy + drop + store,
                         ToTokenT: copy + drop + store>(
        sender: &signer,
        broker: address
    ): Token::Token<ToTokenT> acquires LinearReleaseCap, RecycledPool {
        let slipper = 0; // TODO: get slipper amount from config
        let cap = borrow_global<LinearReleaseCap<PoolT, ToTokenT>>(broker);
        let to_token = TimelyReleasePool::withdraw(broker, &cap.cap);
        let to_token_val = Token::value<ToTokenT>(&to_token);
        let y_out = TokenSwapRouter::compute_y_out<ToTokenT, FromTokenT>(to_token_val, to_token_val + slipper);

        let from_token = Account::withdraw<FromTokenT>(sender, y_out);
        let pool = borrow_global_mut<RecycledPool<FromTokenT>>(broker);
        Token::deposit<FromTokenT>(&mut pool.token, from_token);

        to_token
    }
}
}