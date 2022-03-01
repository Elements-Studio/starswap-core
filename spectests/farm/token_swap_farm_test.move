//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice

//# faucet --addr SwapAdmin

//# block --author 0x1 --timestamp 10000000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WETH, WBTC};

    fun admin_init_token(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 9u8);
        TokenMock::register_token<WBTC>(&signer, 9u8);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenMock::{WETH, WBTC};

    fun alice_accept_token(signer: signer) {
        Account::do_accept_token<WBTC>(&signer);
        Account::do_accept_token<WETH>(&signer);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Math;
    use SwapAdmin::TokenMock;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapRouter;

    fun admin_register_token_pair_and_mint(signer: signer) {
        //token pair register must be swap SwapAdmin account
        TokenSwapRouter::register_swap_pair<TokenMock::WBTC, TokenMock::WETH>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<TokenMock::WBTC, TokenMock::WETH>(), 1001);

        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));

        // Resister and mint BTC and deposit to alice
        CommonHelper::safe_mint<TokenMock::WBTC>(&signer, 100000000 * scaling_factor);
        Account::deposit<TokenMock::WBTC>(@alice, TokenMock::mint_token<TokenMock::WBTC>(100000000 * scaling_factor));

        // Resister and mint ETH and deposit to alice
        CommonHelper::safe_mint<TokenMock::WETH>(&signer, 100000000 * scaling_factor);
        Account::deposit<TokenMock::WETH>(@alice, TokenMock::mint_token<TokenMock::WETH>(100000000 * scaling_factor));

        let amount_btc_desired: u128 = 10 * scaling_factor;
        let amount_eth_desired: u128 = 50 * scaling_factor;
        let amount_btc_min: u128 = 1 * scaling_factor;
        let amount_eth_min: u128 = 1 * scaling_factor;
        TokenSwapRouter::add_liquidity<TokenMock::WBTC, TokenMock::WETH>(
            &signer,
            amount_btc_desired,
            amount_eth_desired,
            amount_btc_min,
            amount_eth_min);
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<TokenMock::WBTC, TokenMock::WETH>();
        assert!(total_liquidity > amount_btc_min, 1002);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_governance_genesis(signer: signer) {
        TokenSwapGov::genesis_initialize(&signer);
        TokenSwapFarmRouter::add_farm_pool<WBTC, WETH>(&signer, 100000000);
        TokenSwapFarmRouter::reset_farm_activation<WBTC, WETH>(&signer, true);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_stake(signer: signer) {
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, liquidity_amount);

        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        Debug::print(&stake_amount);
        assert!(stake_amount == liquidity_amount, 1003);

        let total_stake_amount = TokenSwapFarmRouter::query_total_stake<WBTC, WETH>();
        assert!(total_stake_amount == liquidity_amount, 1004);
    }
}

//# block --author 0x1 --timestamp 10001000

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_harvest(signer: signer) {
        TokenSwapFarmRouter::harvest<WBTC, WETH>(&signer, 0);
        let rewards_amount = Account::balance<STAR::STAR>(Signer::address_of(&signer));
        assert!(rewards_amount > 0, 1005);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10002000

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_unstake(signer: signer) {
        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        assert!(stake_amount > 0, 1006);
        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, stake_amount);
        let after_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        assert!(after_amount > 0, 1007);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::Math;
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenMock::{WBTC, WETH};
    use SwapAdmin::TokenSwapRouter;

    fun alice_add_liquidity(signer: signer) {
        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));

        let amount_btc_desired: u128 = 10 * scaling_factor;
        let amount_eth_desired: u128 = 50 * scaling_factor;
        let amount_btc_min: u128 = 1 * scaling_factor;
        let amount_eth_min: u128 = 1 * scaling_factor;

        TokenSwapRouter::add_liquidity<WBTC, WETH>(
            &signer,
            amount_btc_desired,
            amount_eth_desired,
            amount_btc_min,
            amount_eth_min);

        let liquidity: u128 = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        assert!(liquidity > amount_btc_min, 1008);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10003000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun alice_stake(signer: signer) {
        let account = Signer::address_of(&signer);
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(account);
        assert!(liquidity_amount > 0, 1009);
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, 10000);

        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        assert!(stake_amount == 10000, 1010);

        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, 10000);
        let _stake_amount1 = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        Debug::print(&_stake_amount1);
        assert!(_stake_amount1 == 20000, 1011);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10004000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun alice_unstake(signer: signer) {
        let account = Signer::address_of(&signer);
        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        assert!(stake_amount == 20000, 1020);

        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, 10000);

        let _stake_amount1 = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        assert!(_stake_amount1 == 10000, 1021);

        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, 10000);

        let _stake_amount2 = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        Debug::print(&_stake_amount2);
        assert!(_stake_amount2 == 0, 1022);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_set_release_multi_basic(signer: signer) {
        // Set to 10x
        TokenSwapFarmRouter::set_farm_multiplier<WBTC, WETH>(&signer, 10);
        let (alive, release_per_sec, _, _) = TokenSwapFarmRouter::query_info<WBTC, WETH>();
        assert!(alive, 1030);
        assert!(release_per_sec == 1000000000, 1031); // Check relesase per second

        let mutipler = TokenSwapFarmRouter::get_farm_multiplier<WBTC, WETH>();
        Debug::print(&mutipler);
        assert!(mutipler == 10, 1032);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;

    fun switch_open_to_global_freeze(signer: signer) {
        TokenSwapConfig::set_global_freeze_switch(&signer, true);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun expect_failed_after_global_freeze_lock(signer: signer) {
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, 10000);
    }
}
// check: "Keep(ABORTED { code: 26113"
