//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5 Bridge=0xa0b9394a752f51b1a7956950c67a84ec1d0e627ef4e44cadef3aedbd53f8bc35

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr Bridge --amount 10000000000000000

//# faucet --addr exchanger --amount 10000000000000000

//# faucet --addr lp_provider --amount 10000000000000000

//# faucet --addr SwapFee --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# publish
module SwapAdmin::SwapOracleWrapper {
    use StarcoinFramework::U256::{Self, U256};
    use SwapAdmin::FixedPoint128;

    struct SwapOralce<phantom X, phantom Y> has key, store {
        last_block_timestamp: u64,
        last_price_x_cumulative: U256,
        last_price_y_cumulative: U256,
    }

    /// ignore token pair order, just for test
    public fun initialize_oralce<X: copy + drop + store, Y: copy + drop + store>(signer: &signer) {
        let price_oracle = SwapOralce<X, Y>{
            last_block_timestamp: 0,
            last_price_x_cumulative: U256::zero(),
            last_price_y_cumulative: U256::zero(),
        };
        move_to(signer, price_oracle);
    }

    public fun set_last_oracle<X: copy + drop + store, Y: copy + drop + store>(
        price_x_cumulative: u128,
        price_y_cumulative: u128,
        block_timestamp: u64,
    ) acquires SwapOralce {
        let price_oracle = borrow_global_mut<SwapOralce<X, Y>>(@SwapAdmin);
        price_oracle.last_price_x_cumulative = FixedPoint128::to_u256(FixedPoint128::encode(price_x_cumulative));
        price_oracle.last_price_y_cumulative = FixedPoint128::to_u256(FixedPoint128::encode(price_y_cumulative));
        price_oracle.last_block_timestamp = block_timestamp;
    }

    public fun get_last_oracle<X: copy + drop + store, Y: copy + drop + store>(): (u128, u128, u64) acquires SwapOralce {
        let price_oracle = borrow_global<SwapOralce<X, Y>>(@SwapAdmin);
        let last_block_timestamp = price_oracle.last_block_timestamp;
        let last_price_x_cumulative_decode = FixedPoint128::decode(FixedPoint128::encode_u256(*&price_oracle.last_price_x_cumulative, false));
        let last_price_y_cumulative_decode = FixedPoint128::decode(FixedPoint128::encode_u256(*&price_oracle.last_price_y_cumulative, false));

        (last_price_x_cumulative_decode, last_price_y_cumulative_decode, last_block_timestamp)
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WETH, WUSDT};

    fun token_init(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 18u8);
        TokenMock::register_token<WUSDT>(&signer, 18u8);
    }
}
// check: EXECUTED

//# run --signers lp_provider
script {
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use SwapAdmin::CommonHelper;

    fun init_account(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 60000000000000000000000000u128); //e25
        CommonHelper::safe_mint<WUSDT>(&signer, 50000000000000000000000000000u128);//e28
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
        let token = Token::mint<XUSDT>(&signer, 5000000000000u128);
        Account::deposit_to_self(&signer, token);
    }
}

// check: EXECUTED


//# run --signers SwapFee
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

    fun mint(signer: signer) {
        CommonHelper::safe_mint<WETH>(&signer, 3900000000000000000000u128); //e21
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use SwapAdmin::TokenSwapRouter;

    fun register_token_pair(signer: signer) {
        //token pair register must be swap SwapAdmin account
        TokenSwapRouter::register_swap_pair<WETH, WUSDT>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<WETH, WUSDT>(), 111);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use SwapAdmin::SwapOracleWrapper;

    fun initialize_oralce(signer: signer) {
        SwapOracleWrapper::initialize_oralce<WETH, WUSDT>(&signer);
    }
}

// check: EXECUTED


//# block --author 0x1 --timestamp 1638415260000

//# run --signers alice
script {
    use SwapAdmin::TokenSwapOracleLibrary;
    use StarcoinFramework::Debug;

    fun oralce_info(_: signer) {
        let block_timestamp = TokenSwapOracleLibrary::current_block_timestamp();
        Debug::print(&block_timestamp);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenSwapOracleLibrary;
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use StarcoinFramework::Debug;

    fun oralce_info(_: signer) {
        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();

        Debug::print<u128>(&110500);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
        assert!(price_x_cumulative == 0, 1301);
        assert!(price_y_cumulative == 0, 1302);
    }
}
// check: EXECUTED


//# run --signers lp_provider
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapOracleLibrary;
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use StarcoinFramework::Debug;

    // block time has not change, does not trigger to update oracle
    fun add_liquidity(signer: signer) {
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<WETH, WUSDT>(&signer, 60000000000000000000000u128, 50000000000000000000000000u128, 100, 100); //e22, e25

        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();
        Debug::print<u128>(&110501);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
        assert!(price_x_cumulative == 0, 1303);
        assert!(price_y_cumulative == 0, 1304);
    }
}

// check: EXECUTED

//# block --author 0x1 --timestamp 1638415320000

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapOracleLibrary;
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use StarcoinFramework::Debug;
    use StarcoinFramework::Timestamp;
    use SwapAdmin::SwapOracleWrapper;

    // block time changed, trigger to update oracle
    fun swap_exact_token_for_token(signer: signer) {
        let amount_x_in = 100000000000000000000u128; //e20
        let amount_y_out_min = 25000000000000000u128;
        TokenSwapRouter::swap_exact_token_for_token<WETH, WUSDT>(&signer, amount_x_in, amount_y_out_min);

        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();
        SwapOracleWrapper::set_last_oracle<WETH, WUSDT>(price_x_cumulative, price_y_cumulative, block_timestamp);
        Debug::print<u128>(&110502);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
        let current_block_timestamp = Timestamp::now_seconds() % (1u64 << 32);
        Debug::print<u64>(&current_block_timestamp);
        assert!(price_x_cumulative >= 0, 1305);
        assert!(price_y_cumulative >= 0, 1306);
    }
}
// check: EXECUTED


//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapOracleLibrary;
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use StarcoinFramework::Debug;
    use StarcoinFramework::Timestamp;

    fun swap_token_for_exact_token(signer: signer) {
        let amount_x_in_max = 500000000000000000000u128;
        let amount_y_out = 2500000000000000000000u128; //e21
        TokenSwapRouter::swap_token_for_exact_token<WETH, WUSDT>(&signer, amount_x_in_max, amount_y_out);

        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();
        Debug::print<u128>(&110503);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
        let current_block_timestamp = Timestamp::now_seconds() % (1u64 << 32);
        Debug::print<u64>(&current_block_timestamp);

    }
}
// check: EXECUTED


//# block --author 0x1 --timestamp 1638415380000

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::FixedPoint128;
    use SwapAdmin::TokenSwapOracleLibrary;
    use SwapAdmin::TokenMock::{WETH, WUSDT};

    use StarcoinFramework::Debug;
    use SwapAdmin::SwapOracleWrapper;

    /// forward token pair swap
    fun swap_token_for_exact_token(signer: signer) {
        let amount_x_in_max = 500000000000000000000u128; //e20
        let amount_y_out = 2500000000000000000000u128; //e21

        let (price_x_cumulative0, price_y_cumulative0, block_timestamp0) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();
        Debug::print<u128>(&110504);
        Debug::print(&block_timestamp0);
        Debug::print<u128>(&price_x_cumulative0);
        Debug::print<u128>(&price_y_cumulative0);

        let (price_x_cumulative_base_a1, price_y_cumulative_base_a1, last_block_timestamp_base_a) = TokenSwapRouter::get_cumulative_info<WETH, WUSDT>();
        let price_x_cumulative_base_a = FixedPoint128::decode(FixedPoint128::encode_u256(price_x_cumulative_base_a1, false));
        let price_y_cumulative_base_a = FixedPoint128::decode(FixedPoint128::encode_u256(price_y_cumulative_base_a1, false));
        Debug::print(&last_block_timestamp_base_a);
        Debug::print<u128>(&price_x_cumulative_base_a);
        Debug::print<u128>(&price_y_cumulative_base_a);

        TokenSwapRouter::swap_token_for_exact_token<WETH, WUSDT>(&signer, amount_x_in_max, amount_y_out);

        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WETH, WUSDT>();
        SwapOracleWrapper::set_last_oracle<WETH, WUSDT>(price_x_cumulative, price_y_cumulative, block_timestamp);

        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);

        let (price_x_cumulative_base_b1, price_y_cumulative_base_b1, last_block_timestamp_base_b) = TokenSwapRouter::get_cumulative_info<WETH, WUSDT>();
        let price_x_cumulative_base_b = FixedPoint128::decode(FixedPoint128::encode_u256(price_x_cumulative_base_b1, false));
        let price_y_cumulative_base_b = FixedPoint128::decode(FixedPoint128::encode_u256(price_y_cumulative_base_b1, false));
        Debug::print(&last_block_timestamp_base_b);
        Debug::print<u128>(&price_x_cumulative_base_b);
        Debug::print<u128>(&price_y_cumulative_base_b);

        assert!(price_x_cumulative == price_x_cumulative0, 1307);
        assert!(price_y_cumulative == price_y_cumulative0, 1308);
        assert!(price_x_cumulative_base_b >= price_x_cumulative_base_a, 1309);
        assert!(price_y_cumulative_base_b >= price_y_cumulative_base_a, 1310);
    }
}
// check: EXECUTED


//# block --author 0x1 --timestamp 1638417000000

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapOracleLibrary;
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use StarcoinFramework::Debug;
    use SwapAdmin::SwapOracleWrapper;

    /// reverse token pair swap
    fun swap_token_for_exact_token(signer: signer) {
        let amount_x_in_max = 6000000000000000000000u128; //e22
        let amount_y_out = 100000000000000000u128; //e17

        let (price_x_cumulative0, price_y_cumulative0, block_timestamp0) = TokenSwapOracleLibrary::current_cumulative_prices<WUSDT, WETH>();
        Debug::print<u128>(&110505);
        Debug::print(&block_timestamp0);
        Debug::print<u128>(&price_x_cumulative0);
        Debug::print<u128>(&price_y_cumulative0);
        let (reserve_x0, reserve_y0) = TokenSwapRouter::get_reserves<WUSDT, WETH>();
        Debug::print<u128>(&reserve_x0);
        Debug::print<u128>(&reserve_y0);

        TokenSwapRouter::swap_token_for_exact_token<WUSDT, WETH>(&signer, amount_x_in_max, amount_y_out);

        let (price_x_cumulative, price_y_cumulative, block_timestamp) = TokenSwapOracleLibrary::current_cumulative_prices<WUSDT, WETH>();
        SwapOracleWrapper::set_last_oracle<WETH, WUSDT>(price_x_cumulative, price_y_cumulative, block_timestamp);
        Debug::print(&block_timestamp);
        Debug::print<u128>(&price_x_cumulative);
        Debug::print<u128>(&price_y_cumulative);
        let (reserve_x, reserve_y) = TokenSwapRouter::get_reserves<WUSDT, WETH>();
        Debug::print<u128>(&reserve_x);
        Debug::print<u128>(&reserve_y);

        assert!(price_x_cumulative == price_x_cumulative0, 1311);
        assert!(price_y_cumulative == price_y_cumulative0, 1312);

        // assert price cumulative
        let (last_block_price_x_cumulative, last_block_price_y_cumulative, _) = SwapOracleWrapper::get_last_oracle<WETH, WUSDT>();
        assert!(price_x_cumulative >= last_block_price_x_cumulative, 1311);
        assert!(price_y_cumulative >= last_block_price_y_cumulative, 1312);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 1638418320000

//# run --signers exchanger
script {
    use SwapAdmin::TokenSwapOracleLibrary;
    use SwapAdmin::TokenMock::{WETH, WUSDT};
    use StarcoinFramework::Debug;

    /// reverse token pair swap
    fun swap_token_for_exact_token(_: signer) {
        let (price_x_cumulative0, price_y_cumulative0, block_timestamp0) = TokenSwapOracleLibrary::current_cumulative_prices<WUSDT, WETH>();
        Debug::print<u128>(&110506);
        Debug::print(&block_timestamp0);
        Debug::print<u128>(&price_x_cumulative0);
        Debug::print<u128>(&price_y_cumulative0);
    }
}
// check: EXECUTED