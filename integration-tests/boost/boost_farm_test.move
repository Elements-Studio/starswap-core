//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 1646445600000


//# run --signers SwapAdmin
script {
    use SwapAdmin::UpgradeScripts;

    fun UpgradeScript_genesis_initialize_for_latest_version(signer: signer) {
        UpgradeScripts::genesis_initialize_for_latest_version(
            &signer,
            1000000000,
            10000000000,
        );
    }
}

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::STAR;

    fun alice_accept_token(signer: signer) {
        Account::do_accept_token<WETH>(&signer);
        Account::do_accept_token<STAR::STAR>(&signer);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;

    use SwapAdmin::TokenMock;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapGovPoolType::{
    PoolTypeCommunity,
    PoolTypeSyrup
    };
    use SwapAdmin::TokenMock::{WETH, WBTC, WDAI};

    fun admin_initialize(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 9u8);
        TokenMock::register_token<WBTC>(&signer, 9u8);
        TokenMock::register_token<WDAI>(&signer, 9u8);

        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(1000000);

        TokenSwapGov::dispatch<PoolTypeCommunity>(&signer, @SwapAdmin, powed_mint_aount);

        TokenSwapSyrup::deposit<PoolTypeSyrup, STAR::STAR>(
            &signer,
            Account::withdraw<STAR::STAR>(
                &signer,
                powed_mint_aount
            )
        );

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool_v2<WETH>(&signer, 100, 0);

        // Initialize asset such as WETH to alice's account
        CommonHelper::safe_mint<WETH>(&signer, powed_mint_aount);
        Account::deposit<WETH>(@alice, TokenMock::mint_token<WETH>(powed_mint_aount));

        CommonHelper::safe_mint<WDAI>(&signer, powed_mint_aount);
        Account::deposit<WDAI>(@alice, TokenMock::mint_token<WDAI>(powed_mint_aount));

        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 1u64, 1u64);
        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 2u64, 1u64);

        TokenSwapRouter::register_swap_pair<WBTC, WETH>(&signer);
        TokenSwapRouter::register_swap_pair<WDAI, WETH>(&signer);

        // Resister and mint BTC and deposit to alice
        CommonHelper::safe_mint<WBTC>(
            &signer,
            CommonHelper::pow_amount<WBTC>(100000000)
        );

        Account::deposit<WBTC>(
            @alice,
            TokenMock::mint_token<WBTC>(CommonHelper::pow_amount<WBTC>(100000000))
        );

        // Resister and mint ETH and deposit to alice
        CommonHelper::safe_mint<WETH>(
            &signer,
            CommonHelper::pow_amount<WETH>(100000000)
        );
        Account::deposit<WETH>(
            @alice,
            TokenMock::mint_token<WETH>(100000000)
        );

        // Resister and mint DAI and deposit to alice
        CommonHelper::safe_mint<WDAI>(
            &signer,
            CommonHelper::pow_amount<WDAI>(100000000)
        );
        Account::deposit<WDAI>(
            @alice,
            TokenMock::mint_token<WDAI>(100000000)
        );

        let amount_btc_desired: u128 = CommonHelper::pow_amount<WBTC>(1000);
        let amount_eth_desired: u128 = CommonHelper::pow_amount<WBTC>(8000);
        let amount_btc_min: u128 = CommonHelper::pow_amount<WBTC>(1);
        let amount_eth_min: u128 = CommonHelper::pow_amount<WETH>(1);
        TokenSwapRouter::add_liquidity<TokenMock::WBTC, WETH>(
            &signer,
            amount_btc_desired,
            amount_eth_desired,
            amount_btc_min,
            amount_eth_min
        );
        TokenSwapFarmRouter::add_farm_pool_v2<TokenMock::WBTC, WETH>(&signer, 100);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Signer;

    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH, WDAI};
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::CommonHelper;

    fun add_liquidity(signer: signer) {
        let amount_btc_desired: u128 = CommonHelper::pow_amount<WBTC>(2000);
        let amount_eth_desired: u128 = CommonHelper::pow_amount<WETH>(16000);
        let amount_btc_min: u128 = CommonHelper::pow_amount<WBTC>(1);
        let amount_eth_min: u128 = CommonHelper::pow_amount<WETH>(1);

        TokenSwapRouter::add_liquidity<WBTC, WETH>(
            &signer,
            amount_btc_desired,
            amount_eth_desired,
            amount_btc_min,
            amount_eth_min
        );
        let amount_dai_desired: u128 = CommonHelper::pow_amount<WDAI>(200000);
        let amount_dai_min: u128 = CommonHelper::pow_amount<WETH>(1);
        TokenSwapRouter::add_liquidity<WDAI, WETH>(
            &signer,
            amount_dai_desired,
            amount_eth_desired,
            amount_dai_min,
            amount_eth_min
        );
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, liquidity_amount);
    }
}
// check: EXECUTED

//
//
// //# run --signers SwapAdmin
// script {
//     use SwapAdmin::UpgradeScripts;
//     use SwapAdmin::TokenMock::{WBTC, WETH};
//
//     fun upgrade_for_extend_farm_pool(signer: signer) {
//         UpgradeScripts::extend_farm_pool<WBTC, WETH>(signer, false)
//     }
// }
// // check: EXECUTED
//
// //# run --signers SwapAdmin
// script {
//     use SwapAdmin::TokenSwapConfig;
//     use SwapAdmin::UpgradeScripts;
//     use SwapAdmin::CommonHelper;
//     use SwapAdmin::TokenSwapFarmBoost;
//     use SwapAdmin::STAR;
//
//     fun admin_turned_on_alloc_mode_and_init_upgrade(signer: signer) {
//         // open the upgrade switch
//         TokenSwapConfig::set_alloc_mode_upgrade_switch(&signer, true);
//         assert!(TokenSwapConfig::get_alloc_mode_upgrade_switch(), 100011);
//
//         TokenSwapFarmBoost::initialize_boost_event(&signer);
//         // upgrade for global init
//         UpgradeScripts::initialize_global_syrup_info(signer, CommonHelper::pow_amount<STAR::STAR>(10));
//     }
// }
// // check: EXECUTED

// //# run --signers SwapAdmin
// script {
//     use StarcoinFramework::Debug;
//
//     use SwapAdmin::TokenMock;
//     use SwapAdmin::TokenSwapSyrup;
//
//     fun upgrade_pool_for_weth(signer: signer) {
//         TokenSwapSyrup::extend_syrup_pool<WETH>(&signer, false);
//         let (alloc_point, _, _, _) = TokenSwapSyrup::query_pool_info_v2<WETH>();
//         Debug::print(&alloc_point);
//         assert!(alloc_point == 50, 10012);
//     }
// }
// // check: EXECUTED

//# block --author 0x1 --timestamp 1646445602000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenMock::{WETH};

    fun add_pledage_time_multiplier(signer: signer) {
        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 3600, 1);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::TokenSwapSyrupScript;

    fun alice_stake_all_flow(signer: signer) {
        TokenSwapSyrupScript::stake<WETH>(signer, 3600, 10000000000);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp   1646450600000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun alice_stake_unall_flow(signer: signer) {
        let account = Signer::address_of(&signer);
        TokenSwapFarmRouter::boost<WBTC, WETH>(&signer, 570775);

        assert!(TokenSwapVestarMinter::value(account) > 0, 10010);
        TokenSwapSyrupScript::stake<WETH>(signer, 3600, 10000000000);
        Debug::print(&TokenSwapVestarMinter::value(account));
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Signer;

    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun alice_stake_unall_flow(signer: signer) {
        let account = Signer::address_of(&signer);

        assert!(TokenSwapFarmBoost::get_boost_factor<WBTC, WETH>(account) == 249, 10010);
        TokenSwapFarmRouter::harvest<WBTC, WETH>(&signer, 100);
        assert!(TokenSwapFarmBoost::get_boost_factor<WBTC, WETH>(account) == 174, 10011);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun vestar_query(signer: signer) {
        let account = Signer::address_of(&signer);
        let farm_boost_vestar = TokenSwapFarmRouter::get_boost_locked_vestar_amount<WBTC, WETH>(account);
        let farm_boost_vestar_reverse = TokenSwapFarmRouter::get_boost_locked_vestar_amount<WETH, WBTC>(account);

        assert!(farm_boost_vestar > 0, 10012);
        assert!(farm_boost_vestar == farm_boost_vestar_reverse, 10013);
    }
}
// check: EXECUTED