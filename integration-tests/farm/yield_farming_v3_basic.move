//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr swap_admin --amount 10000000000000000

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr bob --amount 10000000000000000

//# faucet --addr cindy --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# publish
module swap_admin::YieldFarmingWrapper {
    use std::option;
    use std::signer;
    use std::vector;

    use starcoin_framework::coin;

    use swap_admin::YieldFarmingV3 as YieldFarming;

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
        treasury: coin::Coin<MockTokenType>,
        release_per_second: u128
    ) {
        YieldFarming::initialize_business_pool_info<MockPoolType>(
            account,
            release_per_second
        );

        // TokenSwapConfig::set_alloc_mode_upgrade_switch(account, true);
        YieldFarming::initialize<MockPoolType, MockTokenType>(account, treasury);

        let asset_cap = YieldFarming::add_asset_v2<MockPoolType, MockAssetType>(account, 100, 0);
        move_to(account, GovModfiyParamCapability {
            cap: asset_cap,
        });
    }

    public fun reset_release_per_second(
        account: &signer,
        amount: u128
    ) acquires GovModfiyParamCapability {
        YieldFarming::modify_business_release_per_second_by_admin<MockPoolType>(
            account,
            amount
        );

        let broker = signer::address_of(account);
        let cap =
            borrow_global_mut<GovModfiyParamCapability>(broker);
        YieldFarming::update_asset_pool_index<MockPoolType, MockTokenType, MockAssetType>(
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
            (value as u256) * (multiplier as u256),
            value,
            multiplier,
            deadline,
            &cap.cap
        );

        let user_addr = signer::address_of(signer);
        if (!exists<StakeCapbabilityList>(user_addr)) {
            move_to(signer, StakeCapbabilityList {
                items: vector::empty<YieldFarming::HarvestCapability<MockPoolType, MockAssetType>>(),
            });
        };

        let cap_list = borrow_global_mut<StakeCapbabilityList>(user_addr);
        vector::push_back(&mut cap_list.items, harvest_cap);
        stake_id
    }

    fun match_id(
        items: &vector<YieldFarming::HarvestCapability<MockPoolType, MockAssetType>>,
        id: u64
    ): option::Option<u64> {
        let i = 0;
        while (i < vector::length(items)) {
            let cap = vector::borrow(items, i);
            let (stake_id, _) = YieldFarming::get_info_from_cap(cap);
            if (stake_id == id) {
                return option::some(i)
            };
            i = i + 1;
        };
        option::none<u64>()
    }

    public fun unstake(signer: &signer, id: u64): (u128, u128) acquires StakeCapbabilityList {
        assert!(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList>(signer::address_of(signer));

        let idx = match_id(&cap_list.items, id);
        assert!(option::is_some(&idx), 10001);

        let cap = vector::remove(&mut cap_list.items, option::destroy_some(idx));
        let (asset, token) = YieldFarming::unstake<MockPoolType, MockTokenType, MockAssetType>(
            signer,
            broker_addr(),
            cap
        );
        let token_val = coin::value<MockTokenType>(&token);
        coin::deposit<MockTokenType>(signer::address_of(signer), token);
        (asset.value, (token_val as u128))
    }

    public fun harvest(signer: &signer, id: u64): coin::Coin<MockTokenType> acquires StakeCapbabilityList {
        assert!(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList>(signer::address_of(signer));
        let idx = match_id(&cap_list.items, id);
        assert!(option::is_some(&idx), 10001);

        let cap = vector::borrow(&cap_list.items, option::destroy_some(idx));
        YieldFarming::harvest<MockPoolType, MockTokenType, MockAssetType>(
            signer::address_of(signer),
            broker_addr(),
            0,
            cap
        )
    }

    public fun query_expect_gain(user_addr: address, id: u64): u128 acquires StakeCapbabilityList {
        let cap_list = borrow_global_mut<StakeCapbabilityList>(user_addr);
        let cap = vector::borrow(&cap_list.items, id - 1);
        YieldFarming::query_expect_gain<MockPoolType, MockTokenType, MockAssetType>(user_addr, broker_addr(), cap)
    }

    public fun query_stake_list(user_addr: address): vector<u64> {
        YieldFarming::query_stake_list<MockPoolType, MockAssetType>(user_addr)
    }

    public fun query_user_total_stake_weight(user_addr: address): u256 {
        YieldFarming::query_stake_weight<MockPoolType, MockAssetType>(user_addr)
    }

    public fun query_info(): (u64, u128, u256, u256) {
        YieldFarming::query_pool_info_v2<MockPoolType, MockAssetType>(broker_addr())
    }

    public fun query_global_pool_info(): (u64, u128) {
        YieldFarming::query_global_pool_info<MockPoolType>(broker_addr())
    }

    fun broker_addr(): address {
        @swap_admin
    }
}
// check: EXECUTED

//# run --signers swap_admin
script {
    use starcoin_framework::timestamp;
    use swap_admin::YieldFarmingLibrary;
    use starcoin_std::debug;

    /// Index test
    fun yield_farming_library_test(_account: signer) {
        let harvest_index = 100;
        let last_update_timestamp: u64 = timestamp::now_seconds() - 5;
        let _asset_total_weight = 1000000000;

        let index_1 = YieldFarmingLibrary::calculate_harvest_index(
            harvest_index,
            _asset_total_weight,
            last_update_timestamp,
            timestamp::now_seconds(), 2000000000);
        let withdraw_1 = YieldFarmingLibrary::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
        assert!((2000000000 * 5) == withdraw_1, 1001);

        // Denominator bigger than numberator
        let index_2 = YieldFarmingLibrary::calculate_harvest_index(
            0,
            100000000000000,
            0,
            timestamp::now_seconds() + 5,
            10000000
        );
        let amount_2 = YieldFarmingLibrary::calculate_withdraw_amount(index_2, 0, 40000000000);
        debug::print(&index_2);
        debug::print(&amount_2);
        assert!(index_2 > 0, 1002);
        assert!(amount_2 > 0, 1003);
        //let withdraw_1 = YieldFarming::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
        //assert!((2000000000 * 5) == withdraw_1, 10001);
    }
}
// check: EXECUTED


//# run --signers swap_admin
script {
    use std::string;
    use starcoin_framework::coin;
    use starcoin_framework::managed_coin;

    use swap_admin::YieldFarmingWrapper::{MockTokenType};

    fun swap_admin_register_token(swap_admin: signer) {
        let name = string::utf8(b"MockTokenType");
        let symbol = string::utf8(b"MOC");
        managed_coin::initialize<MockTokenType>(
            &swap_admin,
            *string::bytes(&name),
            *string::bytes(&symbol),
            9u8,
            true,
        );
        coin::register<MockTokenType>(&swap_admin);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use starcoin_framework::coin;
    use swap_admin::YieldFarmingWrapper::MockTokenType;

    fun alice_accepte_token(signer: signer) {
        coin::register<MockTokenType>(&signer);
    }
}
// check: EXECUTED

//# run --signers bob
script {
    use starcoin_framework::coin;
    use swap_admin::YieldFarmingWrapper::MockTokenType;

    fun bob_accepte_token(signer: signer) {
        coin::register<MockTokenType>(&signer);
    }
}
// check: EXECUTED

//# run --signers cindy
script {
    use starcoin_framework::coin;
    use swap_admin::YieldFarmingWrapper::MockTokenType;

    fun cindy_accepte_token(signer: signer) {
        coin::register<MockTokenType>(&signer);
    }
}
// check: EXECUTED


//# run --signers swap_admin
script {
    use std::signer;
    use starcoin_framework::coin;

    use swap_admin::CommonHelper;
    use swap_admin::YieldFarmingWrapper::{Self, MockTokenType};

    use starcoin_framework::managed_coin;

    /// Initial reward token, registered and mint it
    fun admin_init_treasury(swap_admin: signer) {
        managed_coin::mint<MockTokenType>(
            &swap_admin,
            signer::address_of(&swap_admin),
            (CommonHelper::pow_amount<MockTokenType>(100000000) as u64),
        );

        let usdx_amount = CommonHelper::pow_amount<MockTokenType>(100000);
        let tresury = coin::withdraw<MockTokenType>(&swap_admin, (usdx_amount as u64));
        YieldFarmingWrapper::initialize_global_pool(&swap_admin, tresury, CommonHelper::pow_amount<MockTokenType>(1));

        managed_coin::mint<MockTokenType>(&swap_admin, @alice, (CommonHelper::pow_amount<MockTokenType>(5000) as u64));
        managed_coin::mint<MockTokenType>(&swap_admin, @bob, (CommonHelper::pow_amount<MockTokenType>(5000) as u64));
        managed_coin::mint<MockTokenType>(&swap_admin, @cindy, (CommonHelper::pow_amount<MockTokenType>(5000) as u64));
    }
}
// check: EXECUTED

//# run --signers cindy
script {
    use swap_admin::YieldFarmingWrapper::{Self, MockTokenType};
    use swap_admin::CommonHelper;

    /// Cindy joined and staking some asset
    fun cindy_stake_1x_token_to_pool(signer: signer) {
        //debug::print(&Timestamp::now_seconds());
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 1, 0);
        assert!(stake_id == 1, 10010);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10001000

//# run --signers cindy
script {
    use std::signer;
    use std::string;
    use starcoin_framework::debug;

    use swap_admin::YieldFarmingWrapper;
    use swap_admin::CommonHelper;

    /// Cindy harvest after 1 seconds, checking whether has rewards.
    fun cindy_query_token_amount(cindy: signer) {
        let expect_amount = YieldFarmingWrapper::query_expect_gain(signer::address_of(&cindy), 1);
        debug::print(&string::utf8(b"yield_farming_v3_basic::cindy_query_token_amount | expect_amount: "));
        debug::print(&expect_amount);
        assert!(expect_amount == CommonHelper::pow_amount<YieldFarmingWrapper::MockTokenType>(1), 10020);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10004000

//# run --signers cindy
script {
    use starcoin_framework::signer;
    use starcoin_framework::debug;

    use swap_admin::YieldFarmingWrapper::{Self, MockTokenType};
    use swap_admin::CommonHelper;

    /// Cindy harvest after 3 seconds, checking whether has rewards.
    fun cindy_unstake_afeter_3_seconds(signer: signer) {
        let amount00 = YieldFarmingWrapper::query_expect_gain(signer::address_of(&signer), 1);
        debug::print(&amount00);

        // Unstake
        let (asset_val, token_val) = YieldFarmingWrapper::unstake(&signer, 1);
        debug::print(&token_val);
        assert!(asset_val == CommonHelper::pow_amount<MockTokenType>(1), 10030);
        assert!(token_val == CommonHelper::pow_amount<MockTokenType>(4), 10031);

        let (_, _, asset_total_weight, _) = YieldFarmingWrapper::query_info();
        assert!(asset_total_weight == 0, 10032);
    }
}
// check: EXECUTED

//# run --signers bob
script {
    use swap_admin::YieldFarmingWrapper::{Self, MockTokenType};
    use swap_admin::CommonHelper;

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
    use std::signer;
    use starcoin_framework::coin;

    use swap_admin::YieldFarmingWrapper::{Self, MockTokenType};
    use swap_admin::CommonHelper;


    /// bob harvest after 4 seconds, checking whether has rewards.
    fun bob_harvest_mul1x_deadline60_after4sec_check_abort(signer: signer) {
        let amount1 = YieldFarmingWrapper::query_expect_gain(signer::address_of(&signer), 1);
        assert!(amount1 == CommonHelper::pow_amount<MockTokenType>(60), 10050);

        let token = YieldFarmingWrapper::harvest(&signer, 1);
        coin::deposit<YieldFarmingWrapper::MockTokenType>(signer::address_of(&signer), token);
    }
}
// check: "Keep(ABORTED { code: 30209"

//# block --author 0x1 --timestamp 10005000

//# run --signers bob

script {
    use swap_admin::YieldFarmingWrapper::{Self, MockTokenType};
    use swap_admin::CommonHelper;

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
    use swap_admin::CommonHelper;
    use swap_admin::YieldFarmingWrapper::{Self, MockTokenType};

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
    use starcoin_framework::signer;
    use starcoin_framework::vector;
    use starcoin_framework::debug;

    use swap_admin::CommonHelper;
    use swap_admin::YieldFarmingWrapper::{Self, MockTokenType};

    fun bob_stake_4(signer: signer) {
        // Third stake operation, 1x
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 1, 0);
        assert!(stake_id == 4, 10080);

        let stake_id_list = YieldFarmingWrapper::query_stake_list(signer::address_of(&signer));
        debug::print(&stake_id_list);
        assert!(vector::length(&stake_id_list) == 4, 10081);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10008000

//# run --signers bob

script {
    use starcoin_framework::coin;

    use std::debug;
    use std::signer;

    use swap_admin::YieldFarmingWrapper;

    fun bob_harvest_2(signer: signer) {
        let user_addr = signer::address_of(&signer);

        // token 2 amount is (2 / 7) * 3 = 0.8571428571
        let token2 = YieldFarmingWrapper::harvest(&signer, 2);
        let amount2 = coin::value(&token2);
        coin::deposit<YieldFarmingWrapper::MockTokenType>(user_addr, token2);
        debug::print(&amount2);
        //assert!(amount2 == 142857142, 10090);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10009000

//# run --signers bob
script {
    use std::debug;
    use std::signer;

    use starcoin_framework::coin;

    use swap_admin::YieldFarmingWrapper;

    fun bob_harvest_3(signer: signer) {
        let token = YieldFarmingWrapper::harvest(&signer, 3);
        let amount = coin::value(&token);
        coin::deposit<YieldFarmingWrapper::MockTokenType>(signer::address_of(&signer), token);
        debug::print(&amount);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10010000

//# run --signers bob
script {
    use starcoin_framework::debug;
    use starcoin_framework::signer;
    use starcoin_framework::coin;

    use swap_admin::YieldFarmingWrapper;

    fun bob_harvest_4(signer: signer) {
        let token = YieldFarmingWrapper::harvest(&signer, 4);
        let amount = coin::value(&token);
        coin::deposit<YieldFarmingWrapper::MockTokenType>(signer::address_of(&signer), token);
        debug::print(&amount);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 11000000

//# run --signers bob
script {
    use starcoin_framework::debug;

    use swap_admin::YieldFarmingWrapper;

    fun bob_unstake_all(signer: signer) {
        let (asset_1, token_1) = YieldFarmingWrapper::unstake(&signer, 1);
        let (asset_2, token_2) = YieldFarmingWrapper::unstake(&signer, 2);
        let (asset_3, token_3) = YieldFarmingWrapper::unstake(&signer, 3);
        let (asset_4, token_4) = YieldFarmingWrapper::unstake(&signer, 4);
        debug::print(&asset_1);
        debug::print(&token_1);
        debug::print(&asset_2);
        debug::print(&token_2);
        debug::print(&asset_3);
        debug::print(&token_3);
        debug::print(&asset_4);
        debug::print(&token_4);
    }
}
// check: EXECUTED

//# run --signers swap_admin
script {
    use swap_admin::YieldFarmingWrapper;
    use swap_admin::CommonHelper;

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
    use swap_admin::YieldFarmingWrapper::{Self, MockTokenType};
    use swap_admin::CommonHelper;

    fun alice_stake_after_modify_release_per_second(signer: signer) {
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 1, 0);
        assert!(stake_id == 1, 10110);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 11001000

//# run --signers alice
script {
    use starcoin_framework::debug;
    use starcoin_framework::signer;
    use starcoin_framework::coin;

    use swap_admin::YieldFarmingWrapper;
    use swap_admin::CommonHelper;

    fun alice_harvest_after_reset_relese_per_second(signer: signer) {
        let token = YieldFarmingWrapper::harvest(&signer, 1);
        let amount = coin::value(&token);
        coin::deposit<YieldFarmingWrapper::MockTokenType>(signer::address_of(&signer), token);
        debug::print(&amount);
        assert!((amount as u128) == CommonHelper::pow_amount<YieldFarmingWrapper::MockTokenType>(10), 10120);
    }
}
// check: EXECUTED

//# run --signers bob
script {
    use starcoin_framework::signer;
    use swap_admin::CommonHelper;
    use swap_admin::YieldFarmingWrapper;

    fun stake_from_bob(sender: signer) {
        YieldFarmingWrapper::stake(&sender, CommonHelper::pow_amount<YieldFarmingWrapper::MockTokenType>(1), 3, 0);
        let user_total_staked_weight = YieldFarmingWrapper::query_user_total_stake_weight(signer::address_of(&sender));
        assert!(
            user_total_staked_weight == (CommonHelper::pow_amount<YieldFarmingWrapper::MockTokenType>(3) as u256),
            10130
        );
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use swap_admin::CommonHelper;
    use swap_admin::YieldFarmingWrapper;
    use starcoin_framework::signer;

    fun query_stake_weight(signer: signer) {
        let (_alloc_point, _asset_total_amount, asset_total_weight, _harvest_index) = YieldFarmingWrapper::query_info();
        let user_total_staked_weight = YieldFarmingWrapper::query_user_total_stake_weight(signer::address_of(&signer));
        assert!(
            asset_total_weight == ((CommonHelper::pow_amount<YieldFarmingWrapper::MockTokenType>(1) * 4) as u256),
            10140
        );
        assert!(
            user_total_staked_weight == (CommonHelper::pow_amount<YieldFarmingWrapper::MockTokenType>(1) as u256),
            10141
        );
    }
}
// check: EXECUTED