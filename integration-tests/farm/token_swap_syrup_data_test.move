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
            1000000000,
            10000000000,
        );
    }
}

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
    //use StarcoinFramework::Account;

    use SwapAdmin::TokenMock;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenMock::{WUSDT, WETH};
    use StarcoinFramework::Debug;
    use StarcoinFramework::Account;

    fun admin_initialize(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 9u8);
        TokenMock::register_token<WUSDT>(&signer, 9u8);

        let powed_mint_aount = CommonHelper::pow_amount<STAR::STAR>(100000000);

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool_v2<WETH>(&signer, 100, 0);

        let (total_alloc_point, pool_release_per_second) = TokenSwapSyrup::query_syrup_info();
        Debug::print(&pool_release_per_second);
        assert!(pool_release_per_second == 10000000000, 10001);
        assert!(total_alloc_point == 100, 10002);
        assert!(TokenSwapSyrup::query_total_stake<WETH>() == 0, 10003);

        // Initialize asset such as WETH to alice's account
        CommonHelper::safe_mint<WETH>(&signer, powed_mint_aount);
        Account::deposit<WETH>(@alice, TokenMock::mint_token<WETH>(powed_mint_aount));
        assert!(Account::balance<WETH>(@alice) == powed_mint_aount, 10004);

        // Initialize asset such as WETH to alice's account
        CommonHelper::safe_mint<WUSDT>(&signer, powed_mint_aount);
        Account::deposit<WUSDT>(@alice, TokenMock::mint_token<WUSDT>(powed_mint_aount));
        assert!(Account::balance<WUSDT>(@alice) == powed_mint_aount, 10005);

        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 1u64, 1u64);
        TokenSwapSyrup::put_stepwise_multiplier<WETH>(&signer, 2u64, 1u64);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::CommonHelper;

    fun alice_stake(signer: signer) {
        TokenSwapSyrupScript::stake<WETH>(
            signer,
            1,
            CommonHelper::pow_amount<WETH>(100)
        );
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10001000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock::{WETH};

    fun check_amount_after_1_second(signer: signer) {
        let except_amount =
            TokenSwapSyrup::query_expect_gain<WETH>(
                Signer::address_of(&signer),
                1
            );
        Debug::print(&except_amount);
        assert!(except_amount == CommonHelper::pow_amount<STAR::STAR>(10), 10010);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10002000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::TokenSwapSyrup;

    fun append_new_pool(signer: signer) {
        TokenSwapSyrup::add_pool_v2<WUSDT>(&signer, 100, 0);
        TokenSwapSyrup::put_stepwise_multiplier<WUSDT>(&signer, 1u64, 1u64);
        TokenSwapSyrup::put_stepwise_multiplier<WUSDT>(&signer, 2u64, 1u64);

        let (
            alloc_point,
            asset_total_amount,
            asset_total_weight,
            harvest_index
        ) = TokenSwapSyrup::query_pool_info_v2<WUSDT>();

        assert!(alloc_point == 100, 10020);
        assert!(asset_total_weight == 0, 10021);
        assert!(asset_total_amount == 0, 10022);
        assert!(harvest_index == 0, 10023);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10004000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock::{WETH};
    use SwapAdmin::STAR;

    fun check_amount_after_4_second(signer: signer) {
        let except_amount =
            TokenSwapSyrup::query_expect_gain<WETH>(
                Signer::address_of(&signer),
                1
            );
        Debug::print(&except_amount);
        assert!(except_amount == CommonHelper::pow_amount<STAR::STAR>(20), 100020);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::TokenSwapSyrupScript;
    use SwapAdmin::CommonHelper;

    fun alice_stake(signer: signer) {
        TokenSwapSyrupScript::stake<WUSDT>(
            signer,
            1,
            CommonHelper::pow_amount<WUSDT>(100)
        );
    }
}
// check: EXECUTED
