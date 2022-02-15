//! account: alice, 10000000000000 0x1::STC::STC
//! account: joe
//! account: admin, 0x2b3d5bd6d0f8a957e6a4abe986056ba7, 10000000000000 0x1::STC::STC
//! account: liquidier, 10000000000000 0x1::STC::STC
//! account: exchanger


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
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script{
    use 0x1::STC;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwap;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwap::LiquidityToken;
    use 0x1::Account;

    fun main(signer: signer) {
        Account::do_accept_token<LiquidityToken<STC::STC, TokenMock::WUSDT>>(&signer);
        // STC/WUSDT = 1:2
        let stc_amount = 10000;
        let usdt_amount = 20000;
        let stc = Account::withdraw<STC::STC>( &signer, stc_amount);
        let usdx = Account::withdraw<TokenMock::WUSDT>( &signer, usdt_amount);
        let liquidity_token = TokenSwap::mint<STC::STC, TokenMock::WUSDT>(stc, usdx);
        Account::deposit_to_self( &signer, liquidity_token);

        let (x, y) = TokenSwap::get_reserves<STC::STC, TokenMock::WUSDT>();
        assert(x == stc_amount, 111);
        assert(y == usdt_amount, 112);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::STC;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwap;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapLibrary;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapConfig;
    use 0x1::Account;
    use 0x1::Token;
    fun main(signer: signer) {
        let stc_amount = 100000;
        let stc = Account::withdraw<STC::STC>( &signer, stc_amount);

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC::STC, TokenMock::WUSDT>();
        let (x, y) = TokenSwap::get_reserves<STC::STC, TokenMock::WUSDT>();
        let amount_out = TokenSwapLibrary::get_amount_out(stc_amount, x, y, fee_numberator, fee_denumerator);
        let (stc_token, usdt_token, stc_fee, usdt_fee) = TokenSwap::swap<STC::STC, TokenMock::WUSDT>(stc, amount_out, Token::zero<TokenMock::WUSDT>(), 0);
        Token::destroy_zero(stc_token);
        Account::deposit_to_self(&signer, usdt_token);
        Token::destroy_zero(usdt_fee);
        Account::deposit_to_self(&signer, stc_fee);
    }
}

// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script{
    use 0x1::STC;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwap;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwap::LiquidityToken;
    // use 0x1::Debug;

    fun main(signer: signer) {
        let liquidity_balance = Account::balance<LiquidityToken<STC::STC, TokenMock::WUSDT>>(Signer::address_of( &signer));
        let liquidity = Account::withdraw<LiquidityToken<STC::STC, TokenMock::WUSDT>>( &signer, liquidity_balance);
        let (stc, usdx) = TokenSwap::burn<STC::STC, TokenMock::WUSDT>(liquidity);
        Account::deposit_to_self(&signer, stc);
        Account::deposit_to_self(&signer, usdx);

        let (x, y) = TokenSwap::get_reserves<STC::STC, TokenMock::WUSDT>();
        assert(x == 0, 111);
        assert(y == 0, 112);
    }
}
// check: EXECUTED
