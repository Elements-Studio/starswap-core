//! account: alice, 100000000000000000 0x1::STC::STC
//! account: bob
//! account: cindy
//! account: davied
//! account: joe

//! new-transaction
//! sender: alice
address alice = {{alice}};
module alice::CalcHelper {

    use 0x1::Math;

    public fun precision(amount: u128) :u128 {
        let scaling_factor = Math::pow(10, 9u64);
        amount * scaling_factor
    }

    public fun precision_num() : u8 {
        9u8
    }
}

//! new-transaction
//! sender: alice
address alice = {{alice}};
module alice::YieldFarmingWarpper {
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Vector;

    use alice::CalcHelper;
    // use 0x1::Debug;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::YieldFarmingV3 as YieldFarming;

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
        let release_per_second = CalcHelper::precision(1);
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
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 86400000

//! new-transaction
//! sender: alice
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::YieldFarmingLibrary;
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
    use alice::CalcHelper;

    /// Initial reward token, registered and mint it
    fun alice_accept_and_deposit(account: signer) {
        let usdx_amount = CalcHelper::precision(100000000);

        // Resister and mint Usdx
        Token::register_token<Usdx>(&account, CalcHelper::precision_num());
        Account::do_accept_token<Usdx>(&account);

        let usdx_token = Token::mint<Usdx>(&account, usdx_amount);
        Account::deposit_to_self(&account, usdx_token);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Account;

    use alice::CalcHelper;
    use alice::YieldFarmingWarpper;

    /// Inital token into yield farming treasury
    fun alice_init_token_into_treasury(account: signer) {
        let usdx_amount = CalcHelper::precision(1000);

        let tresury = Account::withdraw(&account, usdx_amount);
        YieldFarmingWarpper::initialize(&account, tresury);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: cindy
address alice = {{alice}};
script {
    use alice::CalcHelper;
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use 0x1::Account;
    use 0x1::Debug;
    use 0x1::Timestamp;

    /// Cindy joined and staking some asset
    fun cindy_stake_1x_token_to_pool(signer: signer) {
        // Cindy accept Usdx
        Account::do_accept_token<Usdx>(&signer);

        Debug::print(&Timestamp::now_seconds());

        let stake_id = YieldFarmingWarpper::stake(&signer, CalcHelper::precision(1), 1, 0);
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
    use alice::YieldFarmingWarpper;
    use alice::CalcHelper;

    use 0x1::Debug;
    use 0x1::Signer;
    use 0x1::Timestamp;

    /// Cindy harvest after 20 seconds, checking whether has rewards.
    fun cindy_query_token_amount(account: signer) {
        let expect_amount = YieldFarmingWarpper::query_expect_gain(Signer::address_of(&account), 1);
        Debug::print(&111111);
        Debug::print(&expect_amount);
        Debug::print(&Timestamp::now_seconds());
        // assert(amount00 == 0, 10004);
        assert(expect_amount == CalcHelper::precision(20), 1009);
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
    use 0x1::Account;
    use 0x1::Token;
    use 0x1::Signer;
    use 0x1::Debug;
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use alice::CalcHelper;

    /// Cindy harvest after 40 seconds, checking whether has rewards.
    fun cindy_harvest_afeter_40_seconds(signer: signer) {
        let amount00 = YieldFarmingWarpper::query_expect_gain(Signer::address_of(&signer), 1);
        Debug::print(&amount00);

        let token = YieldFarmingWarpper::harvest(&signer, 1);
        let amount1 = Token::value<Usdx>(&token);
        Debug::print(&amount1);
        assert(amount1 == CalcHelper::precision(40), 1010);
        Account::deposit<Usdx>(Signer::address_of(&signer), token);

        // Unstake
        let (asset_val, rewards_token_val) = YieldFarmingWarpper::unstake(&signer, 1);
        Debug::print(&asset_val);
        Debug::print(&rewards_token_val);
        assert(rewards_token_val == 0, 1011);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 4
//! block-time: 86500000

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Account;
    use 0x1::Signer;
    use 0x1::Vector;
    use 0x1::Debug;

    use alice::CalcHelper;
    use alice::YieldFarmingWarpper::{Usdx, Self};

    fun bob_stake_token_to_pool(signer: signer) {
        Account::do_accept_token<Usdx>(&signer);

        // First stake operation, 1x, deadline after 60 seconds
        let stake_id = YieldFarmingWarpper::stake(&signer, CalcHelper::precision(1), 1, 60);
        assert(stake_id == 1, 10001);

        // Second stake operation, 2x
        stake_id = YieldFarmingWarpper::stake(&signer, CalcHelper::precision(1), 2, 0);
        assert(stake_id == 2, 10002);

        // Third stake operation, 3x
        stake_id = YieldFarmingWarpper::stake(&signer, CalcHelper::precision(1), 3, 0);
        assert(stake_id == 3, 10003);

        // Third stake operation, 1x
        stake_id = YieldFarmingWarpper::stake(&signer, CalcHelper::precision(1), 1, 0);
        assert(stake_id == 4, 10004);

        let stake_id_list = YieldFarmingWarpper::query_stake_list(Signer::address_of(&signer));
        Debug::print(&stake_id_list);
        assert(Vector::length(&stake_id_list) == 4, 10005);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 5
//! block-time: 86504000

//! new-transaction
//! sender: bob
address alice = {{alice}};
address bob = {{bob}};
script {
    use 0x1::Token;
    use 0x1::Debug;
    use 0x1::Signer;
    use 0x1::Account;

    use alice::YieldFarmingWarpper;
    use alice::CalcHelper;

    fun bob_harvest_4th_mul1x_deadline0_after4(signer: signer) {
        let token = YieldFarmingWarpper::harvest(&signer, 4);
        let amount = Token::value<YieldFarmingWarpper::Usdx>(&token);
        Debug::print(&amount);
        Account::deposit<YieldFarmingWarpper::Usdx>(Signer::address_of(&signer), token);
        assert(amount == CalcHelper::precision(1), 10006);
    }
}
// check: EXECUTED
//
////! new-transaction
////! sender: bob
//address alice = {{alice}};
//address bob = {{bob}};
//script {
//    use 0x1::Token;
//    use 0x1::Debug;
//    use 0x1::Signer;
//    use 0x1::Account;
//    use alice::YieldFarmingWarpper;
//
//    /// bob harvest after 40 seconds, checking whether has rewards.
//    fun bob_harvest_mul1x_deadline60_after40_check_abort(signer: signer) {
//        let token = YieldFarmingWarpper::harvest(&signer, 1);
//        let amount1 = Token::value<YieldFarmingWarpper::Usdx>(&token);
//        Debug::print(&amount1);
//        assert(amount1 > 0, 1009);
//        Account::deposit<YieldFarmingWarpper::Usdx>(Signer::address_of(&signer), token);
//    }
//}
//// check: "Keep(ABORTED { code: 25863"
//
////! new-transaction
////! sender: alice
//script {
//    use 0x4783d08fb16990bd35d83f3e23bf93b8::YieldFarmingLibrary;
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
