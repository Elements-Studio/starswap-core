//! account: alice, 100000000000000000 0x1::STC::STC
//! account: bob
//! account: cindy
//! account: davied
//! account: joe

//! new-transaction
//! sender: alice
address alice = {{alice}};
module alice::YieldFarmingWarpper {
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::Debug;

    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;
    use 0x8c109349c6bd91411d6bc962e080c4a3::YieldFarmingV3 as YieldFarming;

    struct Usdx has copy, drop, store {}

    struct PoolType_A has copy, drop, store {}

    struct AssetType_A has copy, drop, store { value: u128 }

    struct GovModfiyParamCapability has key, store {
        cap: YieldFarming::ParameterModifyCapability<PoolType_A, AssetType_A>,
    }

    struct StakeCapbabilityList has key, store {
        items: vector<YieldFarming::HarvestCapability<PoolType_A, AssetType_A>>
    }

    public fun initialize(signer: &signer, treasury: Token::Token<Usdx>) {
        YieldFarming::initialize<PoolType_A, Usdx>(signer, treasury);
        let release_per_second = CommonHelper::pow_amount<Usdx>(1);
        let asset_cap = YieldFarming::add_asset<PoolType_A, AssetType_A>(signer, release_per_second, 0);
        move_to(signer, GovModfiyParamCapability{
            cap: asset_cap,
        });
    }

    public fun stake(signer: &signer, value: u128, multiplier: u64, deadline: u64): u64
    acquires GovModfiyParamCapability, StakeCapbabilityList {
        let cap = borrow_global_mut<GovModfiyParamCapability>(@alice);
        let (harvest_cap, stake_id) = YieldFarming::stake<PoolType_A, Usdx, AssetType_A>(
            signer,
            @alice,
            AssetType_A{ value },
            value,
            multiplier,
            deadline,
            &cap.cap);

        let user_addr = Signer::address_of(signer);
        if (!exists<StakeCapbabilityList>(user_addr)) {
            move_to(signer, StakeCapbabilityList{
                items: Vector::empty<YieldFarming::HarvestCapability<PoolType_A, AssetType_A>>(),
            });
        };

        let cap_list = borrow_global_mut<StakeCapbabilityList>(user_addr);
        Vector::push_back(&mut cap_list.items, harvest_cap);
        stake_id
    }

    public fun unstake(signer: &signer, id: u64): (u128, u128) acquires StakeCapbabilityList {
        assert(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList>(Signer::address_of(signer));
        let cap = Vector::remove(&mut cap_list.items, id - 1);
        let (asset, token) = YieldFarming::unstake<PoolType_A, Usdx, AssetType_A>(signer, @alice, cap);
        let token_val = Token::value<Usdx>(&token);
        Account::deposit<Usdx>(Signer::address_of(signer), token);
        (asset.value, token_val)
    }

    public fun harvest(signer: &signer, id: u64): Token::Token<Usdx> acquires StakeCapbabilityList {
        assert(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList>(Signer::address_of(signer));
        let cap = Vector::borrow(&cap_list.items, id - 1);
        YieldFarming::harvest<PoolType_A, Usdx, AssetType_A>(Signer::address_of(signer), @alice, 0, cap)
    }

    public fun query_expect_gain(user_addr: address, id: u64): u128 acquires StakeCapbabilityList {
        let cap_list = borrow_global_mut<StakeCapbabilityList>(user_addr);
        let cap = Vector::borrow(&cap_list.items, id - 1);
        YieldFarming::query_expect_gain<PoolType_A, Usdx, AssetType_A>(user_addr, @alice, cap)
    }

    public fun query_stake_list(user_addr: address): vector<u64> {
        YieldFarming::query_stake_list<PoolType_A, AssetType_A>(user_addr)
    }

    public fun query_info(): (bool, u128, u128, u128) {
        YieldFarming::query_info<PoolType_A, AssetType_A>(@alice)
    }

    public fun print_query_info() {
        let (
            _,
            release_per_second,
            asset_total_weight,
            harvest_index
        ) = query_info();

        Debug::print(&1000110001);
        Debug::print(&release_per_second);
        Debug::print(&asset_total_weight);
        Debug::print(&harvest_index);
        Debug::print(&1000510005);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 86400000

//! new-transaction
//! sender: alice
script {
    use 0x8c109349c6bd91411d6bc962e080c4a3::YieldFarmingLibrary;
    use 0x1::Timestamp;
    use 0x1::Debug;

    /// Index test
    fun yield_farming_library_test(_account: signer) {
        let harvest_index = 100;
        let last_update_timestamp: u64 = 86395;
        let _asset_total_weight = 1000000000;

        let index_1 = YieldFarmingLibrary::calculate_harvest_index(
            harvest_index,
            _asset_total_weight,
            last_update_timestamp,
            Timestamp::now_seconds(), 2000000000);
        let withdraw_1 = YieldFarmingLibrary::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
        assert((2000000000 * 5) == withdraw_1, 1001);

        // Denominator bigger than numberator
        let index_2 = YieldFarmingLibrary::calculate_harvest_index(0, 100000000000000, 0, 5, 10000000);
        let amount_2 = YieldFarmingLibrary::calculate_withdraw_amount(index_2, 0, 40000000000);
        Debug::print(&index_2);
        Debug::print(&amount_2);
        assert(index_2 > 0, 1002);
        assert(amount_2 > 0, 1003);
        //let withdraw_1 = YieldFarming::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
        //assert((2000000000 * 5) == withdraw_1, 10001);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x1::Token;

    use alice::YieldFarmingWarpper::{Usdx};
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;

    /// Initial reward token, registered and mint it
    fun alice_accept_and_deposit(signer: signer) {
        // Resister and mint Usdx
        Token::register_token<Usdx>(&signer, 9u8);
        Account::do_accept_token<Usdx>(&signer);

        let usdx_token = Token::mint<Usdx>(&signer, CommonHelper::pow_amount<Usdx>(100000000));
        Account::deposit_to_self(&signer, usdx_token);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Account;
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;

    /// Inital token into yield farming treasury
    fun alice_init_token_into_treasury(account: signer) {
        let usdx_amount = CommonHelper::pow_amount<Usdx>(1000);

        let tresury = Account::withdraw(&account, usdx_amount);
        YieldFarmingWarpper::initialize(&account, tresury);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: cindy
address alice = {{alice}};
script {
    use 0x1::Account;
    //use 0x1::Debug;
    //use 0x1::Timestamp;

    use alice::YieldFarmingWarpper::{Usdx, Self};
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;

    /// Cindy joined and staking some asset
    fun cindy_stake_1x_token_to_pool(signer: signer) {
        // Cindy accept Usdx
        Account::do_accept_token<Usdx>(&signer);

        //Debug::print(&Timestamp::now_seconds());

        let stake_id = YieldFarmingWarpper::stake(&signer, CommonHelper::pow_amount<Usdx>(1), 1, 0);
        assert(stake_id == 1, 1008);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 86420000

//! new-transaction
//! sender: cindy
address alice = {{alice}};
script {
//    use 0x1::Debug;
    use 0x1::Signer;
    //use 0x1::Timestamp;

    use alice::YieldFarmingWarpper::{Usdx, Self};
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;

    /// Cindy harvest after 20 seconds, checking whether has rewards.
    fun cindy_query_token_amount(signer: signer) {
        let expect_amount = YieldFarmingWarpper::query_expect_gain(Signer::address_of(&signer), 1);
//        Debug::print(&111111);
//        Debug::print(&expect_amount);
//        Debug::print(&Timestamp::now_seconds());
        // assert(amount00 == 0, 10004);
        assert(expect_amount == CommonHelper::pow_amount<Usdx>(20), 1009);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 3
//! block-time: 86440000

//! new-transaction
//! sender: cindy
address alice = {{alice}};
address cindy = {{cindy}};
script {
    use 0x1::Signer;
    use 0x1::Debug;

    use alice::YieldFarmingWarpper::{Usdx, Self};
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;

    /// Cindy harvest after 40 seconds, checking whether has rewards.
    fun cindy_unstake_afeter_40_seconds(signer: signer) {
        let amount00 = YieldFarmingWarpper::query_expect_gain(Signer::address_of(&signer), 1);
        Debug::print(&amount00);

        // Unstake
        let (asset_val, token_val) = YieldFarmingWarpper::unstake(&signer, 1);
        Debug::print(&token_val);
        assert(asset_val == CommonHelper::pow_amount<Usdx>(1), 1011);
        assert(token_val == CommonHelper::pow_amount<Usdx>(40), 1010);

        let (_, _, asset_total_weight, _) = YieldFarmingWarpper::query_info();
        assert(asset_total_weight == 0, 1012);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Account;

    use alice::YieldFarmingWarpper::{Usdx, Self};
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;

    fun bob_stake_1(signer: signer) {
        Account::do_accept_token<Usdx>(&signer);

        // First stake operation, 1x, deadline after 60 seconds
        let stake_id = YieldFarmingWarpper::stake(&signer, CommonHelper::pow_amount<Usdx>(1), 1, 60);
        assert(stake_id == 1, 10001);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Debug;
    use 0x1::Signer;
    use 0x1::Account;

    use alice::YieldFarmingWarpper::{Usdx, Self};
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;

    /// bob harvest after 4 seconds, checking whether has rewards.
    fun bob_harvest_mul1x_deadline60_after4sec_check_abort(signer: signer) {
        let amount1 = YieldFarmingWarpper::query_expect_gain(Signer::address_of(&signer), 1);
        Debug::print(&99999999);
        Debug::print(&amount1);
        assert(amount1 == CommonHelper::pow_amount<Usdx>(60), 10002);

        let token = YieldFarmingWarpper::harvest(&signer, 1);
        Account::deposit<YieldFarmingWarpper::Usdx>(Signer::address_of(&signer), token);
    }
}
// check: "Keep(ABORTED { code: 30209"

//! block-prologue
//! author: genesis
//! block-number: 4
//! block-time: 86441000

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;

    fun bob_stake_2(signer: signer) {
        // Second stake operation, 2x
        let stake_id = YieldFarmingWarpper::stake(&signer, CommonHelper::pow_amount<Usdx>(1), 2, 0);
        assert(stake_id == 2, 10003);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 5
//! block-time: 86442000

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;
    use alice::YieldFarmingWarpper::{Usdx, Self};

    fun bob_stake_3(signer: signer) {
        // Third stake operation, 3x
        let stake_id = YieldFarmingWarpper::stake(&signer, CommonHelper::pow_amount<Usdx>(1), 3, 0);
        assert(stake_id == 3, 10004);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 6
//! block-time: 86443000

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::Debug;

    use 0x8c109349c6bd91411d6bc962e080c4a3::CommonHelper;
    use alice::YieldFarmingWarpper::{Usdx, Self};

    fun bob_stake_4(signer: signer) {
        // Third stake operation, 1x
        let stake_id = YieldFarmingWarpper::stake(&signer, CommonHelper::pow_amount<Usdx>(1), 1, 0);
        assert(stake_id == 4, 10005);

        let stake_id_list = YieldFarmingWarpper::query_stake_list(Signer::address_of(&signer));
        Debug::print(&stake_id_list);
        assert(Vector::length(&stake_id_list) == 4, 10006);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 7
//! block-time: 86444000

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Debug;
    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Token;

    use alice::YieldFarmingWarpper;

    fun bob_harvest_2(signer: signer) {
        let user_addr = Signer::address_of(&signer);

        // token 2 amount is (2 / 7) * 3 = 0.8571428571
        let token2 = YieldFarmingWarpper::harvest(&signer, 2);
        let amount2 = Token::value(&token2);
        Account::deposit<YieldFarmingWarpper::Usdx>(user_addr, token2);
        Debug::print(&amount2);
        //assert(amount2 == 142857142, 10007);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 8
//! block-time: 86445000

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Debug;
    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Token;

    use alice::YieldFarmingWarpper;

    fun bob_harvest_3(signer: signer) {
        let token = YieldFarmingWarpper::harvest(&signer, 3);
        let amount = Token::value(&token);
        Account::deposit<YieldFarmingWarpper::Usdx>(Signer::address_of(&signer), token);
        Debug::print(&amount);
    }
}
// check: EXECUTED
//
//! block-prologue
//! author: genesis
//! block-number: 9
//! block-time: 86446000
//
//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Debug;
    use 0x1::Signer;
    use 0x1::Account;
    use 0x1::Token;

    use alice::YieldFarmingWarpper;

    fun bob_harvest_4(signer: signer) {
        let token = YieldFarmingWarpper::harvest(&signer, 4);
        let amount = Token::value(&token);
        Account::deposit<YieldFarmingWarpper::Usdx>(Signer::address_of(&signer), token);
        Debug::print(&amount);
    }
}
// check: EXECUTED

////! new-transaction
////! sender: alice
//script {
//    use 0x8c109349c6bd91411d6bc962e080c4a3::YieldFarmingLibrary;
//    use 0x1::Timestamp;
//    use 0x1::Debug;
//
//    /// big number cacl test
//    fun alice_big_number_test(_account: signer) {
//        let harvest_index = 1000000000; //e9
//        let last_update_timestamp: u64 = 86395;
//        let _asset_total_weight = 10000000000000000000; //e19
//
//        let index_1 = YieldFarmingLibrary::calculate_harvest_index(harvest_index, _asset_total_weight, last_update_timestamp, Timestamp::now_seconds(), 2000000000);
//        let withdraw_1 = YieldFarmingLibrary::calculate_withdraw_amount(index_1, harvest_index, _asset_total_weight);
//        Debug::print(&index_1);
//        Debug::print(&withdraw_1);
//        ////        assert((2000000000 * 5) == withdraw_1, 1001);
//
//        // Denominator far greater than numberator
//        let index_2 = YieldFarmingLibrary::calculate_harvest_index(0, 1000000000000000000000, 0, 5, 10000000);
//        let amount_2 = YieldFarmingLibrary::calculate_withdraw_amount(index_2, 0, 40000000000);
//        Debug::print(&index_2);
//        Debug::print(&amount_2);
//        assert(index_2 > 0, 1010);
//        assert(amount_2 >= 0, 1011);
//    }
//}
//// check: EXECUTED
