//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr SwapAdmin

//# faucet --addr exchanger

//# faucet --addr alice

//# faucet --addr feetokenholder

//# faucet --addr feeadmin



//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapFee;

    fun init_token_swap_fee(signer: signer) {
        TokenSwapFee::initialize_token_swap_fee(&signer);
    }
}
// check: EXECUTED

//# run --signers feetokenholder

script {
    use Bridge::XUSDT::XUSDT;
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;

    fun fee_token_init(signer: signer) {
        Token::register_token<XUSDT>(&signer, 9);
        Account::do_accept_token<XUSDT>(&signer);
        let token = Token::mint<XUSDT>(&signer, 500000u128);
        Account::deposit_to_self(&signer, token);
    }
}
// check: EXECUTED

//# run --signers alice

script {
    use StarcoinFramework::Account;
    use Bridge::XUSDT::XUSDT;

    fun accept_token(signer: signer) {
        Account::do_accept_token<XUSDT>(&signer);
    }
}
// check: EXECUTED


//# run --signers feeadmin

script {
    use StarcoinFramework::Account;
    use Bridge::XUSDT::XUSDT;

    fun accept_token(signer: signer) {
        Account::do_accept_token<XUSDT>(&signer);
    }
}
// check: EXECUTED


//# run --signers feetokenholder


script {
    use SwapAdmin::CommonHelper;
    use Bridge::XUSDT::XUSDT;

    fun transfer(signer: signer) {
        CommonHelper::transfer<XUSDT>(&signer, @alice, 300000u128);
    }
}

// check: EXECUTED


//# run --signers SwapAdmin

script {
    use Bridge::XUSDT::XUSDT;
    use SwapAdmin::TokenSwap;
    use StarcoinFramework::STC::STC;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwap::register_swap_pair<STC, XUSDT>(&signer);
        assert(TokenSwap::swap_pair_exists<STC, XUSDT>(), 111);
    }
}
// check: EXECUTED


//# run --signers alice

script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC::STC;
    use Bridge::XUSDT::XUSDT;

    fun add_liquidity(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC, XUSDT>(&signer, 200000, 50000, 10, 10);
        let total_liquidity = TokenSwapRouter::total_liquidity<STC, XUSDT>();
        assert(total_liquidity > 0, (total_liquidity as u64));
    }
}
// check: EXECUTED


//# run --signers alice

script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;
    use Bridge::XUSDT::XUSDT;

    fun swap_exact_token_for_token(signer: signer) {

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, XUSDT>();
        let (stc_reserve, token_reserve) = TokenSwapRouter::get_reserves<STC, XUSDT>();
        Debug::print<u128>(&stc_reserve);
        Debug::print<u128>(&token_reserve);
        let token_balance_start = Account::balance<XUSDT>(Signer::address_of(&signer));
        TokenSwapRouter::swap_exact_token_for_token<STC, XUSDT>(&signer, 20000, 1000);
        let token_balance_end = Account::balance<XUSDT>(Signer::address_of(&signer));
        let expected_token_balance = TokenSwapLibrary::get_amount_out(20000, stc_reserve, token_reserve, fee_numberator, fee_denumerator);
        Debug::print<u128>(&token_balance_start);
        Debug::print<u128>(&token_balance_end);
        let token_balance_change = token_balance_end - token_balance_start;
        assert(token_balance_change == expected_token_balance, (token_balance_change as u64));
    }
}
// check: EXECUTED


//# run --signers alice

script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;

    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use Bridge::XUSDT::XUSDT;

    fun swap_exact_token_for_token(signer: signer) {

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<XUSDT, STC>();
        let (token_reserve, stc_reserve) = TokenSwapRouter::get_reserves<XUSDT, STC>();
        Debug::print<u128>(&stc_reserve);
        Debug::print<u128>(&token_reserve);
        let token_balance_start = Account::balance<XUSDT>(Signer::address_of(&signer));
        TokenSwapRouter::swap_exact_token_for_token<XUSDT, STC>(&signer, 10000, 20000);
        let token_balance_end = Account::balance<XUSDT>(Signer::address_of(&signer));
        let expected_token_balance = TokenSwapLibrary::get_amount_out(10000, token_reserve, stc_reserve, fee_numberator, fee_denumerator);
        Debug::print<u128>(&token_balance_start);
        Debug::print<u128>(&token_balance_end);
        let token_balance_change = token_balance_start - token_balance_end;
        Debug::print<u128>(&token_balance_change);
        Debug::print<u128>(&expected_token_balance);
    }
}
// check: EXECUTED

