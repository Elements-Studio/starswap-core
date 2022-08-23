//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# publish
module SwapAdmin::TimelyReleaseWrapper {
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;

    use SwapAdmin::TimelyReleasePool;

    struct MockTimelyReleasePool has key, store {}

    struct WithdrawCapWrapper<phantom TokenT> has key {
        cap: TimelyReleasePool::WithdrawCapability<MockTimelyReleasePool, TokenT>,
    }

    public fun init<TokenT: store>(sender: &signer, amount: u128, begin_time: u64, interval: u64, release_per_time: u128) {
        let token = Account::withdraw<STC>(sender, amount);
        let withdraw_cap =
            TimelyReleasePool::init<MockTimelyReleasePool, STC>(
                sender, token, begin_time, interval, release_per_time);

        move_to(sender, WithdrawCapWrapper {
            cap: withdraw_cap,
        });
    }

    /// Withdraw from release pool
    public fun withdraw<TokenT: store>(): Token::Token<TokenT> acquires WithdrawCapWrapper {
        let wrapper =
            borrow_global_mut<WithdrawCapWrapper<TokenT>>(@SwapAdmin);
        TimelyReleasePool::withdraw<MockTimelyReleasePool, TokenT>(@SwapAdmin, &wrapper.cap)
    }

    public fun set_release_per_seconds<TokenT: store>(amount: u128) acquires WithdrawCapWrapper {
        let wrapper = borrow_global_mut<WithdrawCapWrapper<TokenT>>(@SwapAdmin);
        TimelyReleasePool::set_release_per_time<MockTimelyReleasePool, TokenT>(@SwapAdmin, amount, &wrapper.cap);
    }

    public fun set_interval<TokenT: store>(interval: u64) acquires WithdrawCapWrapper {
        let wrapper = borrow_global_mut<WithdrawCapWrapper<TokenT>>(@SwapAdmin);
        TimelyReleasePool::set_interval<MockTimelyReleasePool, TokenT>(@SwapAdmin, interval, &wrapper.cap);
    }

    public fun query_info<TokenT: store>(): (u128, u128, u128, u64, u64, u64, u64, u128) {
        TimelyReleasePool::query_pool_info<MockTimelyReleasePool, TokenT>(@SwapAdmin)
    }
}

//# run --signers SwapAdmin
script {
    use StarcoinFramework::STC::STC;

    use SwapAdmin::TokenMock::{Self, WUSDT};
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwap;

    fun init_token(signer: signer) {
        let scale_index: u8 = 9;
        TokenMock::register_token<WUSDT>(&signer, scale_index);

        CommonHelper::safe_mint<WUSDT>(&signer, CommonHelper::pow_amount<WUSDT>(1000000));

        // Register swap pair
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);

        assert!(TokenSwap::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Math;
    use StarcoinFramework::STC::STC;

    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::Debug;

    fun add_liquidity_and_swap(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        // STC/WUSDT = 1:5
        //let stc_amount: u128 = 10000 * scaling_factor;

        ////////////////////////////////////////////////////////////////////////////////////////////
        // Add liquidity, STC/WUSDT = 1:5
        let amount_stc_desired: u128 = 10 * scaling_factor;
        let amount_usdt_desired: u128 = 50 * scaling_factor;
        let amount_stc_min: u128 = 1 * scaling_factor;
        let amount_usdt_min: u128 = 1 * scaling_factor;
        TokenSwapRouter::add_liquidity<STC, WUSDT>(
            &signer,
            amount_stc_desired,
            amount_usdt_desired,
            amount_stc_min,
            amount_usdt_min
        );

        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity > amount_stc_min, 10000);

        let stc_balance = Account::balance<STC>(Signer::address_of(&signer));
        Debug::print(&stc_balance);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use StarcoinFramework::Math;
    use StarcoinFramework::STC;

    use SwapAdmin::TimelyReleaseWrapper;
    use StarcoinFramework::Debug;

    fun initalize_pool(sender: signer) {
        let scale_index: u8 = 9;
        let scaling_factor = Math::pow(10, (scale_index as u64));
        TimelyReleaseWrapper::init<STC::STC>(
            &sender,
            1000 * scaling_factor,
            86401,
            10,
            1 * scaling_factor);

        let (
            treasury_amount,
            total_treasury_amount,
            release_per_time,
            begin_time,
            latest_withdraw_time,
            interval,
            current_time_stamp,
            current_time_amount,
        ) = TimelyReleaseWrapper::query_info<STC::STC>();

        Debug::print(&treasury_amount);
        Debug::print(&total_treasury_amount);
        Debug::print(&release_per_time);
        Debug::print(&begin_time);
        Debug::print(&latest_withdraw_time);
        Debug::print(&interval);
        Debug::print(&current_time_stamp);
        Debug::print(&current_time_amount);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::STC;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;

    use SwapAdmin::TimelyReleaseWrapper;

    fun withdraw_aborted_by_not_start(sender: signer) {
        let token = TimelyReleaseWrapper::withdraw<STC::STC>();
        Account::deposit<STC::STC>(Signer::address_of(&sender), token);
    }
}
// check: MoveAbort 769025

//# block --author 0x1 --timestamp 86401000

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;

    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Token;
    use SwapAdmin::TimelyReleaseWrapper;

    fun withdraw_aborted_by_not_interval(sender: signer) {
        let token = TimelyReleaseWrapper::withdraw<STC>();
        Debug::print(&Token::value<STC>(&token));
        Account::deposit<STC>(Signer::address_of(&sender), token);
    }
}
// check: MoveAbort 512513

//# block --author 0x1 --timestamp 86410000

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;

    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Token;
    use SwapAdmin::TimelyReleaseWrapper;

    fun withdraw_succeed(sender: signer) {
        let token = TimelyReleaseWrapper::withdraw<STC>();
        let token_amount = Token::value<STC>(&token);
        Debug::print(&token_amount);
        assert!(token_amount == 1000000000, 10001);
        Account::deposit<STC>(Signer::address_of(&sender), token);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 86420000

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Token;

    use SwapAdmin::TimelyReleaseWrapper;

    fun withdraw_succeed_2(sender: signer) {
        let token = TimelyReleaseWrapper::withdraw<STC>();
        let token_amount = Token::value<STC>(&token);
        Debug::print(&token_amount);
        assert!(token_amount == 1000000000, 10002);
        Account::deposit<STC>(Signer::address_of(&sender), token);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 86425000

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Token;

    use SwapAdmin::TimelyReleaseWrapper;

    fun withdraw_aborted_by_not_interval(sender: signer) {
        let token = TimelyReleaseWrapper::withdraw<STC>();
        let token_amount = Token::value<STC>(&token);
        Debug::print(&token_amount);
        assert!(token_amount == 1000000000, 10003);
        Account::deposit<STC>(Signer::address_of(&sender), token);
    }
}
// check: MoveAbort 512513

//# run --signers alice
script {
    use StarcoinFramework::STC::STC;
    use SwapAdmin::TimelyReleaseWrapper;
    use SwapAdmin::CommonHelper;

    fun set_parameters(_sender: signer) {
        TimelyReleaseWrapper::set_release_per_seconds<STC>(CommonHelper::pow_amount<STC>(5));
        TimelyReleaseWrapper::set_interval<STC>(10000);

        let (_, _, release_per_time, _, _, interval, _, _) = TimelyReleaseWrapper::query_info<STC>();

        assert!(release_per_time == CommonHelper::pow_amount<STC>(5), 10004);
        assert!(interval == 10000, 10005);
    }
}
// check: EXECUTED