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


    #[test(sender=@SwapAdmin,framework=@aptos_framework)]
    public fun Test(sender:&signer,framework:&signer){
        timestamp::set_time_has_started_for_testing(framework);
        timestamp::update_global_time_for_test_secs(1646445600);
        let (burn_cap,mint_cap) = aptos_coin::initialize_for_test(framework);


        account::create_account_for_test(address_of(sender));

        coin::register<AptosCoin>(sender);

        coin::deposit(address_of(sender), coin::mint(1000 * 1000 * 1000 * 1000 * 1000,&mint_cap));
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);


        asset::init(sender);
        asset::mint(sender, 1000 * 1000 * 1000 * 1000 * 1000);

        TokenSwapRouter::set_alloc_mode_upgrade_switch(sender, true);

        TokenSwapGov::genesis_initialize(sender);
        TokenSwapFee::initialize_token_swap_fee(sender);

        TokenSwapGov::linear_initialize(sender);

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

        TokenSwapFarmBoost::initialize_boost_event(sender);
        TokenSwapFarm::initialize_global_pool_info(sender, 270000000);

        TokenSwapFarmRouter::add_farm_pool_v2<STAR, AptosCoin>(sender, 30);
        TokenSwapFarmRouter::add_farm_pool_v2<STAR, USDT>(sender, 10);
        TokenSwapSyrup::initialize_global_pool_info(sender,2700000);
        TokenSwapSyrup::add_pool_v2<STAR>(sender, 30, 0);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 100, 1);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 3600, 1);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 604800, 1);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 1209600, 1);

        timestamp::update_global_time_for_test_secs(1646445610);

        TokenSwapFarmRouter::stake<STAR, USDT>(sender, 10);

    }
}
