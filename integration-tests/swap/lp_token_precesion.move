//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5 --public-keys Bridge=0x8085e172ecf785692da465ba3339da46c4b43640c3f92a45db803690cc3c4a36

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr swap_admin --amount 10000000000000000

//# faucet --addr liquidier --amount 10000000000000000

//# faucet --addr Bridge --amount 10000000000000000


//# publish
module Bridge::XUSDT {
    struct XUSDT {}
}

//# publish
module alice::coin_mock {
    use starcoin_framework::managed_coin;
    use starcoin_std::type_info::{struct_name, type_of};

    struct WUSDT {}

    struct WDAI {}

    struct WDOT {}

    struct WBTC {}

    struct WETH {}

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

//# run --signers alice
script {
    use alice::coin_mock::{Self, WBTC, WDAI, WDOT, WETH};

    fun init_token(alice: &signer) {
        coin_mock::initialize<WETH>(alice, 12);
        coin_mock::initialize<WDAI>(alice, 12);
        coin_mock::initialize<WBTC>(alice, 12);
        coin_mock::initialize<WDOT>(alice, 9);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use swap_admin::CommonHelper::{pow_amount, safe_mint};
    use alice::coin_mock::{WBTC, WDAI, WDOT, WETH};

    fun init_account(alice: &signer) {
        safe_mint<WETH>(alice, pow_amount<WETH>(10_000_000));
        safe_mint<WDAI>(alice, pow_amount<WDAI>(600_000));
        safe_mint<WBTC>(alice, pow_amount<WBTC>(6_000_000));
        safe_mint<WDOT>(alice, pow_amount<WDOT>(600_000));
    }
}
// check: EXECUTED

//# run --signers swap_admin
script {
    use swap_admin::TokenSwapFee;

    fun init_token_swap_fee(swap_admin: signer) {
        TokenSwapFee::initialize_token_swap_fee(&swap_admin);
    }
}
// check: EXECUTED


//# run --signers Bridge
script {
    use std::signer;
    use Bridge::XUSDT::XUSDT;
    use swap_admin::CommonHelper::pow_amount;

    use starcoin_std::type_info::{struct_name, type_of};

    use starcoin_framework::managed_coin;
    use starcoin_framework::coin;

    fun fee_token_init(bridge_admin: &signer) {
        // Token::register_token<XUSDT>(&bridge_admin, 9);
        managed_coin::initialize<XUSDT>(
            bridge_admin,
            struct_name(&type_of<XUSDT>()),
            struct_name(&type_of<XUSDT>()),
            9,
            true,
        );
        coin::register<XUSDT>(bridge_admin);
        managed_coin::mint<XUSDT>(
            bridge_admin,
            signer::address_of(bridge_admin),
            (pow_amount<XUSDT>(500000) as u64)
        );
    }
}
// check: EXECUTED


//# run --signers swap_admin
script {
    use alice::coin_mock::{WBTC, WDAI, WDOT, WETH};
    use swap_admin::TokenSwapRouter;

    use starcoin_framework::starcoin_coin::STC;

    fun register_token_pair(swap_admin: signer) {
        //token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<STC, WETH>(&swap_admin);
        TokenSwapRouter::register_swap_pair<WETH, WDAI>(&swap_admin);
        TokenSwapRouter::register_swap_pair<WBTC, STC>(&swap_admin);
        TokenSwapRouter::register_swap_pair<STC, WDOT>(&swap_admin);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use std::signer;
    use starcoin_framework::starcoin_coin::STC;
    use starcoin_std::debug;

    use swap_admin::TokenSwapRouter;
    use alice::coin_mock::WDOT;
    use swap_admin::CommonHelper::pow_amount;

    fun add_liquidity_precision_9(alice: &signer) {
        // let scaling_factor_9 = Math::pow(10, 9);
        debug::print(&200200);
        let alice_addr = signer::address_of(alice);

        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC, WDOT>(
            alice,
            2000000,
            50000000,
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<STC, WDOT>(alice_addr);
        debug::print(&liquidity);

        TokenSwapRouter::add_liquidity<STC, WDOT>(
            alice,
            pow_amount<STC>(20),
            pow_amount<WDOT>(5),
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<STC, WDOT>(alice_addr);
        debug::print(&liquidity);

        TokenSwapRouter::add_liquidity<STC, WDOT>(
            alice,
            pow_amount<STC>(20000),
            pow_amount<WDOT>(5000),
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<STC, WDOT>(alice_addr);
        debug::print(&liquidity);

        TokenSwapRouter::add_liquidity<STC, WDOT>(
            alice,
            pow_amount<STC>(600000),
            pow_amount<WDOT>(8000),
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<STC, WDOT>(alice_addr);
        debug::print(&liquidity);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use std::signer;
    use starcoin_std::debug;

    use swap_admin::TokenSwapRouter;
    use alice::coin_mock::WETH;
    use swap_admin::CommonHelper::pow_amount;

    use starcoin_framework::starcoin_coin::STC;

    fun add_liquidity(alice: &signer) {
        let alice_address = signer::address_of(alice);
        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC, WETH>(
            alice,
            20000000,
            50000000,
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<STC, WETH>(alice_address);
        debug::print(&liquidity);

        TokenSwapRouter::add_liquidity<STC, WETH>(
            alice,
            pow_amount<STC>(20),
            5000000000000000,
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<STC, WETH>(alice_address);
        debug::print(&liquidity);

        TokenSwapRouter::add_liquidity<STC, WETH>(
            alice,
            pow_amount<STC>(20000),
            pow_amount<WETH>(50),
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<STC, WETH>(alice_address);
        debug::print(&liquidity);

        TokenSwapRouter::add_liquidity<STC, WETH>(
            alice,
            pow_amount<STC>(600000),
            pow_amount<WETH>(8000),
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<STC, WETH>(alice_address);
        debug::print(&liquidity);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use std::signer;

    use starcoin_std::debug;

    // use swap_admin::CommonHelper::pow_amount;
    use swap_admin::TokenSwapRouter;
    use alice::coin_mock::{WETH, WDAI};
    use swap_admin::CommonHelper::pow_amount;

    fun add_liquidity_precesion_12(alice: &signer) {
        debug::print(&200500);
        let alice_address = signer::address_of(alice);

        assert!(TokenSwapRouter::swap_pair_exists<WETH, WDAI>(), 101);

        // for the first add liquidity
        TokenSwapRouter::add_liquidity<WETH, WDAI>(
            alice,
            20000000,
            50000000,
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<WETH, WDAI>(alice_address);
        debug::print(&liquidity);

        TokenSwapRouter::add_liquidity<WETH, WDAI>(
            alice,
            20000000000000,
            5000000000000000,
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<WETH, WDAI>(alice_address);
        debug::print(&liquidity);

        TokenSwapRouter::add_liquidity<WETH, WDAI>(
            alice,
            pow_amount<WETH>(50),
            pow_amount<WDAI>(2000),
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<WETH, WDAI>(alice_address);

        debug::print(&liquidity);
        TokenSwapRouter::add_liquidity<WETH, WDAI>(
            alice,
            pow_amount<WETH>(8000),
            pow_amount<WDAI>(400000),
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<WETH, WDAI>(alice_address);
        debug::print(&liquidity);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use std::signer;
    use starcoin_std::debug;

    use starcoin_framework::starcoin_coin::STC;
    use starcoin_framework::coin;

    use swap_admin::TokenSwapRouter;
    use alice::coin_mock::WBTC;
    use starcoin_framework::coin::balance;

    fun add_and_remove_liquidity(alice: &signer) {
        debug::print(&200600);
        let alice_address = signer::address_of(alice);

        debug::print(&balance<STC>(alice_address));
        debug::print(&balance<WBTC>(alice_address));

        // for the first add liquidity
        TokenSwapRouter::add_liquidity<STC, WBTC>(
            alice,
            20000000000000,
            1123456789987654321,
            10,
            10
        );
        let liquidity = TokenSwapRouter::liquidity<STC, WBTC>(alice_address);
        debug::print(&liquidity);
        let btc_balance = coin::balance<WBTC>(alice_address);

        TokenSwapRouter::remove_liquidity<STC, WBTC>(alice, liquidity, 10, 10);
        let liquidity = TokenSwapRouter::liquidity<STC, WBTC>(alice_address);

        debug::print(&liquidity);
        let btc_balance_2 = coin::balance<WBTC>(alice_address);

        debug::print(&(btc_balance_2 - btc_balance));
        assert!((btc_balance_2 - btc_balance) == 1123456789987654321, 2002);
    }
}
// check: EXECUTED