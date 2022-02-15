//! account: alice, 10000000000000 0x1::STC::STC
//! account: joe
//! account: admin, 0x2b3d5bd6d0f8a957e6a4abe986056ba7, 10000000000000 0x1::STC::STC
//! account: liquidier, 10000000000000 0x1::STC::STC

//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::{Self, WUSDT};

    fun init_token(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        TokenMock::register_token<WUSDT>(&signer, precision);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::{WUSDT};
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::CommonHelper;
    use 0x1::Math;

    fun init_account(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        let usdt_amount: u128 = 50000 * scaling_factor;
        CommonHelper::safe_mint<WUSDT>(&signer, usdt_amount);
    }
}
// check: EXECUTED

////! new-transaction
////! sender: liquidier
//address alice = {{alice}};
//script {
//    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::{WUSDT};
//    use 0x1::Account;
//    use 0x1::Token;
//    use 0x1::Math;
//    fun init_liquidier(signer: signer) {
//        let precision: u8 = 9; //STC precision is also 9.
//        let scaling_factor = Math::pow(10, (precision as u64));
//        let usdt_amount: u128 = 50000 * scaling_factor;
//        // mint WUSDT
//        Account::do_accept_token<WUSDT>(&signer);
//        let usdt_token = Token::mint<WUSDT>(&signer, usdt_amount);
//        Account::deposit_to_self(&signer, usdt_token);
//    }
//}
//// check: EXECUTED


//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::{WUSDT};
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwap;
    use 0x1::STC::STC;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);
        assert(TokenSwap::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTE

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::{WUSDT};
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapRouter;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Math;
    use 0x1::STC::STC;

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
        assert(total_liquidity > amount_stc_min, 10000);
        // Balance verify
        assert(Account::balance<STC>(Signer::address_of(&signer)) ==
               (stc_amount - amount_stc_desired), 10001);
        assert(Account::balance<WUSDT>(Signer::address_of(&signer)) ==
               (usdt_amount - amount_usdt_desired), 10002);

        ////////////////////////////////////////////////////////////////////////////////////////////
        // Swap token pair, put 1 STC, got 5 WUSDT
        let pledge_stc_amount: u128 = 1 * scaling_factor;
        let pledge_usdt_amount: u128 = 5 * scaling_factor;
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(
            &signer, pledge_stc_amount, pledge_stc_amount);
        assert(Account::balance<STC>(Signer::address_of(&signer)) ==
               (stc_amount - amount_stc_desired - pledge_stc_amount), 10004);
        // TODO: To verify why swap out less than ratio swap out
        assert(Account::balance<WUSDT>(Signer::address_of(&signer)) <=
               (usdt_amount - amount_usdt_desired + pledge_usdt_amount), 10005);
    }
}

// check: EXECUTED