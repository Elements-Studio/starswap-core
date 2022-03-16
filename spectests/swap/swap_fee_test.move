//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5 Bridge=0xa0b9394a752f51b1a7956950c67a84ec1d0e627ef4e44cadef3aedbd53f8bc35 SwapFeeAdmin=0xbf76b7fc68b3344e63512fd6b4ded611e6910fc9df1b9f858cb6bf571e201e2d --addresses SwapFeeAdmin=0x9572abb16f9d9e9b009cc1751727129e

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr exchanger --amount 10000000000000000

//# faucet --addr SwapFeeAdmin --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# faucet --addr Bridge --amount 10000000000000000


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WETH, WUSDT, WDAI};

    fun token_init(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 18u8);
        TokenMock::register_token<WUSDT>(&signer, 18u8);
        TokenMock::register_token<WDAI>(&signer, 18u8);
    }
}

// check: EXECUTED

//# run --signers alice

script {
    use SwapAdmin::TokenMock::{WETH, WUSDT, WDAI};
    use SwapAdmin::CommonHelper;

    fun init_account(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 600000u128);
        CommonHelper::safe_mint<WUSDT>(&signer, 500000u128);
        CommonHelper::safe_mint<WDAI>(&signer, 200000u128);
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


//# run --signers alice

script {
    use StarcoinFramework::Account;
    use Bridge::XUSDT::XUSDT;

    fun accept_token(signer: signer) {
        Account::do_accept_token<XUSDT>(&signer);
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


//# run --signers exchanger
script {
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::CommonHelper;

    fun transfer(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 100000u128);
    }
}

// check: EXECUTED


//# run --signers Bridge
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
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC::STC;
    use Bridge::XUSDT::XUSDT;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<WETH, WUSDT>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<WETH, WUSDT>(), 111);

        TokenSwapRouter::register_swap_pair<STC, WETH>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<STC, WETH>(), 112);

        TokenSwapRouter::register_swap_pair<STC, XUSDT>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<STC, XUSDT>(), 113);
    }
}

// check: EXECUTED



//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapRouter;

    fun open_swap_fee_auto_convert_switch(signer: signer) {
        TokenSwapRouter::set_fee_auto_convert_switch(&signer, true);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::STC::STC;
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use Bridge::XUSDT::XUSDT;

    fun add_liquidity(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<WETH, WUSDT>(&signer, 100000, 200000, 100, 100);
        TokenSwapRouter::add_liquidity<STC, WETH>(&signer, 100000, 30000, 100, 100);

        TokenSwapRouter::add_liquidity<STC, XUSDT>(&signer, 200000, 50000, 100, 100);
    }
}

// check: EXECUTED


//# run --signers exchanger
script {
    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;
    use StarcoinFramework::STC::STC;
    use SwapAdmin::TokenMock::{WETH};
    use Bridge::XUSDT::XUSDT;

    use SwapAdmin::CommonHelper;
    use SwapAdmin::SafeMath;
    use StarcoinFramework::Debug;

    fun swap_exact_token_for_token_swap(signer: signer) {
        let amount_x_in = 20000;
        let amount_y_out_min = 10;
        let fee_balance_before = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);

        TokenSwapRouter::swap_exact_token_for_token<STC, WETH>(&signer, amount_x_in, amount_y_out_min);
        let (actual_fee_operation_numerator, actual_fee_operation_denominator) = TokenSwap::cacl_actual_swap_fee_operation_rate<STC, WETH>();
        let swap_fee = SafeMath::safe_mul_div_u128(amount_x_in, actual_fee_operation_numerator, actual_fee_operation_denominator);

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, XUSDT>();
        let (reserve_x, reserve_fee) = TokenSwapRouter::get_reserves<STC, XUSDT>();
        let fee_out = TokenSwapLibrary::get_amount_out(swap_fee, reserve_x, reserve_fee, fee_numberator, fee_denumerator);
        let fee_balance_after = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);

        let fee_balance_change = fee_balance_after - fee_balance_before;
        Debug::print<u128>(&110100);
        Debug::print<u128>(&swap_fee);
        Debug::print<u128>(&fee_out);
        Debug::print<u128>(&fee_balance_change);
        Debug::print<u128>(&fee_balance_after);
        Debug::print(&@SwapFeeAdmin);
        assert!(fee_balance_change == fee_out, 201);
        assert!(fee_balance_change >= 0, 202);
    }
}
//the case: token pay for fee and fee token pair exist
//check: EXECUTED


//# run --signers exchanger
script {
    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;

    use StarcoinFramework::STC::STC;
    use SwapAdmin::TokenMock::{WETH};
    use Bridge::XUSDT::XUSDT;

    use SwapAdmin::CommonHelper;
    use SwapAdmin::SafeMath;
    use StarcoinFramework::Debug;

    fun swap_token_for_exact_token_swap(signer: signer) {
        let amount_x_in_max = 30000;
        let amount_y_out = 3200;
        let fee_balance_start = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);

        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WETH>();
        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, WETH>();
        let x_in = TokenSwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y, fee_numberator, fee_denumerator);
        TokenSwapRouter::swap_token_for_exact_token<STC, WETH>(&signer, amount_x_in_max, amount_y_out);

        let (actual_fee_operation_numerator, actual_fee_operation_denominator) = TokenSwap::cacl_actual_swap_fee_operation_rate<STC, WETH>();
        let swap_fee = SafeMath::safe_mul_div_u128(x_in, actual_fee_operation_numerator, actual_fee_operation_denominator);

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, XUSDT>();
        let (reserve_x, reserve_fee) = TokenSwapRouter::get_reserves<STC, XUSDT>();
        let fee_out = TokenSwapLibrary::get_amount_out(swap_fee, reserve_x, reserve_fee, fee_numberator, fee_denumerator);
        let fee_balance_end = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);
        let fee_balance_change = fee_balance_end - fee_balance_start;

        Debug::print<u128>(&110200);
        Debug::print<u128>(&x_in);
        Debug::print<u128>(&swap_fee);
        Debug::print<u128>(&reserve_fee);
        Debug::print<u128>(&fee_out);
        Debug::print<u128>(&fee_balance_change);
        assert!(fee_balance_change == fee_out, 205);
        assert!(fee_balance_change >= 0, 206);
    }
}
//the case: token pay for fee and fee token pair exist
// check: EXECUTED



//# run --signers exchanger


script {
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use Bridge::XUSDT::XUSDT;

    use SwapAdmin::CommonHelper;
    use SwapAdmin::SafeMath;

    fun pay_for_token_and_fee_token_pair_not_exist(signer: signer) {
        let amount_x_in = 10000;
        let amount_y_out_min = 10;
        let fee_balance_start = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<WUSDT, WETH>();
        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<WUSDT, WETH>();
        let y_out = TokenSwapLibrary::get_amount_out(amount_x_in, reserve_x, reserve_y, fee_numberator, fee_denumerator);
        TokenSwapRouter::swap_exact_token_for_token<WETH, WUSDT>(&signer, amount_x_in, amount_y_out_min);
        let (actual_fee_operation_numerator, actual_fee_operation_denominator) = TokenSwap::cacl_actual_swap_fee_operation_rate<WETH, WUSDT>();
        let swap_fee = SafeMath::safe_mul_div_u128(amount_x_in, actual_fee_operation_numerator, actual_fee_operation_denominator);

        let fee_balance_end = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);
        let fee_balance_change = fee_balance_end - fee_balance_start;

        Debug::print<u128>(&110300);
        Debug::print<u128>(&amount_y_out_min);
        Debug::print<u128>(&y_out);
        Debug::print<u128>(&swap_fee);
        Debug::print<u128>(&fee_balance_change);
        assert!(fee_balance_change == 0, 210);
    }
}
//the case: token pay for fee and fee token pair not exist
// check: EXECUTED


//# run --signers exchanger


script {
    use StarcoinFramework::STC::STC;
    
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenMock::{WETH};

    use SwapAdmin::SafeMath;
    use StarcoinFramework::Debug;

    /// two way to calculate swap fee and compare
    fun swap_exact_token_for_token_swap_fee_calculate(_: signer) {
        let amount_x_in = 20507;
//        let amount_y_out_min = 10;
        let swap_fee = SafeMath::safe_mul_div_u128(amount_x_in, 3, 1000);
        let amountx_x_in_2 = amount_x_in - swap_fee;

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, WETH>();
        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WETH>();
        let y_out = TokenSwapLibrary::get_amount_out(amount_x_in, reserve_x, reserve_y, fee_numberator, fee_denumerator);
        let y_out_2 = TokenSwapLibrary::get_amount_out_without_fee(amountx_x_in_2, reserve_x, reserve_y);

        Debug::print<u128>(&110400);
        Debug::print<u128>(&swap_fee);
        Debug::print<u128>(&y_out);
        Debug::print<u128>(&y_out_2);
        assert!(y_out == y_out_2, 215);
    }
}
//the case: token pay for fee and fee token pair exist
// check: EXECUTED


//# run --signers exchanger


script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::STC::STC;

    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::SafeMath;

    fun swap_token_for_exact_token_swap_fee_calculate(_: signer) {
//        let amount_x_in_max = 8000;
        let amount_y_out = 1299;

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, WETH>();
        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WETH>();
        let x_in = TokenSwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y, fee_numberator, fee_denumerator);
        let x_in_without_fee = TokenSwapLibrary::get_amount_in_without_fee(amount_y_out, reserve_x, reserve_y);
        let swap_fee = x_in - x_in_without_fee;
        let swap_fee_2 = SafeMath::safe_mul_div_u128(x_in, 3, 1000);

        Debug::print<u128>(&110400);
        Debug::print<u128>(&swap_fee);
        Debug::print<u128>(&swap_fee_2);
        assert!(swap_fee == swap_fee_2, 221);
    }
}
//the case: token pay for fee and fee token pair exist
// check: EXECUTED