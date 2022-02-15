//! account: alice, 10000000000000 0x1::STC::STC
//! account: bob, 10000000000000 0x1::STC::STC
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
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::{WUSDT};
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::CommonHelper;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapRouter;
    use 0x1::Math;
    use 0x1::STC::STC;

    // Deposit to swap pool
    fun main(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.

        let scaling_factor = Math::pow(10, (precision as u64));// STC/WUSDT = 1:5
        let stc_amount: u128 = 1000000 * scaling_factor;
        let usdt_amount: u128 = 1000000 * scaling_factor;

        CommonHelper::safe_mint<WUSDT>(&signer, usdt_amount);
        ////////////////////////////////////////////////////////////////////////////////////////////
        // Add liquidity, STC/WUSDT = 1:1
        let amount_stc_desired: u128 = 10000 * scaling_factor;
        let amount_usdt_desired: u128 = 10000 * scaling_factor;
        let amount_stc_min: u128 = stc_amount;
        let amount_usdt_min: u128 = usdt_amount;
        TokenSwapRouter::add_liquidity<STC, WUSDT>(
            &signer, amount_stc_desired, amount_usdt_desired, amount_stc_min, amount_usdt_min);

        // check liquidity
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert(total_liquidity > 0, 10000);

        // check reverse
        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<STC, WUSDT>();
        assert(reserve_x >= amount_stc_desired, 10001);
        assert(reserve_y >= amount_usdt_desired, 10001);
   }
}

// check: EXECUTED



//! new-transaction
//! sender: bob
address bob = {{bob}};
address alice = {{alice}};
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::WUSDT;
    use 0x1::STC::STC;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Debug;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapRouter;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwap;

    fun main(signer: signer) {
        let (reserve_x, reserve_y) = TokenSwap::get_reserves<STC, WUSDT>();
        Debug::print<u128>(&reserve_x);
        Debug::print<u128>(&reserve_y);
        TokenSwapRouter::swap_exact_token_for_token<STC, WUSDT>(&signer, 100, 0);
        let balance = Account::balance<WUSDT>(Signer::address_of(&signer));
        assert(balance > 0, 10002);

        TokenSwapRouter::swap_token_for_exact_token<STC, WUSDT>(&signer, 10000000, 10000);
        let balance = Account::balance<STC>(Signer::address_of(&signer));
        assert(balance > 0, 10003);
    }
}

// check: EXECUTED