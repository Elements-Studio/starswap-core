//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr SwapAdmin --amount 10000000000000000

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr bob --amount 10000000000000000

//# faucet --addr cindy --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# publish
module SwapAdmin::YieldFarmingWrapper {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Option;

    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::TokenSwapConfig;

    struct MockTokenType has copy, drop, store {}

    struct MockPoolType has copy, drop, store {}

    struct MockAssetType has copy, drop, store { value: u128 }

    struct GovModfiyParamCapability has key, store {
        cap: YieldFarming::ParameterModifyCapability<MockPoolType, MockAssetType>,
    }

    struct StakeCapbabilityList has key, store {
        items: vector<YieldFarming::HarvestCapability<MockPoolType, MockAssetType>>
    }

    public fun initialize_global_pool(
        account: &signer,
        treasury: Token::Token<MockTokenType>,
        release_per_second: u128
    ) {
        YieldFarming::initialize_global_pool_info<MockPoolType>(
            account,
            release_per_second
        );

        TokenSwapConfig::set_alloc_mode_upgrade_switch(account, true);
        YieldFarming::initialize<MockPoolType, MockTokenType>(account, treasury);

        let asset_cap = YieldFarming::add_asset_v2<MockPoolType, MockAssetType>(account, 50, 0);
        move_to(account, GovModfiyParamCapability {
            cap: asset_cap,
        });
    }

    public fun reset_release_per_second(
        account: &signer,
        amount: u128
    ) acquires GovModfiyParamCapability {
        YieldFarming::modify_global_release_per_second_by_admin<MockPoolType>(
            account,
            amount
        );

        let broker = Signer::address_of(account);
        let cap =
            borrow_global_mut<GovModfiyParamCapability>(broker);
        YieldFarming::update_pool_index<MockPoolType, MockTokenType, MockAssetType>(
            &cap.cap,
            broker
        );

    }

    public fun stake(
        signer: &signer,
        value: u128,
        multiplier: u64,
        deadline: u64
    ): u64 acquires GovModfiyParamCapability, StakeCapbabilityList {
        let cap = borrow_global_mut<GovModfiyParamCapability>(broker_addr());
        let (
            harvest_cap,
            stake_id
        ) = YieldFarming::stake_v2<MockPoolType, MockTokenType, MockAssetType>(
            signer,
            broker_addr(),
            MockAssetType { value },
            value * (multiplier as u128),
            value,
            multiplier,
            deadline,
            &cap.cap
        );

        let user_addr = Signer::address_of(signer);
        if (!exists<StakeCapbabilityList>(user_addr)) {
            move_to(signer, StakeCapbabilityList {
                items: Vector::empty<YieldFarming::HarvestCapability<MockPoolType, MockAssetType>>(),
            });
        };

        let cap_list = borrow_global_mut<StakeCapbabilityList>(user_addr);
        Vector::push_back(&mut cap_list.items, harvest_cap);
        stake_id
    }

    fun match_id(
        items: &vector<YieldFarming::HarvestCapability<MockPoolType, MockAssetType>>,
        id: u64
    ): Option::Option<u64> {
        let i = 0;
        while (i < Vector::length(items)) {
            let cap = Vector::borrow(items, i);
            let (stake_id, _) = YieldFarming::get_info_from_cap(cap);
            if (stake_id == id) {
                return Option::some(i)
            };
            i = i + 1;
        };
        Option::none<u64>()
    }

    public fun unstake(signer: &signer, id: u64): (u128, u128) acquires StakeCapbabilityList {
        assert!(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList>(Signer::address_of(signer));

        let idx = match_id(&cap_list.items, id);
        assert!(Option::is_some(&idx), 10001);

        let cap = Vector::remove(&mut cap_list.items, Option::destroy_some(idx));
        let (asset, token) = YieldFarming::unstake<MockPoolType, MockTokenType, MockAssetType>(signer, broker_addr(), cap);
        let token_val = Token::value<MockTokenType>(&token);
        Account::deposit<MockTokenType>(Signer::address_of(signer), token);
        (asset.value, token_val)
    }

    public fun harvest(signer: &signer, id: u64): Token::Token<MockTokenType> acquires StakeCapbabilityList {
        assert!(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList>(Signer::address_of(signer));
        let idx = match_id(&cap_list.items, id);
        assert!(Option::is_some(&idx), 10001);

        let cap = Vector::borrow(&cap_list.items, Option::destroy_some(idx));
        YieldFarming::harvest<MockPoolType, MockTokenType, MockAssetType>(
            Signer::address_of(signer),
            broker_addr(),
            0,
            cap
        )
    }

    public fun query_expect_gain(user_addr: address, id: u64): u128 acquires StakeCapbabilityList {
        let cap_list = borrow_global_mut<StakeCapbabilityList>(user_addr);
        let cap = Vector::borrow(&cap_list.items, id - 1);
        YieldFarming::query_expect_gain<MockPoolType, MockTokenType, MockAssetType>(user_addr, broker_addr(), cap)
    }

    public fun query_stake_list(user_addr: address): vector<u64> {
        YieldFarming::query_stake_list<MockPoolType, MockAssetType>(user_addr)
    }

    public fun query_info(): (u128, u128, u128, u128) {
        YieldFarming::query_pool_info_v2<MockPoolType, MockAssetType>(broker_addr())
    }

    public fun query_global_pool_info(): (u128, u128) {
        YieldFarming::query_global_pool_info<MockPoolType>(broker_addr())
    }

    fun broker_addr(): address {
        @SwapAdmin
    }

    public fun print_query_info() {
        let (
            alloc_point,
            asset_total_amount,
            asset_total_weight,
            harvest_index
        ) = query_info();

        let (
            total_alloc_point,
            release_per_second
        ) = query_global_pool_info();

        Debug::print(&b"00000000");
        Debug::print(&alloc_point);
        Debug::print(&total_alloc_point);
        Debug::print(&asset_total_amount);
        Debug::print(&asset_total_weight);
        Debug::print(&harvest_index);
        Debug::print(&release_per_second);

        Debug::print(&b"00000000");
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::YieldFarmingLibrary;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Debug;

    /// Index test
    fun yield_farming_library_test(_account: signer) {
        let harvest_index = 100;
        let last_update_timestamp: u64 = Timestamp::now_seconds() - 5;
        let _asset_total_weight = 1000000000;

        let index_1 = YieldFarmingLibrary::calculate_harvest_index(
            harvest_index,
            _asset_total_weight,
            last_update_timestamp,
            Timestamp::now_seconds(), 2000000000);
        let withdraw_1 = YieldFarmingLibrary::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
        assert!((2000000000 * 5) == withdraw_1, 1001);

        // Denominator bigger than numberator

        let index_2 = YieldFarmingLibrary::calculate_harvest_index(
            0, 100000000000000, 0, Timestamp::now_seconds() + 5, 10000000);
        let amount_2 = YieldFarmingLibrary::calculate_withdraw_amount(index_2, 0, 40000000000);
        Debug::print(&index_2);
        Debug::print(&amount_2);
        assert!(index_2 > 0, 1002);
        assert!(amount_2 > 0, 1003);
        //let withdraw_1 = YieldFarming::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
        //assert!((2000000000 * 5) == withdraw_1, 10001);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Token;
    use SwapAdmin::YieldFarmingWrapper;

    fun swap_admin_register_token(account: signer) {
        Token::register_token<YieldFarmingWrapper::MockTokenType>(&account, 9u8);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType};

    fun alice_accepte_token(signer: signer) { Account::do_accept_token<MockTokenType>(&signer); }
}
// check: EXECUTED

//# run --signers bob
script {
    use StarcoinFramework::Account;
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType};

    fun bob_accepte_token(signer: signer) { Account::do_accept_token<MockTokenType>(&signer); }
}
// check: EXECUTED

//# run --signers cindy
script {
    use StarcoinFramework::Account;
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType};

    fun cindy_accepte_token(signer: signer) { Account::do_accept_token<MockTokenType>(&signer); }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;

    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    /// Initial reward token, registered and mint it
    fun admin_init_treasury(account: signer) {
        let usdx_token = Token::mint<MockTokenType>(&account, CommonHelper::pow_amount<MockTokenType>(100000000));
        Account::deposit_to_self(&account, usdx_token);

        let usdx_amount = CommonHelper::pow_amount<MockTokenType>(100000);
        let tresury = Account::withdraw(&account, usdx_amount);
        YieldFarmingWrapper::initialize_global_pool(&account, tresury, CommonHelper::pow_amount<MockTokenType>(1));

        Account::deposit(@alice, Token::mint<MockTokenType>(&account, CommonHelper::pow_amount<MockTokenType>(5000)));
        Account::deposit(@bob, Token::mint<MockTokenType>(&account, CommonHelper::pow_amount<MockTokenType>(5000)));
        Account::deposit(@cindy, Token::mint<MockTokenType>(&account, CommonHelper::pow_amount<MockTokenType>(5000)));
    }
}
// check: EXECUTED

//# run --signers cindy
script {
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    /// Cindy joined and staking some asset
    fun cindy_stake_1x_token_to_pool(signer: signer) {
        //Debug::print(&Timestamp::now_seconds());
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 1, 0);
        assert!(stake_id == 1, 10010);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10001000

//# run --signers cindy
script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Signer;
    //use StarcoinFramework::Timestamp;

    use SwapAdmin::YieldFarmingWrapper;
    use SwapAdmin::CommonHelper;

    /// Cindy harvest after 1 seconds, checking whether has rewards.
    fun cindy_query_token_amount(signer: signer) {
        let expect_amount = YieldFarmingWrapper::query_expect_gain(Signer::address_of(&signer), 1);
        Debug::print(&expect_amount);
        assert!(expect_amount == CommonHelper::pow_amount<YieldFarmingWrapper::MockTokenType>(1), 10020);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10004000

//# run --signers cindy
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    /// Cindy harvest after 3 seconds, checking whether has rewards.
    fun cindy_unstake_afeter_3_seconds(signer: signer) {
        let amount00 = YieldFarmingWrapper::query_expect_gain(Signer::address_of(&signer), 1);
        Debug::print(&amount00);

        // Unstake
        let (asset_val, token_val) = YieldFarmingWrapper::unstake(&signer, 1);
        Debug::print(&token_val);
        assert!(asset_val == CommonHelper::pow_amount<MockTokenType>(1), 10030);
        assert!(token_val == CommonHelper::pow_amount<MockTokenType>(4), 10031);

        let (_, _, asset_total_weight, _) = YieldFarmingWrapper::query_info();
        assert!(asset_total_weight == 0, 10032);
    }
}
// check: EXECUTED

//# run --signers bob
script {
    //use StarcoinFramework::Account;

    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    fun bob_stake_1(signer: signer) {
        // First stake operation, 1x, deadline after 60 seconds
        let stake_id = YieldFarmingWrapper::stake(
            &signer,
            CommonHelper::pow_amount<MockTokenType>(1),
            1,
            60
        );
        assert!(stake_id == 1, 10040);
    }
}
// check: EXECUTED

//# run --signers bob
script {
    //use StarcoinFramework::Debug;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;

    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    /// bob harvest after 4 seconds, checking whether has rewards.
    fun bob_harvest_mul1x_deadline60_after4sec_check_abort(signer: signer) {
        let amount1 = YieldFarmingWrapper::query_expect_gain(Signer::address_of(&signer), 1);
        assert!(amount1 == CommonHelper::pow_amount<MockTokenType>(60), 10050);

        let token = YieldFarmingWrapper::harvest(&signer, 1);
        Account::deposit<YieldFarmingWrapper::MockTokenType>(Signer::address_of(&signer), token);
    }
}
// check: "Keep(ABORTED { code: 30209"

//# block --author 0x1 --timestamp 10005000

//# run --signers bob

script {
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    fun bob_stake_2(signer: signer) {
        // Second stake operation, 2x
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 2, 0);
        assert!(stake_id == 2, 10060);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10006000

//# run --signers bob
script {
    use SwapAdmin::CommonHelper;
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};

    fun bob_stake_3(signer: signer) {
        // Third stake operation, 3x
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 3, 0);
        assert!(stake_id == 3, 10070);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10007000

//# run --signers bob
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Debug;

    use SwapAdmin::CommonHelper;
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};

    fun bob_stake_4(signer: signer) {
        // Third stake operation, 1x
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 1, 0);
        assert!(stake_id == 4, 10080);

        let stake_id_list = YieldFarmingWrapper::query_stake_list(Signer::address_of(&signer));
        Debug::print(&stake_id_list);
        assert!(Vector::length(&stake_id_list) == 4, 10081);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10008000

//# run --signers bob

script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;

    use SwapAdmin::YieldFarmingWrapper;

    fun bob_harvest_2(signer: signer) {
        let user_addr = Signer::address_of(&signer);

        // token 2 amount is (2 / 7) * 3 = 0.8571428571
        let token2 = YieldFarmingWrapper::harvest(&signer, 2);
        let amount2 = Token::value(&token2);
        Account::deposit<YieldFarmingWrapper::MockTokenType>(user_addr, token2);
        Debug::print(&amount2);
        //assert!(amount2 == 142857142, 10090);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10009000

//# run --signers bob
script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;

    use SwapAdmin::YieldFarmingWrapper;

    fun bob_harvest_3(signer: signer) {
        let token = YieldFarmingWrapper::harvest(&signer, 3);
        let amount = Token::value(&token);
        Account::deposit<YieldFarmingWrapper::MockTokenType>(Signer::address_of(&signer), token);
        Debug::print(&amount);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10010000

//# run --signers bob
script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;

    use SwapAdmin::YieldFarmingWrapper;

    fun bob_harvest_4(signer: signer) {
        let token = YieldFarmingWrapper::harvest(&signer, 4);
        let amount = Token::value(&token);
        Account::deposit<YieldFarmingWrapper::MockTokenType>(Signer::address_of(&signer), token);
        Debug::print(&amount);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 11000000

//# run --signers bob
script {
    use StarcoinFramework::Debug;

    use SwapAdmin::YieldFarmingWrapper;

    fun bob_unstake_all(signer: signer) {
        let (asset_1, token_1) = YieldFarmingWrapper::unstake(&signer, 1);
        let (asset_2, token_2) = YieldFarmingWrapper::unstake(&signer, 2);
        let (asset_3, token_3) = YieldFarmingWrapper::unstake(&signer, 3);
        let (asset_4, token_4) = YieldFarmingWrapper::unstake(&signer, 4);
        Debug::print(&asset_1);
        Debug::print(&token_1);
        Debug::print(&asset_2);
        Debug::print(&token_2);
        Debug::print(&asset_3);
        Debug::print(&token_3);
        Debug::print(&asset_4);
        Debug::print(&token_4);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::YieldFarmingWrapper;
    use SwapAdmin::CommonHelper;

    fun swap_admin_reset_release_per_second(signer: signer) {
        YieldFarmingWrapper::reset_release_per_second(
            &signer,
            CommonHelper::pow_amount<YieldFarmingWrapper::MockTokenType>(10)
        );
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    fun alice_stake_after_modify_release_per_second(signer: signer) {
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 1, 0);
        assert!(stake_id == 1, 10110);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 11001000

//# run --signers alice
script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;

    use SwapAdmin::YieldFarmingWrapper;
    use SwapAdmin::CommonHelper;

    fun alice_harvest_after_reset_relese_per_second(signer: signer) {
        let token = YieldFarmingWrapper::harvest(&signer, 1);
        let amount = Token::value(&token);
        Account::deposit<YieldFarmingWrapper::MockTokenType>(Signer::address_of(&signer), token);
        Debug::print(&amount);
        assert!(amount == CommonHelper::pow_amount<YieldFarmingWrapper::MockTokenType>(10), 10120);
    }
}
// check: EXECUTED