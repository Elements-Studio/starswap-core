//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice

//# faucet --addr SwapAdmin

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WUSDT};

    fun init_token(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        TokenMock::register_token<WUSDT>(&signer, precision);
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

//# run --signers alice

script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Math;

    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock::WUSDT;
    //use SwapAdmin::TokenSwap;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapLibrary;
    use SwapAdmin::TokenSwapConfig;

    fun main(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.

        let scaling_factor = Math::pow(10, (precision as u64));// STC/WUSDT = 1:5
        let stc_amount: u128 = 1000 * scaling_factor;
        let usdt_amount: u128 = 1000 * scaling_factor;

        CommonHelper::safe_mint<WUSDT>(&signer, usdt_amount);
        ////////////////////////////////////////////////////////////////////////////////////////////
        // Add liquidity, STC/WUSDT = 1:1
        let amount_stc_desired: u128 = 1 * scaling_factor;
        let amount_usdt_desired: u128 = 1 * scaling_factor;
        let amount_stc_min: u128 = stc_amount;
        let amount_usdt_min: u128 = usdt_amount;
        TokenSwapRouter::add_liquidity<STC, WUSDT>(&signer,
            amount_stc_desired, amount_usdt_desired, amount_stc_min, amount_usdt_min);
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity > 0, 10000);

        let (fee_numberator, fee_denumerator) = TokenSwapConfig::get_poundage_rate<STC, WUSDT>();
        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WUSDT>();
        //Debug::print<u128>(&reserve_x);
        //Debug::print<u128>(&reserve_y);
        assert!(reserve_x >= amount_stc_desired, 10001);
        // assert!(reserve_y >=, 10002);

        let amount_out_1 = TokenSwapLibrary::get_amount_out(10 * scaling_factor, reserve_x, reserve_y, fee_numberator, fee_denumerator);
        Debug::print<u128>(&amount_out_1);
        // assert!(1 * scaling_factor >= (1 * scaling_factor * reserve_y) / reserve_x * (997 / 1000), 1003);

        let amount_out_2 = TokenSwapLibrary::quote(amount_stc_desired, reserve_x, reserve_y);
        Debug::print<u128>(&amount_out_2);
        // assert!(amount_out_2 <= amount_usdt_desired, 1004);

        let amount_out_3 = TokenSwapLibrary::get_amount_in(100, 100000000, 10000000000, 3, 1000);
        Debug::print<u128>(&amount_out_3);
        //assert!(amount_out_3 >= amount_stc_desired, 1005);
    }
}