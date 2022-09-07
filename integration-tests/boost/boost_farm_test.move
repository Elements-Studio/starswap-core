//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 1646445600000

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapGov;

    fun genesis_initialized(signer: signer) {
        TokenSwapGov::genesis_initialize(&signer);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapGov;

    fun upgrade_dao_treasury_genesis(signer: signer) {
        TokenSwapGov::upgrade_dao_treasury_genesis(signer);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenMock::WETH;

    fun alice_accept_token(signer: signer) {
        Account::do_accept_token<WETH>(&signer);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::STAR;
    use StarcoinFramework::Account;

    fun swap_admin_accept_STAR(signer: signer) {
        Account::do_accept_token<STAR::STAR>(&signer);
    }
}

//# run --signers SwapAdmin
script {

    use SwapAdmin::TokenSwapGov;

    fun linear_initialize(signer: signer) {
        TokenSwapGov::linear_initialize(&signer);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Math;

    use SwapAdmin::TokenMock;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeCommunity,
        PoolTypeSyrup
    };

    fun admin_initialize(signer: signer) {

        TokenMock::register_token<TokenMock::WETH>(&signer, 9u8);
        TokenMock::register_token<TokenMock::WBTC>(&signer, 9u8);  
        TokenMock::register_token<TokenMock::WDAI>(&signer, 9u8);
        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(1000000);

        TokenSwapGov::dispatch<PoolTypeCommunity>(&signer, @SwapAdmin, powed_mint_aount);

        TokenSwapSyrup::deposit<PoolTypeSyrup,STAR::STAR>(&signer, Account::withdraw<STAR::STAR>(&signer,powed_mint_aount));

        let release_per_second_amount = CommonHelper::pow_amount<TokenMock::WETH>(100);

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool<TokenMock::WETH>(&signer, release_per_second_amount, 0);
        TokenSwapSyrup::set_alive<TokenMock::WETH>(&signer, true);

        // Initialize asset such as WETH to alice's account
        CommonHelper::safe_mint<TokenMock::WETH>(&signer, powed_mint_aount);
        Account::deposit<TokenMock::WETH>(@alice, TokenMock::mint_token<TokenMock::WETH>(powed_mint_aount));

        TokenSwapConfig::put_stepwise_multiplier(&signer, 1u64, 1u64);
        TokenSwapConfig::put_stepwise_multiplier(&signer, 2u64, 1u64);


        TokenSwapRouter::register_swap_pair<TokenMock::WBTC, TokenMock::WETH>(&signer);
        TokenSwapRouter::register_swap_pair<TokenMock::WDAI, TokenMock::WETH>(&signer);
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
        TokenSwapFarmRouter::add_farm_pool<TokenMock::WBTC, TokenMock::WETH>(&signer, 100000000);
        TokenSwapFarmRouter::reset_farm_activation<TokenMock::WBTC, TokenMock::WETH>(&signer, true);
        TokenSwapFarmRouter::set_farm_multiplier<TokenMock::WBTC, TokenMock::WETH>(&signer, 30);

    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Math;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH, WDAI};
    use SwapAdmin::TokenSwapFarmRouter;
    use StarcoinFramework::Signer;

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

        let amount_dai_desired: u128 = 200000 * scaling_factor;
        let amount_dai_min: u128 = 1 * scaling_factor;
        TokenSwapRouter::add_liquidity<WDAI, WETH>(
            &signer,
            amount_dai_desired,
            amount_eth_desired,
            amount_dai_min,
            amount_eth_min);
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, liquidity_amount);
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
    use SwapAdmin::UpgradeScripts;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::STAR;

    fun admin_turned_on_alloc_mode_and_init_upgrade(signer: signer) {
        // open the upgrade switch
        TokenSwapConfig::set_alloc_mode_upgrade_switch(&signer, true);
        assert!(TokenSwapConfig::get_alloc_mode_upgrade_switch(), 100011);

        TokenSwapFarmBoost::initialize_boost_event(&signer);
        // upgrade for global init
        UpgradeScripts::initialize_global_syrup_info(signer, CommonHelper::pow_amount<STAR::STAR>(10));
    }
}
// check: EXECUTED



//# run --signers SwapAdmin
script {
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrup;

    fun upgrade_pool_for_weth(signer: signer) {
        TokenSwapSyrup::extend_syrup_pool<TokenMock::WETH>(&signer, false);
        let (alloc_point, _, _, _) = TokenSwapSyrup::query_pool_info_v2<TokenMock::WETH>();
        Debug::print(&alloc_point);
        assert!(alloc_point == 50, 10012);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 1646445602000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;

    fun add_pledage_time_multiplier(signer: signer) {
        TokenSwapConfig::put_stepwise_multiplier(&signer, 3600, 1);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrupScript;

    fun alice_stake_all_flow(signer: signer) {
        TokenSwapSyrupScript::stake<TokenMock::WETH>(signer, 3600, 10000000000);
    }
}
// check: EXECUTED
                                   
//# block --author 0x1 --timestamp   1646450600000

//# run --signers alice
script {
    use SwapAdmin::TokenSwapFarmRouter;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::TokenSwapVestarMinter;
    fun alice_stake_unall_flow(signer: signer) {
        let account = Signer::address_of(&signer);
        TokenSwapFarmRouter::boost<TokenMock::WBTC,TokenMock::WETH>(&signer,570775);

        assert!(TokenSwapVestarMinter::value(account) > 0, 10010);
        TokenSwapSyrupScript::stake<TokenMock::WETH>(signer, 3600, 10000000000);
        Debug::print(&TokenSwapVestarMinter::value(account));
        
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenSwapFarmRouter;
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapFarmBoost;
    
    fun alice_stake_unall_flow(signer: signer) {
        let account = Signer::address_of(&signer);

        assert!(TokenSwapFarmBoost::get_boost_factor<TokenMock::WBTC,TokenMock::WETH>(account) == 249,10010);
        TokenSwapFarmRouter::harvest<TokenMock::WBTC,TokenMock::WETH>(&signer,100);
        assert!(TokenSwapFarmBoost::get_boost_factor<TokenMock::WBTC,TokenMock::WETH>(account) == 174,10011);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenSwapFarmRouter;
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenMock;

    fun vestar_query(signer: signer) {
        let account = Signer::address_of(&signer);
        let farm_boost_vestar = TokenSwapFarmRouter::get_boost_locked_vestar_amount<TokenMock::WBTC,TokenMock::WETH>(account);
        let farm_boost_vestar_reverse = TokenSwapFarmRouter::get_boost_locked_vestar_amount<TokenMock::WETH,TokenMock::WBTC>(account);
        assert!(farm_boost_vestar > 0, 10012);
        assert!(farm_boost_vestar == farm_boost_vestar_reverse, 10013);

    }
}
// check: EXECUTED