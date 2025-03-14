//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5 --public-keys Bridge=0x8085e172ecf785692da465ba3339da46c4b43640c3f92a45db803690cc3c4a36 --public-keys SwapFeeAdmin=0xbf76b7fc68b3344e63512fd6b4ded611e6910fc9df1b9f858cb6bf571e201e2d --addresses SwapFeeAdmin=0x9572abb16f9d9e9b009cc1751727129e

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr exchanger --amount 10000000000000000

//# faucet --addr SwapFeeAdmin --amount 10000000000000000

//# faucet --addr swap_admin --amount 10000000000000000

//# faucet --addr Bridge --amount 10000000000000000

//# publish
module swap_admin::coin_mock {
    use starcoin_framework::managed_coin;
    use starcoin_std::type_info::{struct_name, type_of};

    struct WETH {}

    struct WUSDT {}

    struct WDAI {}

    public fun initialize<T>(alice: &signer, percision: u8) {
        let name = struct_name(&type_of<T>());
        managed_coin::initialize<T>(
            alice,
            name,
            name,
            percision,
            true,
        );
        managed_coin::register<T>(alice);
    }
}

//# run --signers swap_admin
script {
    use swap_admin::coin_mock::{initialize, WDAI, WETH, WUSDT};

    fun token_init(swap_admin: &signer) {
        initialize<WETH>(swap_admin, 12);
        initialize<WUSDT>(swap_admin, 12);
        initialize<WDAI>(swap_admin, 12);
    }
}

// check: EXECUTED

//# run --signers swap_admin
script {
    use swap_admin::coin_mock::{WDAI, WETH, WUSDT};
    use swap_admin::CommonHelper;

    fun init_account(swap_admin: &signer) {
        CommonHelper::safe_mint<WETH>(swap_admin, 600000u128);
        CommonHelper::safe_mint<WUSDT>(swap_admin, 500000u128);
        CommonHelper::safe_mint<WDAI>(swap_admin, 200000u128);
    }
}
// check: EXECUTED
//
//
// //# run --signers swap_admin
// script {
//     use swap_admin::TokenSwapFee;
//
//     fun init_token_swap_fee(signer: signer) {
//         TokenSwapFee::initialize_token_swap_fee(&signer);
//     }
// }
// // check: EXECUTED

//
// //# run --signers Bridge
// script {
//     use Bridge::XUSDT::XUSDT;
//     use starcoin_framework::Token;
//     use starcoin_framework::Account;
//
//     fun fee_token_init(signer: signer) {
//         Token::register_token<XUSDT>(&signer, 9);
//         Account::do_accept_token<XUSDT>(&signer);
//         let token = Token::mint<XUSDT>(&signer, 500000u128);
//         Account::deposit_to_self(&signer, token);
//     }
// }
//
// // check: EXECUTED
//
//
// //# run --signers exchanger
// script {
//     use swap_admin::coin_mock::WETH;
//     use starcoin_framework::Account;
//
//     fun accept_token(signer: signer) {
//         Account::do_accept_token<WETH>(&signer);
//     }
// }
// // check: EXECUTED
//
//
// //# run --signers alice
//
// script {
//     use starcoin_framework::Account;
//     use Bridge::XUSDT::XUSDT;
//
//     fun accept_token(signer: signer) {
//         Account::do_accept_token<XUSDT>(&signer);
//     }
// }
// // check: EXECUTED
//
//
// //# run --signers SwapFeeAdmin
// script {
//     use starcoin_framework::Account;
//     use Bridge::XUSDT::XUSDT;
//
//     fun accept_token(signer: signer) {
//         Account::do_accept_token<XUSDT>(&signer);
//     }
// }
// // check: EXECUTED
//
//
// //# run --signers exchanger
// script {
//     use swap_admin::coin_mock::WETH;
//     use swap_admin::CommonHelper;
//
//     fun transfer(signer: signer) {
//         CommonHelper::safe_mint<WETH>(&signer, 100000u128);
//     }
// }
//
// // check: EXECUTED
//
//
// //# run --signers Bridge
// script {
//     use swap_admin::CommonHelper;
//     use Bridge::XUSDT::XUSDT;
//
//     fun transfer(signer: signer) {
//         CommonHelper::transfer<XUSDT>(&signer, @alice, 300000u128);
//     }
// }
//
// // check: EXECUTED
//
//
// //# run --signers swap_admin
//
// script {
//     use swap_admin::coin_mock::{WETH, WUSDT};
//     use swap_admin::TokenSwapRouter;
//     use starcoin_framework::starcoin_coin::STC;
//     use Bridge::XUSDT::XUSDT;
//
//     fun register_token_pair(signer: signer) {
//         //token pair register must be swap admin account
//         TokenSwapRouter::register_swap_pair<WETH, WUSDT>(&signer);
//         assert!(TokenSwapRouter::swap_pair_exists<WETH, WUSDT>(), 111);
//
//         TokenSwapRouter::register_swap_pair<STC, WETH>(&signer);
//         assert!(TokenSwapRouter::swap_pair_exists<STC, WETH>(), 112);
//
//         TokenSwapRouter::register_swap_pair<STC, XUSDT>(&signer);
//         assert!(TokenSwapRouter::swap_pair_exists<STC, XUSDT>(), 113);
//     }
// }
//
// // check: EXECUTED
//
//
//
// //# run --signers swap_admin
// script {
//     use swap_admin::TokenSwapRouter;
//
//     fun open_swap_fee_auto_convert_switch(signer: signer) {
//         TokenSwapRouter::set_fee_auto_convert_switch(&signer, true);
//     }
// }
// // check: EXECUTED
//
//
// //# run --signers alice
// script {
//     use swap_admin::TokenSwapRouter;
//     use starcoin_framework::starcoin_coin::STC;
//     use swap_admin::coin_mock::{WETH, WUSDT};
//     use Bridge::XUSDT::XUSDT;
//
//     fun add_liquidity(signer: signer) {
//         // for the first add liquidity
//         TokenSwapRouter::add_liquidity<WETH, WUSDT>(&signer, 100000, 200000, 100, 100);
//         TokenSwapRouter::add_liquidity<STC, WETH>(&signer, 100000, 30000, 100, 100);
//
//         TokenSwapRouter::add_liquidity<STC, XUSDT>(&signer, 200000, 50000, 100, 100);
//     }
// }
//
// // check: EXECUTED
//
//
// //# run --signers exchanger
// script {
//     use starcoin_framework::starcoin_coin::STC;
//     use starcoin_std::debug;
//     use Bridge::XUSDT::XUSDT;
//
//     use swap_admin::TokenSwap;
//     use swap_admin::TokenSwapRouter;
//     use swap_admin::TokenSwapLibrary;
//     use swap_admin::TokenSwapConfig;
//     use swap_admin::coin_mock::WETH;
//     use swap_admin::CommonHelper;
//     use swap_admin::SafeMath;
//
//     fun swap_exact_token_for_token_swap(signer: signer) {
//         let amount_x_in = 20000;
//         let amount_y_out_min = 10;
//         let fee_balance_before = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);
//
//         TokenSwapRouter::swap_exact_token_for_token<STC, WETH>(&signer, amount_x_in, amount_y_out_min);
//         let (actual_fee_operation_numerator, actual_fee_operation_denominator) = TokenSwap::cacl_actual_swap_fee_operation_rate<STC, WETH>();
//         let swap_fee = SafeMath::safe_mul_div_u128(amount_x_in, actual_fee_operation_numerator, actual_fee_operation_denominator);
//
//         let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, XUSDT>();
//         let (reserve_x, reserve_fee) = TokenSwapRouter::get_reserves<STC, XUSDT>();
//         let fee_out = TokenSwapLibrary::get_amount_out(swap_fee, reserve_x, reserve_fee, fee_numberator, fee_denumerator);
//         let fee_balance_after = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);
//
//         let fee_balance_change = fee_balance_after - fee_balance_before;
//         debug::print<u128>(&110100);
//         debug::print<u128>(&swap_fee);
//         debug::print<u128>(&fee_out);
//         debug::print<u128>(&fee_balance_change);
//         debug::print<u128>(&fee_balance_after);
//         debug::print(&@SwapFeeAdmin);
//         assert!(fee_balance_change == fee_out, 201);
//         assert!(fee_balance_change >= 0, 202);
//     }
// }
// //the case: token pay for fee and fee token pair exist
// //check: EXECUTED
//
//
// //# run --signers exchanger
// script {
//     use starcoin_std::debug;
//     use starcoin_framework::starcoin_coin::STC;
//     use Bridge::XUSDT::XUSDT;
//
//     use swap_admin::TokenSwap;
//     use swap_admin::SafeMath;
//     use swap_admin::CommonHelper;
//     use swap_admin::TokenSwapRouter;
//     use swap_admin::TokenSwapLibrary;
//     use swap_admin::TokenSwapConfig;
//     use swap_admin::coin_mock::WETH;
//
//     fun swap_token_for_exact_token_swap(signer: signer) {
//         let amount_x_in_max = 30000;
//         let amount_y_out = 3200;
//         let fee_balance_start = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);
//
//         let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WETH>();
//         let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, WETH>();
//
//         let x_in = TokenSwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y, fee_numberator, fee_denumerator);
//         TokenSwapRouter::swap_token_for_exact_token<STC, WETH>(&signer, amount_x_in_max, amount_y_out);
//
//         let (actual_fee_operation_numerator, actual_fee_operation_denominator) = TokenSwap::cacl_actual_swap_fee_operation_rate<STC, WETH>();
//         let swap_fee = SafeMath::safe_mul_div_u128(x_in, actual_fee_operation_numerator, actual_fee_operation_denominator);
//
//         let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, XUSDT>();
//         let (reserve_x, reserve_fee) = TokenSwapRouter::get_reserves<STC, XUSDT>();
//         let fee_out = TokenSwapLibrary::get_amount_out(swap_fee, reserve_x, reserve_fee, fee_numberator, fee_denumerator);
//         let fee_balance_end = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);
//         let fee_balance_change = fee_balance_end - fee_balance_start;
//
//         debug::print<u128>(&110200);
//         debug::print<u128>(&x_in);
//         debug::print<u128>(&swap_fee);
//         debug::print<u128>(&reserve_fee);
//         debug::print<u128>(&fee_out);
//         debug::print<u128>(&fee_balance_change);
//         assert!(fee_balance_change == fee_out, 205);
//         assert!(fee_balance_change >= 0, 206);
//     }
// }
// //the case: token pay for fee and fee token pair exist
// // check: EXECUTED
//
//
//
// //# run --signers exchanger
//
//
// script {
//     use starcoin_std::debug;
//
//     use swap_admin::TokenSwap;
//     use swap_admin::TokenSwapRouter;
//     use swap_admin::TokenSwapLibrary;
//     use swap_admin::TokenSwapConfig;
//     use swap_admin::coin_mock::{WETH, WUSDT};
//     use Bridge::XUSDT::XUSDT;
//
//     use swap_admin::CommonHelper;
//     use swap_admin::SafeMath;
//
//     fun pay_for_token_and_fee_token_pair_not_exist(signer: signer) {
//         let amount_x_in = 10000;
//         let amount_y_out_min = 10;
//         let fee_balance_start = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);
//
//         let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<WUSDT, WETH>();
//         let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<WUSDT, WETH>();
//         let y_out = TokenSwapLibrary::get_amount_out(amount_x_in, reserve_x, reserve_y, fee_numberator, fee_denumerator);
//         TokenSwapRouter::swap_exact_token_for_token<WETH, WUSDT>(&signer, amount_x_in, amount_y_out_min);
//         let (actual_fee_operation_numerator, actual_fee_operation_denominator) = TokenSwap::cacl_actual_swap_fee_operation_rate<WETH, WUSDT>();
//         let swap_fee = SafeMath::safe_mul_div_u128(amount_x_in, actual_fee_operation_numerator, actual_fee_operation_denominator);
//
//         let fee_balance_end = CommonHelper::get_safe_balance<XUSDT>(@SwapFeeAdmin);
//         let fee_balance_change = fee_balance_end - fee_balance_start;
//
//         debug::print<u128>(&110300);
//         debug::print<u128>(&amount_y_out_min);
//         debug::print<u128>(&y_out);
//         debug::print<u128>(&swap_fee);
//         debug::print<u128>(&fee_balance_change);
//         assert!(fee_balance_change == 0, 210);
//     }
// }
// //the case: token pay for fee and fee token pair not exist
// // check: EXECUTED
//
//
// //# run --signers exchanger
// script {
//     use starcoin_framework::starcoin_coin::STC;
//
//     use swap_admin::TokenSwapRouter;
//     use swap_admin::TokenSwapLibrary;
//     use swap_admin::TokenSwapConfig;
//     use swap_admin::coin_mock::WETH;
//
//     use swap_admin::SafeMath;
//     use starcoin_std::debug;
//
//     /// two way to calculate swap fee and compare
//     fun swap_exact_token_for_token_swap_fee_calculate(_: signer) {
//         let amount_x_in = 20507;
// //        let amount_y_out_min = 10;
//         let swap_fee = SafeMath::safe_mul_div_u128(amount_x_in, 3, 1000);
//         let amountx_x_in_2 = amount_x_in - swap_fee;
//
//         let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, WETH>();
//         let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WETH>();
//         let y_out = TokenSwapLibrary::get_amount_out(amount_x_in, reserve_x, reserve_y, fee_numberator, fee_denumerator);
//         let y_out_2 = TokenSwapLibrary::get_amount_out_without_fee(amountx_x_in_2, reserve_x, reserve_y);
//
//         debug::print<u128>(&110400);
//         debug::print<u128>(&swap_fee);
//         debug::print<u128>(&y_out);
//         debug::print<u128>(&y_out_2);
//         assert!(y_out == y_out_2, 215);
//     }
// }
// //the case: token pay for fee and fee token pair exist
// // check: EXECUTED
//
//
// //# run --signers exchanger
// script {
//     use starcoin_std::debug;
//     use starcoin_framework::starcoin_coin::STC;
//
//     use swap_admin::TokenSwapRouter;
//     use swap_admin::TokenSwapLibrary;
//     use swap_admin::TokenSwapConfig;
//     use swap_admin::coin_mock::WETH;
//     use swap_admin::SafeMath;
//
//     fun swap_token_for_exact_token_swap_fee_calculate(_: signer) {
// //        let amount_x_in_max = 8000;
//         let amount_y_out = 1299;
//
//         let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, WETH>();
//         let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WETH>();
//         let x_in = TokenSwapLibrary::get_amount_in(amount_y_out, reserve_x, reserve_y, fee_numberator, fee_denumerator);
//         let x_in_without_fee = TokenSwapLibrary::get_amount_in_without_fee(amount_y_out, reserve_x, reserve_y);
//         let swap_fee = x_in - x_in_without_fee;
//         let swap_fee_2 = SafeMath::safe_mul_div_u128(x_in, 3, 1000);
//
//         debug::print<u128>(&110400);
//         debug::print<u128>(&swap_fee);
//         debug::print<u128>(&swap_fee_2);
//         assert!(swap_fee == swap_fee_2, 221);
//     }
// }
// //the case: token pay for fee and fee token pair exist
// // check: EXECUTED