//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5


//# faucet --addr exchanger

//# faucet --addr alice

//# faucet --addr SwapAdmin


//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenMock::{Self, WUSDT};

    fun init_token(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        TokenMock::register_token<WUSDT>(&signer, precision);
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


//TODO support mint for another account test
//# run --signers exchanger

script {
    use SwapAdmin::TokenMock::{WUSDT};
    use StarcoinFramework::Account;
    fun init_exchanger(signer: signer) {
        Account::do_accept_token<WUSDT>(&signer);
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

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenMock::WETH;
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;

    fun register_another_token(signer: signer) {
        Token::register_token<WETH>(&signer, 6);
        Account::do_accept_token<WETH>(&signer);
        let old_market_cap = Token::market_cap<WETH>();
        assert!(old_market_cap == 0, 8001);
        let token = Token::mint<WETH>(&signer, 10000);
        assert!(Token::value<WETH>(&token) == 10000, 8000);
        assert!(Token::market_cap<WETH>() == old_market_cap + 10000, 8001);
        let sender_address = Signer::address_of(&signer);
        Account::deposit(sender_address, token);
        assert!(Account::balance<WETH>(sender_address) == 10000, 8003);
    }
}

// check: EXECUTED


//# run --signers alice

script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC;
    use SwapAdmin::TokenMock;

    fun add_liquidity(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC::STC, TokenMock::WUSDT>(&signer, 10000, 10000 * 10000, 10, 10);
        let total_liquidity = TokenSwapRouter::total_liquidity<STC::STC, TokenMock::WUSDT>();
        assert!(total_liquidity == 1000000 - 1000, (total_liquidity as u64));
        TokenSwapRouter::add_liquidity<STC::STC, TokenMock::WUSDT>(&signer, 10000, 10000 * 10000, 10, 10);
        let total_liquidity = TokenSwapRouter::total_liquidity<STC::STC, TokenMock::WUSDT>();
        assert!(total_liquidity == (1000000 - 1000) * 2, (total_liquidity as u64));
    }
}
// check: EXECUTED

//# run --signers alice

script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC;
    use SwapAdmin::TokenMock;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;

    fun remove_liquidity(signer: signer) {
        TokenSwapRouter::remove_liquidity<STC::STC, TokenMock::WUSDT>(&signer, 10000, 10, 10);
        let _token_balance = Account::balance<TokenMock::WUSDT>(Signer::address_of(&signer));
        let expected = (10000 * 10000) * 2 * 10000 / ((1000000 - 1000) * 2);
        //assert!(token_balance == expected, (token_balance as u64));

        //let y = to_burn_value * y_reserve / total_supply;
        let (stc_reserve, usdt_reserve) = TokenSwapRouter::get_reserves<STC::STC, TokenMock::WUSDT>();
        assert!(stc_reserve == 10000 * 2 - 10000 * 2 * 10000 / ((1000000 - 1000) * 2), (stc_reserve as u64));
        assert!(usdt_reserve == 10000 * 10000 * 2 - expected, (usdt_reserve as u64));
    }
}
// check: EXECUTED


//# run --signers exchanger

script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC;
    use SwapAdmin::TokenMock;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;

    fun swap_exact_token_for_token(signer: signer) {
        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC::STC, TokenMock::WUSDT>();
        let (stc_reserve, token_reserve) = TokenSwapRouter::get_reserves<STC::STC, TokenMock::WUSDT>();
        Debug::print<u128>(&stc_reserve);
        Debug::print<u128>(&token_reserve);
        TokenSwapRouter::swap_exact_token_for_token<STC::STC, TokenMock::WUSDT>(&signer, 1000, 0);
        let token_balance = Account::balance<TokenMock::WUSDT>(Signer::address_of(&signer));
        let expected_token_balance = TokenSwapLibrary::get_amount_out(1000, stc_reserve, token_reserve, fee_numberator, fee_denumerator);
        Debug::print<u128>(&token_balance);
        assert!(token_balance == expected_token_balance, (token_balance as u64));
    }
}
// check: EXECUTED

//# run --signers exchanger

script {
    use StarcoinFramework::STC;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;

    fun swap_token_for_exact_token(signer: signer) {
        let stc_balance_before = Account::balance<STC::STC>(Signer::address_of(&signer));
        let (stc_reserve, token_reserve) = TokenSwapRouter::get_reserves<STC::STC, TokenMock::WUSDT>();
        TokenSwapRouter::swap_token_for_exact_token<STC::STC, TokenMock::WUSDT>(&signer, 30, 100000);
        let stc_balance_after = Account::balance<STC::STC>(Signer::address_of(&signer));

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC::STC, TokenMock::WUSDT>();
        let expected_balance_change = TokenSwapLibrary::get_amount_in(100000, stc_reserve, token_reserve, fee_numberator, fee_denumerator);
        assert!(stc_balance_before - stc_balance_after == expected_balance_change, (expected_balance_change as u64));
    }
}
// check: EXECUTED


//# run --signers exchanger

script {
    use StarcoinFramework::STC;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock;
    use StarcoinFramework::Debug;

    fun get_reserves(_: signer) {
        let (stc_reserve, token_reserve) = TokenSwapRouter::get_reserves<STC::STC, TokenMock::WUSDT>();
        Debug::print(&100100);
        Debug::print(&stc_reserve);
        Debug::print(&token_reserve);
        let (token_reserve_2, stc_reserve_2) = TokenSwapRouter::get_reserves<TokenMock::WUSDT, STC::STC>();
        Debug::print(&token_reserve_2);
        Debug::print(&stc_reserve_2);
        assert!(stc_reserve == stc_reserve_2, 1112);
        assert!(token_reserve == token_reserve_2, 1112);
    }
}
// check: EXECUTED
