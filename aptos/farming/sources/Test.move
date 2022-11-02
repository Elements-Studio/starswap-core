#[test_only]
module SwapAdmin::Test {

    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFee;
    use aptos_framework::account;
    use std::signer::address_of;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::STAR::STAR;
    use bridge::asset::{Self ,USDT};
    use SwapAdmin::TokenSwapGovPoolType::PoolTypeCommunity;
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::aptos_coin;
    use aptos_framework::coin;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::TokenSwap::LiquidityToken;
    use aptos_std::debug;
    use aptos_framework::coin::balance;


    #[test(sender=@SwapAdmin,framework=@aptos_framework,test1=@0x1234)]
    public fun Test(sender:&signer,framework:&signer,test1:&signer){
        timestamp::set_time_has_started_for_testing(framework);
        timestamp::update_global_time_for_test_secs(1646445600);
        let (burn_cap,mint_cap) = aptos_coin::initialize_for_test(framework);


        account::create_account_for_test(address_of(sender));
        account::create_account_for_test(address_of(test1));

        coin::register<AptosCoin>(sender);


        coin::deposit(address_of(sender), coin::mint(1000 * 1000 * 1000 * 1000 * 1000,&mint_cap));
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);


        asset::init(sender);
        asset::mint(sender, 1000 * 1000 * 1000 * 1000 * 1000);


        TokenSwapGov::genesis_initialize(sender);
        TokenSwapFee::initialize_token_swap_fee(sender);

        TokenSwapGov::linear_initialize(sender);

        assert!(coin::balance<STAR>(address_of(sender)) == 800000000000000 ,100);

        TokenSwapFarmBoost::initialize_boost_event(sender);
        TokenSwapFarm::initialize_global_pool_info(sender, 270000000);

        TokenSwapSyrupScript::initialize_global_syrup_info(sender,8000000);

        TokenSwapRouter::set_swap_fee_operation_rate(sender, 10, 60);
        TokenSwapRouter::register_swap_pair<STAR,USDT>(sender);
        TokenSwapGov::dispatch<PoolTypeCommunity>(sender, address_of(sender), 50000000000000);
        TokenSwapRouter::add_liquidity<STAR, USDT>(
            sender,
            30000000000000,
            500000000,
            5000,
            5000
        );

        TokenSwapRouter::register_swap_pair<STAR,AptosCoin>(sender);
        TokenSwapRouter::add_liquidity<STAR, AptosCoin>(
            sender,
            4000000000000,
            1000000000,
            5000,
            5000
        );

        TokenSwapRouter::register_swap_pair<AptosCoin,USDT>(sender);
        TokenSwapRouter::add_liquidity<AptosCoin, USDT>(
            sender,
            1000000000,
            70000000,
            5000,
            5000
        );


        TokenSwapFarmRouter::add_farm_pool_v2<STAR, AptosCoin>(sender, 30);
        TokenSwapFarmRouter::add_farm_pool_v2<STAR, USDT>(sender, 10);

        TokenSwapSyrup::add_pool_v2<STAR>(sender, 30, 0);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 100, 1);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 3600, 2);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 604800, 6);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 1209600, 9);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 2592000 , 12);

        coin::register<LiquidityToken<STAR,USDT>>(test1);
        coin::transfer<LiquidityToken<STAR,USDT>>(sender, address_of(test1), 10);

        coin::register<STAR>(test1);
        coin::transfer<STAR>(sender, address_of(test1), 1000000);


        TokenSwapFarmRouter::stake<STAR, USDT>(test1, 10);
        TokenSwapSyrupScript::stake<STAR>(test1, 100, 1000000);
        debug::print(&balance<STAR>(address_of(test1)));

        timestamp::update_global_time_for_test_secs(1646445701);

        let old = balance<STAR>(address_of(test1));
        TokenSwapSyrupScript::unstake<STAR>(test1, 1);
        let stake_reward = balance<STAR>(address_of(test1)) - old;
        debug::print(&stake_reward);
        assert!(stake_reward == 100 * 8000000, 10013);

        let old = balance<STAR>(address_of(test1));
        TokenSwapFarmRouter::unstake<STAR, USDT>(test1, 10);
        let farm_reward = balance<STAR>(address_of(test1)) - old;
        debug::print(&farm_reward);
    }
}
