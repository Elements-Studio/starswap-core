//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5 --public-keys Bridge=0x8085e172ecf785692da465ba3339da46c4b43640c3f92a45db803690cc3c4a36 --public-keys SwapFeeAdmin=0xbf76b7fc68b3344e63512fd6b4ded611e6910fc9df1b9f858cb6bf571e201e2d

//# faucet --addr Bridge --amount 10000000000000000

//# faucet --addr SwapFeeAdmin --amount 10000000000000000

//# faucet --addr exchanger --amount 10000000000000000

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000


//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenMock::{Self, WETH, WUSDT, WDAI, WBTC};

    fun init_token(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 18u8);
        TokenMock::register_token<WUSDT>(&signer, 18u8);
        TokenMock::register_token<WDAI>(&signer, 18u8);
        TokenMock::register_token<WBTC>(&signer, 9u8);
    }
}
// check: EXECUTED


//# run --signers alice

script {
    use SwapAdmin::TokenMock::{WETH, WUSDT, WDAI, WBTC};
    use SwapAdmin::CommonHelper;

    fun init_account(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 600000u128);
        CommonHelper::safe_mint<WUSDT>(&signer, 500000u128);
        CommonHelper::safe_mint<WDAI>(&signer, 200000u128);
        CommonHelper::safe_mint<WBTC>(&signer, 100000u128);
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

//# run --signers exchanger

script {
    use SwapAdmin::TokenMock::{WETH};
    use StarcoinFramework::Account;

    fun accept_token(signer: signer) {
        Account::do_accept_token<WETH>(&signer);
    }
}
// check: EXECUTED

//# run --signers SwapFeeAdmin

script {
    use StarcoinFramework::Account;
    use Bridge::XUSDT::XUSDT;

    fun accept_token(signer: signer) {
        Account::do_accept_token<XUSDT>(&signer);
    }
}
// check: EXECUTED

//# run --signers alice


script {
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::CommonHelper;

    fun transfer(signer: signer) {
        CommonHelper::transfer<WETH>(&signer, @exchanger, 100000u128);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenMock::{WETH, WUSDT, WDAI, WBTC};
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC::STC;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<WETH, WUSDT>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<WETH, WUSDT>(), 111);

        TokenSwapRouter::register_swap_pair<WUSDT, WDAI>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<WUSDT, WDAI>(), 112);

        TokenSwapRouter::register_swap_pair<WDAI, WBTC>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<WDAI, WBTC>(), 113);

        TokenSwapRouter::register_swap_pair<STC, WETH>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<STC, WETH>(), 114);

        TokenSwapRouter::register_swap_pair<WBTC, WETH>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<WBTC, WETH>(), 115);
    }
}

// check: EXECUTED


//# run --signers alice

script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC::STC;
    use SwapAdmin::TokenMock::{WETH, WUSDT, WDAI, WBTC};

    fun add_liquidity(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<WETH, WUSDT>(&signer, 5000, 100000, 100, 100);
        TokenSwapRouter::add_liquidity<WUSDT, WDAI>(&signer, 20000, 30000, 100, 100);
        TokenSwapRouter::add_liquidity<WDAI, WBTC>(&signer, 100000, 4000, 100, 100);
        TokenSwapRouter::add_liquidity<STC, WETH>(&signer, 200000, 10000, 100, 100);
        TokenSwapRouter::add_liquidity<WETH, WBTC>(&signer, 60000, 5000, 100, 100);
    }
}

// check: EXECUTED


//# run --signers exchanger

script {
    use SwapAdmin::TokenSwapRouter3;
    use SwapAdmin::TokenMock::{WETH, WDOT, WBTC, WDAI};

    fun swap_pair_not_exist(signer: signer) {
        let amount_x_in = 200;
        let amount_y_out_min = 500;
        TokenSwapRouter3::swap_exact_token_for_token<WETH, WBTC, WDOT, WDAI>(&signer, amount_x_in, amount_y_out_min);
    }
}
// when swap router dost not exist, swap encounter failure
// check: EXECUTION_FAILURE
// check: MISSING_DATA


//# run --signers exchanger

script {
    // use SwapAdmin::TokenSwapRouter;
    // use SwapAdmin::TokenMock::{WETH};

    use SwapAdmin::TokenSwapRouter3;
    use StarcoinFramework::STC::STC;
    use SwapAdmin::TokenMock::{WETH, WUSDT, WDAI};

    use SwapAdmin::CommonHelper;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    fun swap_exact_token_for_token(signer: signer) {
        let amount_x_in = 15000;
        let amount_y_out_min = 10;
        let token_balance = CommonHelper::get_safe_balance<WDAI>(Signer::address_of(&signer));
        assert!(token_balance == 0, 201);

        let (r_out, t_out, expected_token_balance) = TokenSwapRouter3::get_amount_out<STC, WETH, WUSDT, WDAI>(amount_x_in);
        TokenSwapRouter3::swap_exact_token_for_token<STC, WETH, WUSDT, WDAI>(&signer, amount_x_in, amount_y_out_min);

        // TokenSwapRouter::swap_exact_token_for_token<STC, WETH>(&signer, amount_x_in, r_out);
        // TokenSwapRouter::swap_exact_token_for_token<WETH, WUSDT>(&signer, r_out, t_out);
        // TokenSwapRouter::swap_exact_token_for_token<WUSDT, WDAI>(&signer, t_out, amount_y_out_min);

        let token_balance = CommonHelper::get_safe_balance<WDAI>(Signer::address_of(&signer));
        Debug::print<u128>(&r_out);
        Debug::print<u128>(&t_out);
        Debug::print<u128>(&token_balance);

        Debug::print<u128>(&amount_y_out_min);
        Debug::print<u128>(&expected_token_balance);
        assert!(token_balance == expected_token_balance, (token_balance as u64));
        assert!(token_balance >= amount_y_out_min, (token_balance as u64));
    }
}

// check: EXECUTED


//# run --signers exchanger

script {
//    use SwapAdmin::TokenSwapRouter;
    // use SwapAdmin::TokenMock::{WETH};

    use SwapAdmin::TokenSwapRouter3;
    use SwapAdmin::TokenMock::{WETH, WUSDT, WDAI, WBTC};

    use SwapAdmin::CommonHelper;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    fun swap_token_for_exact_token(signer: signer) {
        let amount_x_in_max = 30000;
        let amount_y_out = 200;
        let token_balance = CommonHelper::get_safe_balance<WBTC>(Signer::address_of(&signer));
        assert!(token_balance == 0, 201);

        let (t_in, r_in, x_in) = TokenSwapRouter3::get_amount_in<WETH, WUSDT, WDAI, WBTC>(amount_y_out);
        TokenSwapRouter3::swap_token_for_exact_token<WETH, WUSDT, WDAI, WBTC>(&signer, amount_x_in_max, amount_y_out);

        // TokenSwapRouter::swap_token_for_exact_token<WETH, WUSDT>(&signer, amount_x_in_max, r_in);
        // TokenSwapRouter::swap_token_for_exact_token<WUSDT, WDAI>(&signer, r_in, t_in);
        // TokenSwapRouter::swap_token_for_exact_token<WDAI, WBTC>(&signer, t_in, amount_y_out);

        let token_balance = CommonHelper::get_safe_balance<WBTC>(Signer::address_of(&signer));
        Debug::print<u128>(&x_in);
        Debug::print<u128>(&r_in);
        Debug::print<u128>(&t_in);
        Debug::print<u128>(&token_balance);
        Debug::print<u128>(&amount_x_in_max);
        assert!(token_balance == amount_y_out, (token_balance as u64));
        assert!(x_in <= amount_x_in_max, (token_balance as u64));
    }
}

// check: EXECUTED