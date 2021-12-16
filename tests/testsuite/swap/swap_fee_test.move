//! account: admin, 0x4783d08fb16990bd35d83f3e23bf93b8, 200000 0x1::STC::STC
//! account: feetokenholder, 0x2d81a0427d64ff61b11ede9085efa5ad, 400000 0x1::STC::STC
//! account: feeadmin, 0xd231d9da8e37fc3d9ff3f576cf978535
//! account: exchanger, 100000 0x1::STC::STC
//! account: alice, 500000 0x1::STC::STC


//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{Self, WETH, WUSDT, WDAI};

    fun token_init(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 18u8);
        TokenMock::register_token<WUSDT>(&signer, 18u8);
        TokenMock::register_token<WDAI>(&signer, 18u8);
    }
}

// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT, WDAI};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;

    fun init_account(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 600000u128);
        CommonHelper::safe_mint<WUSDT>(&signer, 500000u128);
        CommonHelper::safe_mint<WDAI>(&signer, 200000u128);
    }
}
// check: EXECUTED


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
//! sender: exchanger
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};
    use 0x1::Account;

    fun accept_token(signer: signer) {
        Account::do_accept_token<WETH>(&signer);
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
//! sender: exchanger
address alice = {{alice}};
address exchanger = {{exchanger}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;

    fun transfer(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 100000u128);
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
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x1::STC::STC;
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<WETH, WUSDT>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<WETH, WUSDT>(), 111);

        TokenSwapRouter::register_swap_pair<STC, WETH>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<STC, WETH>(), 112);

        TokenSwapRouter::register_swap_pair<STC, XUSDT>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<STC, XUSDT>(), 113);
    }
}

// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x1::STC::STC;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    fun add_liquidity(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<WETH, WUSDT>(&signer, 100000, 200000, 100, 100);
        TokenSwapRouter::add_liquidity<STC, WETH>(&signer, 100000, 30000, 100, 100);

        TokenSwapRouter::add_liquidity<STC, XUSDT>(&signer, 200000, 50000, 100, 100);
    }
}

// check: EXECUTED


//! new-transaction
//! sender: exchanger
address alice = {{alice}};
address feeadmin = {{feeadmin}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwap;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;
    use 0x1::STC::STC;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::SafeMath;
    use 0x1::Debug;

    fun swap_exact_token_for_token_swap(signer: signer) {
        let amount_x_in = 20000;
        let amount_y_out_min = 10;
        let fee_balance_before = CommonHelper::get_safe_balance<XUSDT>(@feeadmin);

        TokenSwapRouter::swap_exact_token_for_token<STC, WETH>(&signer, amount_x_in, amount_y_out_min);
        let (actual_fee_operation_numerator, actual_fee_operation_denominator) = TokenSwap::cacl_actual_swap_fee_operation_rate<STC, WETH>();
        let swap_fee = SafeMath::safe_mul_div_u128(amount_x_in, actual_fee_operation_numerator, actual_fee_operation_denominator);

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, XUSDT>();
        let (reserve_x, reserve_fee) = TokenSwapRouter::get_reserves<STC, XUSDT>();
        let fee_out = TokenSwapLibrary::get_amount_out(swap_fee, reserve_x, reserve_fee, fee_numberator, fee_denumerator);
        let fee_balance_after = CommonHelper::get_safe_balance<XUSDT>(@feeadmin);

        let fee_balance_change = fee_balance_after - fee_balance_before;
        Debug::print<u128>(&110100);
        Debug::print<u128>(&swap_fee);
        Debug::print<u128>(&fee_out);
        Debug::print<u128>(&fee_balance_change);
        assert(fee_balance_change == fee_out, 201);
        assert(fee_balance_change >= 0, 202);
    }
}
//the case: token pay for fee and fee token pair exist
// check: EXECUTED



//! new-transaction
//! sender: exchanger
address alice = {{alice}};
address feeadmin = {{feeadmin}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwap;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;

    use 0x1::STC::STC;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::SafeMath;
    use 0x1::Debug;

    fun swap_token_for_exact_token_swap(signer: signer) {
        let amount_x_in_max = 30000;
        let amount_y_out = 3200;
        let fee_balance_start = CommonHelper::get_safe_balance<XUSDT>(@feeadmin);

        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WETH>();
        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, WETH>();
        let x_in = TokenSwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y, fee_numberator, fee_denumerator);
        TokenSwapRouter::swap_token_for_exact_token<STC, WETH>(&signer, amount_x_in_max, amount_y_out);

        let (actual_fee_operation_numerator, actual_fee_operation_denominator) = TokenSwap::cacl_actual_swap_fee_operation_rate<STC, WETH>();
        let swap_fee = SafeMath::safe_mul_div_u128(x_in, actual_fee_operation_numerator, actual_fee_operation_denominator);

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, XUSDT>();
        let (reserve_x, reserve_fee) = TokenSwapRouter::get_reserves<STC, XUSDT>();
        let fee_out = TokenSwapLibrary::get_amount_out(swap_fee, reserve_x, reserve_fee, fee_numberator, fee_denumerator);
        let fee_balance_end = CommonHelper::get_safe_balance<XUSDT>(@feeadmin);
        let fee_balance_change = fee_balance_end - fee_balance_start;

        Debug::print<u128>(&110200);
        Debug::print<u128>(&x_in);
        Debug::print<u128>(&swap_fee);
        Debug::print<u128>(&reserve_fee);
        Debug::print<u128>(&fee_out);
        Debug::print<u128>(&fee_balance_change);
        assert(fee_balance_change == fee_out, 205);
        assert(fee_balance_change >= 0, 206);
    }
}
//the case: token pay for fee and fee token pair exist
// check: EXECUTED



//! new-transaction
//! sender: exchanger
address alice = {{alice}};
address feeadmin = {{feeadmin}};
script {
    use 0x1::Debug;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwap;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WUSDT};
    use 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::SafeMath;

    fun pay_for_token_and_fee_token_pair_not_exist(signer: signer) {
        let amount_x_in = 10000;
        let amount_y_out_min = 10;
        let fee_balance_start = CommonHelper::get_safe_balance<XUSDT>(@feeadmin);


        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<WUSDT, WETH>();
        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<WUSDT, WETH>();
        let y_out = TokenSwapLibrary::get_amount_out(amount_x_in, reserve_x, reserve_y, fee_numberator, fee_denumerator);
        TokenSwapRouter::swap_exact_token_for_token<WETH, WUSDT>(&signer, amount_x_in, amount_y_out_min);
        let (actual_fee_operation_numerator, actual_fee_operation_denominator) = TokenSwap::cacl_actual_swap_fee_operation_rate<WETH, WUSDT>();
        let swap_fee = SafeMath::safe_mul_div_u128(amount_x_in, actual_fee_operation_numerator, actual_fee_operation_denominator);

        let fee_balance_end = CommonHelper::get_safe_balance<XUSDT>(@feeadmin);
        let fee_balance_change = fee_balance_end - fee_balance_start;

        Debug::print<u128>(&110300);
        Debug::print<u128>(&amount_y_out_min);
        Debug::print<u128>(&y_out);
        Debug::print<u128>(&swap_fee);
        Debug::print<u128>(&fee_balance_change);
        assert(fee_balance_change == 0, 210);
    }
}
//the case: token pay for fee and fee token pair not exist
// check: EXECUTED


//! new-transaction
//! sender: exchanger
address alice = {{alice}};
address feeadmin = {{feeadmin}};
script {
    use 0x1::STC::STC;
    
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};

    use 0x4783d08fb16990bd35d83f3e23bf93b8::SafeMath;
    use 0x1::Debug;

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
        assert(y_out == y_out_2, 215);
    }
}
//the case: token pay for fee and fee token pair exist
// check: EXECUTED


//! new-transaction
//! sender: exchanger
address alice = {{alice}};
address feeadmin = {{feeadmin}};
script {
    use 0x1::Debug;
    use 0x1::STC::STC;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapLibrary;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::SafeMath;

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
        assert(swap_fee == swap_fee_2, 221);
    }
}
//the case: token pay for fee and fee token pair exist
// check: EXECUTED