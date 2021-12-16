//! account: admin, 0x4783d08fb16990bd35d83f3e23bf93b8, 10000 0x1::STC::STC
//! account: exchanger, 10000000000000 0x1::STC::STC
//! account: alice, 10000000000000 0x1::STC::STC
//! account: feetokenholder, 0x2d81a0427d64ff61b11ede9085efa5ad, 400000 0x1::STC::STC
//! account: feeadmin, 0xd231d9da8e37fc3d9ff3f576cf978535


//! new-transaction
//! sender: feetokenholder
address alice = {{alice}};
script {
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;
    use 0x1::Token;
    use 0x1::Account;

    fun fee_token_init(signer: signer) {
        Token::register_token<XUSDT>(&signer, 9);
        Account::do_accept_token<XUSDT>(&signer);
        let token = Token::mint<XUSDT>(&signer, 500000u128);
        Account::deposit_to_self(&signer, token);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    fun accept_token(signer: signer) {
        Account::do_accept_token<XUSDT>(&signer);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: feeadmin
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    fun accept_token(signer: signer) {
        Account::do_accept_token<XUSDT>(&signer);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: feetokenholder
address alice = {{alice}};
address exchanger = {{exchanger}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    fun transfer(signer: signer) {
        CommonHelper::transfer<XUSDT>(&signer, @alice, 300000u128);
    }
}

// check: EXECUTED


//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwap;
    use 0x1::STC::STC;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwap::register_swap_pair<STC, XUSDT>(&signer);
        assert(TokenSwap::swap_pair_exists<STC, XUSDT>(), 111);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x1::STC::STC;
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    fun add_liquidity(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC, XUSDT>(&signer, 200000, 50000, 10, 10);
        let total_liquidity = TokenSwapRouter::total_liquidity<STC, XUSDT>();
        assert(total_liquidity > 0, (total_liquidity as u64));
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x1::STC::STC;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Debug;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

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


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;

    use 0x1::STC::STC;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Debug;
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

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

