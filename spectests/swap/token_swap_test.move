//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice

//# faucet --addr joe

//# faucet --addr SwapAdmin

//# faucet --addr liquidier

//# faucet --addr exchanger



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

script{
    use StarcoinFramework::STC;
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwap::LiquidityToken;
    use StarcoinFramework::Account;

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
        assert!(x == stc_amount, 111);
        assert!(y == usdt_amount, 112);
    }
}
// check: EXECUTED

//# run --signers alice

script {
    use StarcoinFramework::STC;
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;
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

//# run --signers alice

script{
    use StarcoinFramework::STC;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwap::LiquidityToken;
    // use StarcoinFramework::Debug;

    fun main(signer: signer) {
        let liquidity_balance = Account::balance<LiquidityToken<STC::STC, TokenMock::WUSDT>>(Signer::address_of( &signer));
        let liquidity = Account::withdraw<LiquidityToken<STC::STC, TokenMock::WUSDT>>( &signer, liquidity_balance);
        let (stc, usdx) = TokenSwap::burn<STC::STC, TokenMock::WUSDT>(liquidity);
        Account::deposit_to_self(&signer, stc);
        Account::deposit_to_self(&signer, usdx);

        let (x, y) = TokenSwap::get_reserves<STC::STC, TokenMock::WUSDT>();
        assert!(x == 0, 111);
        assert!(y == 0, 112);
    }
}
// check: EXECUTED
