//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr bob --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{Self, WETH, WBTC, WDAI};

    fun admin_init_token(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 9u8);
        TokenMock::register_token<WBTC>(&signer, 9u8);
        TokenMock::register_token<WDAI>(&signer, 9u8);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenMock::{WETH, WBTC, WDAI};

    fun alice_accept_token(signer: signer) {
        Account::do_accept_token<WBTC>(&signer);
        Account::do_accept_token<WETH>(&signer);
        Account::do_accept_token<WDAI>(&signer);
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
        TokenSwapRouter::register_swap_pair<TokenMock::WDAI, TokenMock::WETH>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<TokenMock::WDAI, TokenMock::WETH>(), 1002);

        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));

        // Resister and mint BTC and deposit to alice
        CommonHelper::safe_mint<TokenMock::WBTC>(&signer, 100000000 * scaling_factor);
        Account::deposit<TokenMock::WBTC>(@alice, TokenMock::mint_token<TokenMock::WBTC>(100000000 * scaling_factor));

        // Resister and mint ETH and deposit to alice
        CommonHelper::safe_mint<TokenMock::WETH>(&signer, 100000000 * scaling_factor);
        Account::deposit<TokenMock::WETH>(@alice, TokenMock::mint_token<TokenMock::WETH>(100000000 * scaling_factor));

        // Resister and mint DAI and deposit to alice
        CommonHelper::safe_mint<TokenMock::WDAI>(&signer, 100000000 * scaling_factor);
        Account::deposit<TokenMock::WDAI>(@alice, TokenMock::mint_token<TokenMock::WDAI>(100000000 * scaling_factor));

        let amount_btc_desired: u128 = 1000 * scaling_factor;
        let amount_eth_desired: u128 = 8000 * scaling_factor;
        let amount_btc_min: u128 = 1 * scaling_factor;
        let amount_eth_min: u128 = 1 * scaling_factor;
        TokenSwapRouter::add_liquidity<TokenMock::WBTC, TokenMock::WETH>(
            &signer,
            amount_btc_desired,
            amount_eth_desired,
            amount_btc_min,
            amount_eth_min);
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<TokenMock::WBTC, TokenMock::WETH>();
        assert!(total_liquidity > 0, 1003);

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
        TokenSwapFarmRouter::set_farm_multiplier<WBTC, WETH>(&signer, 30);
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
        assert!(stake_amount == liquidity_amount, 1004);
    }
}


//# run --signers alice
script {
    use StarcoinFramework::Math;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH, WDAI};

    fun add_liquidity(signer: signer) {
        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));
        let amount_btc_desired: u128 = 2000 * scaling_factor;
        let amount_eth_desired: u128 = 16000 * scaling_factor;
        let amount_btc_min: u128 = 1 * scaling_factor;
        let amount_eth_min: u128 = 1 * scaling_factor;
        TokenSwapRouter::add_liquidity<WBTC, WETH>(
            &signer,
            amount_btc_desired,
            amount_eth_desired,
            amount_btc_min,
            amount_eth_min);
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<WBTC, WETH>();
        assert!(total_liquidity > 0, 1005);

        let amount_dai_desired: u128 = 200000 * scaling_factor;
        let amount_dai_min: u128 = 1 * scaling_factor;
        TokenSwapRouter::add_liquidity<WDAI, WETH>(
            &signer,
            amount_dai_desired,
            amount_eth_desired,
            amount_dai_min,
            amount_eth_min);
        let total_liquidity2: u128 = TokenSwapRouter::total_liquidity<WDAI, WETH>();
        assert!(total_liquidity2 > 0, 1006);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun alice_stake_before_upgrade(signer: signer) {
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, liquidity_amount);

        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        Debug::print(&stake_amount);
        assert!(stake_amount == liquidity_amount, 1007);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_unstake_all_before_upgrade(signer: signer) {
        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, stake_amount);

        let after_stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        assert!(after_stake_amount == 0, 1010);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use SwapAdmin::UpgradeScripts;

    fun upgrade_for_farm_initialize_global_pool_info(signer: signer) {
        UpgradeScripts::initialize_global_pool_info(signer, 800000000u128)
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::UpgradeScripts;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun upgrade_for_extend_farm_pool(signer: signer) {
        UpgradeScripts::extend_farm_pool<WBTC, WETH>(signer, false)
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;

    fun upgrade_for_turned_on_alloc_mode(signer: signer) {
        // open the upgrade switch
        TokenSwapConfig::set_alloc_mode_upgrade_switch(&signer, true);
        assert!(TokenSwapConfig::get_alloc_mode_upgrade_switch(), 100011);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::UpgradeScripts;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::STAR;

    fun upgrade_for_syrup(signer: signer) {
        // upgrade for syrup global init
        UpgradeScripts::initialize_global_syrup_info(signer, CommonHelper::pow_amount<STAR::STAR>(10));
    }
}
// check: EXECUTED

////# run --signers SwapAdmin
//script {
//    use SwapAdmin::UpgradeScripts;
//    use SwapAdmin::CommonHelper;
//    use SwapAdmin::STAR;
//
//    fun upgrade_for_boost_event(signer: signer) {
//        // upgrade for syrup global init
//        UpgradeScripts::initialize_global_syrup_info(signer, CommonHelper::pow_amount<STAR::STAR>(10));
//    }
//}
//// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{WDAI, WETH};
    use SwapAdmin::TokenSwapFarmRouter;

    //add new pool
    fun add_pool_v2(signer: signer) {
        let alloc_point = 10;
        TokenSwapFarmRouter::add_farm_pool_v2<WDAI, WETH>(&signer, alloc_point);
        let (lp_alloc_point, _, _, _) = TokenSwapFarmRouter::query_info_v2<WDAI, WETH>();
        assert!(lp_alloc_point == alloc_point, 1015);
    }
}
// check: EXECUTED


//# block --author 0x1 --timestamp 10002000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenMock::{WBTC, WETH};
    use SwapAdmin::TokenSwapFarmRouter;

    fun alice_query_after_upgrade(signer: signer) {
        let lookup_gain = TokenSwapFarmRouter::lookup_gain<WBTC, WETH>(Signer::address_of(&signer));
        assert!(lookup_gain > 0, 1018);
        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        assert!(stake_amount > 0, 1019);

    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenMock::{WBTC, WETH};
    use SwapAdmin::TokenSwapFarmRouter;

    fun pool_query_after_upgrade(_signer: signer) {
        let release_per_second = TokenSwapFarmRouter::query_release_per_second<WBTC, WETH>();
        assert!(release_per_second > 0, 1020);
        let total_stake_amount = TokenSwapFarmRouter::query_total_stake<WBTC, WETH>();
        assert!(total_stake_amount > 0, 1021);
        let (total_alloc_point, pool_release_per_second) = TokenSwapFarmRouter::query_global_pool_info();
        assert!(total_alloc_point > 0, 1022);
        assert!(pool_release_per_second == 800000000u128 , 1023);

    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun alice_harvest_after_upgrade(signer: signer) {
        TokenSwapFarmRouter::harvest<WBTC, WETH>(&signer, 0);
        let rewards_amount = Account::balance<STAR::STAR>(Signer::address_of(&signer));
        assert!(rewards_amount > 0, 1027);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10038000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenMock::{WBTC, WETH};
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapRouter;

    fun alice_unstake_after_upgrade(signer: signer) {
        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        assert!(stake_amount > 0, 1028);
        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, stake_amount);
        let after_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        assert!(after_amount > 0, 1029);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun alice_stake_after_upgrade(signer: signer) {
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, liquidity_amount);

        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        Debug::print(&stake_amount);
        assert!(stake_amount == liquidity_amount, 1033);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WDAI, WETH};

    fun alice_stake_new_pool_after_upgrade(signer: signer) {
        let liquidity_amount = TokenSwapRouter::liquidity<WDAI, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::stake<WDAI, WETH>(&signer, liquidity_amount);

        let stake_amount = TokenSwapFarmRouter::query_stake<WDAI, WETH>(Signer::address_of(&signer));
        Debug::print(&stake_amount);
        assert!(stake_amount == liquidity_amount, 1036);
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

    fun admin_stake_after_upgrade(signer: signer) {
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, liquidity_amount);

        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        Debug::print(&stake_amount);
        assert!(stake_amount == liquidity_amount, 1008);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10060000

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_harvest_after_upgrade(signer: signer) {
        TokenSwapFarmRouter::harvest<WBTC, WETH>(&signer, 0);
        let rewards_amount = Account::balance<STAR::STAR>(Signer::address_of(&signer));
        assert!(rewards_amount > 0, 1042);
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
