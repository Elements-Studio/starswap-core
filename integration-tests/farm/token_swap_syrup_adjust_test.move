//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# run --signers SwapAdmin
script {
    use SwapAdmin::UpgradeScripts;

    fun UpgradeScript_genesis_initialize_for_latest_version(signer: signer) {
        UpgradeScripts::genesis_initialize_for_latest_version(
            &signer,
            100000000,
            100000000000,
        );
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenMock::{WETH};

    fun alice_accept_token(signer: signer) {
        Account::do_accept_token<WETH>(&signer);
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
    use SwapAdmin::TokenMock::{WETH};
    use StarcoinFramework::Debug;

    fun admin_add_pool(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 9u8);

        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(100000000);

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool_v2<WETH>(&signer, 100, 0);

        let (total_alloc_point, pool_release_per_second) = TokenSwapSyrup::query_syrup_info();
        Debug::print(&pool_release_per_second);
        assert!(pool_release_per_second == CommonHelper::pow_amount<WETH>(100), 10010);
        assert!(total_alloc_point == 100, 10011);
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == 0, 10012);

        // Initialize asset such as WETH to alice's account
        Account::deposit<WETH>(@alice, TokenMock::mint_token<WETH>(powed_mint_aount));
        assert!(Account::balance<WETH>(@alice) == powed_mint_aount, 10013);

        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 1000u64, 1u64);
        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 2000u64, 2u64);
        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 3000u64, 3u64);
        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 4000u64, 4u64);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;

    fun alice_stake(signer: signer) {
        TokenSwapSyrup::stake<WETH>(
            &signer,
            1000u64,
            CommonHelper::pow_amount<WETH>(1)
        );
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == CommonHelper::pow_amount<WETH>(1), 100200);

        TokenSwapSyrup::stake<WETH>(
            &signer,
            2000u64,
            CommonHelper::pow_amount<WETH>(1)
        );
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == CommonHelper::pow_amount<WETH>(2), 100201);

        TokenSwapSyrup::stake<WETH>(
            &signer,
            3000u64,
            CommonHelper::pow_amount<WETH>(1)
        );
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == CommonHelper::pow_amount<WETH>(3), 100202);

        TokenSwapSyrup::stake<WETH>(
            &signer,
            4000u64,
            CommonHelper::pow_amount<WETH>(1)
        );
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == CommonHelper::pow_amount<WETH>(4), 100203);

        // Check multiplier pool
        let (
            _multiplier,
            asset_weight,
            asset_amount
        ) = TokenSwapSyrup::query_multiplier_pool_info<WETH>(1000);
        assert!(_multiplier == 1, 100204);
        assert!(asset_amount == CommonHelper::pow_amount<WETH>(1), 100205);
        assert!(asset_weight == CommonHelper::pow_amount<WETH>(1), 100206);

        let (
            _multiplier,
            asset_weight,
            asset_amount
        ) = TokenSwapSyrup::query_multiplier_pool_info<WETH>(2000);
        assert!(_multiplier == 2, 100207);
        assert!(asset_amount == CommonHelper::pow_amount<WETH>(1), 100208);
        assert!(asset_weight == CommonHelper::pow_amount<WETH>(2), 100209);

        let (
            _multiplier,
            asset_weight,
            asset_amount
        ) = TokenSwapSyrup::query_multiplier_pool_info<WETH>(3000);
        assert!(_multiplier == 3, 100210);
        assert!(asset_amount == CommonHelper::pow_amount<WETH>(1), 100211);
        assert!(asset_weight == CommonHelper::pow_amount<WETH>(3), 100212);


        let (
            _multiplier,
            asset_weight,
            asset_amount
        ) = TokenSwapSyrup::query_multiplier_pool_info<WETH>(4000);
        assert!(_multiplier == 4, 100213);
        assert!(asset_amount == CommonHelper::pow_amount<WETH>(1), 100214);
        assert!(asset_weight == CommonHelper::pow_amount<WETH>(4), 100215);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10002000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock::WETH;

    fun swap_admin_update_stepwise_multiplier_pool(account: signer) {
        TokenSwapSyrup::set_multiplier_pool_amount<WETH>(
            &account,
            1000,
            CommonHelper::pow_amount<WETH>(10)
        );

        TokenSwapSyrup::set_multiplier_pool_amount<WETH>(
            &account,
            2000,
            CommonHelper::pow_amount<WETH>(10)
        );

        TokenSwapSyrup::set_multiplier_pool_amount<WETH>(
            &account,
            3000,
            CommonHelper::pow_amount<WETH>(10)
        );

        TokenSwapSyrup::set_multiplier_pool_amount<WETH>(
            &account,
            4000,
            CommonHelper::pow_amount<WETH>(10)
        );

        TokenSwapSyrup::update_total_from_multiplier_pool<WETH>(&account);

        let
        (
            _alloc_point,
            asset_total_amount,
            asset_total_weight,
            _harvest_index
        ) = TokenSwapSyrup::query_pool_info_v2<WETH>();

        assert!(asset_total_amount == CommonHelper::pow_amount<WETH>(40), 100300);
        assert!(asset_total_weight == CommonHelper::pow_amount<WETH>(100), 100301);
    }
}
// check: EXECUTED


