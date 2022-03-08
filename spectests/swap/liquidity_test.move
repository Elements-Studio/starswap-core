//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000

//# faucet --addr SwapAdmin --amount 10000000000000

//# faucet --addr liquidier --amount 10000000000000000


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WUSDT};

    fun init_token(signer: signer) {
        TokenMock::register_token<WUSDT>(&signer, 9u8);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::CommonHelper;
    use StarcoinFramework::Math;

    fun init_account(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        let usdt_amount: u128 = 50000 * scaling_factor;
        CommonHelper::safe_mint<WUSDT>(&signer, usdt_amount);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::TokenSwap;
    use StarcoinFramework::STC::STC;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);
        assert!(TokenSwap::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Math;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::TokenSwapRouter;

    fun add_liquidity_and_swap(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        // STC/WUSDT = 1:5
        let stc_amount: u128 = 10000 * scaling_factor;
        let usdt_amount: u128 = 50000 * scaling_factor;

        ////////////////////////////////////////////////////////////////////////////////////////////
        // Add liquidity, STC/WUSDT = 1:5
        let amount_stc_desired: u128 = 10 * scaling_factor;
        let amount_usdt_desired: u128 = 50 * scaling_factor;
        let amount_stc_min: u128 = 1 * scaling_factor;
        let amount_usdt_min: u128 = 1 * scaling_factor;
        TokenSwapRouter::add_liquidity<STC, WUSDT>(&signer,
            amount_stc_desired, amount_usdt_desired, amount_stc_min, amount_usdt_min);
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity > amount_stc_min, 10000);

        // Balance verify
        Debug::print(&stc_amount);
        Debug::print(&amount_stc_desired);
        let stc_balance = Account::balance<STC>(Signer::address_of(&signer));
        Debug::print(&stc_balance);
        //gas used
        assert!(stc_balance <= (stc_amount - amount_stc_desired), 10001);

        let usdt_balance = Account::balance<WUSDT>(Signer::address_of(&signer));
        Debug::print(&usdt_amount);
        Debug::print(&amount_usdt_desired);
        Debug::print(&usdt_balance);
        assert!(usdt_balance == (usdt_amount - amount_usdt_desired), 10002);

        ////////////////////////////////////////////////////////////////////////////////////////////
        // Swap token pair, put 1 STC, got 5 WUSDT
        let pledge_stc_amount: u128 = 1 * scaling_factor;
        let pledge_usdt_amount: u128 = 5 * scaling_factor;
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(
            &signer, pledge_stc_amount, pledge_stc_amount);
        assert!(Account::balance<STC>(Signer::address_of(&signer)) <=
                (stc_amount - amount_stc_desired - pledge_stc_amount), 10004);
        assert!(Account::balance<WUSDT>(Signer::address_of(&signer)) <=
                (usdt_amount - amount_usdt_desired + pledge_usdt_amount), 10005);
    }
}
// check: EXECUTED