//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5 --public-keys Bridge=0x57e74d84273e190d80e736c0fd82e0f6a00fb3f93ff2a8a95d1f3ad480da36ce

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# faucet --addr liquidier --amount 10000000000000000

//# faucet --addr Bridge --amount 10000000000000000


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WETH, WDAI, WDOT, WBTC};

    fun init_token(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 18);
        TokenMock::register_token<WDAI>(&signer, 18);
        TokenMock::register_token<WBTC>(&signer, 18);
        TokenMock::register_token<WDOT>(&signer, 9);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenMock::{WETH, WDAI, WDOT, WBTC};
    use SwapAdmin::CommonHelper;
    use StarcoinFramework::Math;

    fun init_account(signer: signer) {
        let scaling_factor_9 = Math::pow(10, 9);
        let scaling_factor_18 = Math::pow(10, 18);
        CommonHelper::safe_mint<WETH>(&signer, 10000 * scaling_factor_18);
        CommonHelper::safe_mint<WDAI>(&signer, 600000 * scaling_factor_18);
        CommonHelper::safe_mint<WDOT>(&signer, 600000 * scaling_factor_9);
        CommonHelper::safe_mint<WBTC>(&signer, 60000 * scaling_factor_18);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapFee;

    fun init_token_swap_fee(signer: signer) {
        TokenSwapFee::initialize_token_swap_fee(&signer);
    }
}
// check: EXECUTED


//# run --signers Bridge
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

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{WETH, WDAI, WDOT, WBTC};
    use SwapAdmin::TokenSwap;
    use StarcoinFramework::STC::STC;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwap::register_swap_pair<STC, WETH>(&signer);
        TokenSwap::register_swap_pair<WETH, WDAI>(&signer);
        TokenSwap::register_swap_pair<WBTC, STC>(&signer);
        TokenSwap::register_swap_pair<STC, WDOT>(&signer);

    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Math;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WDOT};

    fun add_liquidity_precision_9(signer: signer) {
        let scaling_factor_9 = Math::pow(10, 9);
        Debug::print(&200200);
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC, WDOT>(&signer, 2000000, 50000000, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<STC, WDOT>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<STC, WDOT>(&signer, 20 * scaling_factor_9, 5 * scaling_factor_9, 10, 10);

        let liquidity = TokenSwapRouter::liquidity<STC, WDOT>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<STC, WDOT>(&signer, 20000 * scaling_factor_9, 5000 * scaling_factor_9, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<STC, WDOT>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<STC, WDOT>(&signer, 600000 * scaling_factor_9, 8000 * scaling_factor_9, 10, 10);

        let liquidity = TokenSwapRouter::liquidity<STC, WDOT>(Signer::address_of(&signer));
        Debug::print(&liquidity);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC::STC;
    use SwapAdmin::TokenMock::{WETH};
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Math;

    fun add_liquidity(signer: signer) {
        let scaling_factor_9 = Math::pow(10, 9);
        let scaling_factor_18 = Math::pow(10, 18);
        Debug::print(&200300);
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC, WETH>(&signer, 20000000, 50000000, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<STC, WETH>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<STC, WETH>(&signer, 20 * scaling_factor_9, 5000000000000000, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<STC, WETH>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<STC, WETH>(&signer, 20000 * scaling_factor_9, 50 * scaling_factor_18, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<STC, WETH>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<STC, WETH>(&signer, 600000 * scaling_factor_9, 8000 * scaling_factor_18, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<STC, WETH>(Signer::address_of(&signer));
        Debug::print(&liquidity);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WETH, WDAI};
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Math;

    fun add_liquidity_precesion_18(signer: signer) {
        let scaling_factor_18 = Math::pow(10, 18);
        Debug::print(&200500);
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<WETH, WDAI>(&signer, 20000000, 50000000, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<WETH, WDAI>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<WETH, WDAI>(&signer, 20000000000000, 5000000000000000, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<WETH, WDAI>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<WETH, WDAI>(&signer, 50 * scaling_factor_18, 2000 * scaling_factor_18, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<WETH, WDAI>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<WETH, WDAI>(&signer, 8000 * scaling_factor_18, 400000 * scaling_factor_18, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<WETH, WDAI>(Signer::address_of(&signer));
        Debug::print(&liquidity);
    }
}
// check: EXECUTED


//# run --signers alice


script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC::STC;
    use SwapAdmin::TokenMock::{WBTC};
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Account;

    fun add_and_remove_liquidity(signer: signer) {
        Debug::print(&200600);
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC, WBTC>(&signer, 20000000000000, 1123456789987654321, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<STC, WBTC>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        let btc_balance = Account::balance<WBTC>(Signer::address_of(&signer));

        TokenSwapRouter::remove_liquidity<STC, WBTC>(&signer, liquidity, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<STC, WBTC>(Signer::address_of(&signer));
        Debug::print(&liquidity);
        let btc_balance_2 = Account::balance<WBTC>(Signer::address_of(&signer));

        Debug::print(&(btc_balance_2 - btc_balance));
        assert!((btc_balance_2 - btc_balance) == 1123456789987654321, 2002);
    }
}
// check: EXECUTED