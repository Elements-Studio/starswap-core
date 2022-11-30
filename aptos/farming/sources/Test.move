#[test_only]
module SwapAdmin::Test {

    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFee;
    use aptos_framework::account;
    use std::signer::address_of;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::STAR::STAR;
    use bridge::asset::{Self ,USDC};
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
    use aptos_framework::coin::{balance, Coin};
    use SwapAdmin::TokenSwapGov::get_genesis_timestamp;

    struct AptosCoinCap has key{
        mint_cap: coin::MintCapability<AptosCoin>,
        burn_cap: coin::BurnCapability<AptosCoin>
    }


    public fun starswap_init(sender:&signer){
        TokenSwapGov::genesis_initialize(sender);
        TokenSwapFee::initialize_token_swap_fee(sender);

        TokenSwapGov::linear_initialize(sender);
        TokenSwapFarmBoost::initialize_boost_event(sender);
        TokenSwapFarm::initialize_global_pool_info(sender, 270000000);

        TokenSwapSyrupScript::initialize_global_syrup_info(sender,8000000);

        TokenSwapRouter::set_swap_fee_operation_rate(sender, 10, 60);
    }

    public fun framework_init(sender:&signer ,framework:&signer){
        timestamp::set_time_has_started_for_testing(framework);
        coin::register<AptosCoin>(sender);
        let (burn_cap,mint_cap) = aptos_coin::initialize_for_test(framework);
        move_to(sender, AptosCoinCap{
            mint_cap,
            burn_cap
        });
    }

    public fun mint_apt(sender:&signer,amount:u64):Coin<AptosCoin> acquires AptosCoinCap {
        let cap = &borrow_global<AptosCoinCap>(address_of(sender)).mint_cap;
        coin::mint(amount, cap)
    }


    #[test(sender=@SwapAdmin,framework=@aptos_framework,bridge=@bridge,test1=@0x1234)]
    public fun Test(sender:&signer,framework:&signer,bridge:&signer,test1:&signer)acquires AptosCoinCap {
        account::create_account_for_test(address_of(sender));
        account::create_account_for_test(address_of(test1));
        account::create_account_for_test(address_of(bridge));

        framework_init(sender,framework);

        coin::deposit(address_of(sender), mint_apt(sender,1000 * 1000 * 1000 * 1000 * 1000));


        timestamp::update_global_time_for_test_secs(get_genesis_timestamp());

        asset::init_usdc(bridge);
        asset::mint_usdc(bridge, 1000 * 1000 * 1000 * 1000 * 1000);

        coin::register<asset::USDC>(sender);
        coin::transfer<asset::USDC>(bridge, address_of(sender),1000 * 1000 * 1000 * 1000 * 1000);


        starswap_init(sender);
        assert!(coin::balance<STAR>(address_of(sender)) == 800000000000000 ,100);


        TokenSwapRouter::register_swap_pair<STAR,USDC>(sender);
        TokenSwapGov::dispatch<PoolTypeCommunity>(sender, address_of(sender), 50000000000000);
        TokenSwapRouter::add_liquidity<STAR, USDC>(
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

        TokenSwapRouter::register_swap_pair<AptosCoin,USDC>(sender);
        TokenSwapRouter::add_liquidity<AptosCoin, USDC>(
            sender,
            1000000000,
            70000000,
            5000,
            5000
        );


        TokenSwapFarmRouter::add_farm_pool_v2<STAR, AptosCoin>(sender, 30);
        TokenSwapFarmRouter::add_farm_pool_v2<STAR, USDC>(sender, 10);

        TokenSwapSyrup::add_pool_v2<STAR>(sender, 30, 0);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 100, 1);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 3600, 2);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 604800, 6);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 1209600, 9);
        TokenSwapSyrup::put_stepwise_multiplier<STAR>(sender, 2592000 , 12);

        coin::register<LiquidityToken<STAR,USDC>>(test1);
        coin::transfer<LiquidityToken<STAR,USDC>>(sender, address_of(test1), 10);

        coin::register<STAR>(test1);
        coin::transfer<STAR>(sender, address_of(test1), 1000000);


        TokenSwapFarmRouter::stake<STAR, USDC>(test1, 10);
        TokenSwapSyrupScript::stake<STAR>(test1, 100, 1000000);
        debug::print(&balance<STAR>(address_of(test1)));

        timestamp::update_global_time_for_test_secs(get_genesis_timestamp() + 101);



        let old = balance<STAR>(address_of(test1));
        TokenSwapFarmRouter::unstake<STAR, USDC>(test1, 10);
        let farm_reward = balance<STAR>(address_of(test1)) - old;
        debug::print(&farm_reward);
        assert!(farm_reward == 6817500000, 10214);


        timestamp::update_global_time_for_test_secs(get_genesis_timestamp() + 86400);

        let old = balance<STAR>(address_of(test1));
        TokenSwapSyrupScript::unstake<STAR>(test1, 1);
        let stake_reward = balance<STAR>(address_of(test1)) - old - 1000000;
        debug::print(&stake_reward);

        assert!(stake_reward == 691200000000, 13425);
    }
}
