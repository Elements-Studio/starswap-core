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

    use SwapAdmin::YieldFarmingV3 as YieldFarming;

    struct STARWrapper has copy, drop, store {}

    struct PoolType_A has copy, drop, store {}

    struct AssetType_A has copy, drop, store { value: u128 }

    struct GovModfiyParamCapability has key, store {
        cap: YieldFarming::ParameterModifyCapability<PoolType_A, AssetType_A>,
    }

    struct StakeCapbabilityList has key, store {
        items: vector<YieldFarming::HarvestCapability<PoolType_A, AssetType_A>>
    }

    public fun initialize(signer: &signer, treasury: Token::Token<STARWrapper>) {
        YieldFarming::initialize<PoolType_A, STARWrapper>(signer, treasury);
        YieldFarming::initialize_global_pool_info<PoolType_A>(signer, 800000000u128);
        let alloc_point = 10;
        let asset_cap = YieldFarming::add_asset_v2<PoolType_A, AssetType_A>(signer, alloc_point, 0);
        move_to(signer, GovModfiyParamCapability{
            cap: asset_cap,
        });
    }

    // only admin call
    public fun update_pool(signer: &signer,  alloc_point: u128, last_alloc_point: u128) acquires GovModfiyParamCapability {
        let user_addr = Signer::address_of(signer);
        let cap = borrow_global<GovModfiyParamCapability>(user_addr);
        YieldFarming::update_pool<PoolType_A, STARWrapper, AssetType_A>(
            &cap.cap,
            @SwapAdmin,
            alloc_point,
            last_alloc_point);
    }

    public fun stake_v2(signer: &signer, asset_amount: u128, asset_weight: u128, weight_factor: u64, deadline: u64): u64
    acquires GovModfiyParamCapability, StakeCapbabilityList {
        let cap = borrow_global_mut<GovModfiyParamCapability>(@SwapAdmin);
        let (harvest_cap, stake_id) = YieldFarming::stake_v2<PoolType_A, STARWrapper, AssetType_A>(
            signer,
            @SwapAdmin,
            AssetType_A{ value : asset_amount },
            asset_weight,
            asset_amount,
            weight_factor,
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
        assert!(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList>(Signer::address_of(signer));
        let cap = Vector::remove(&mut cap_list.items, id - 1);
        let (asset, token) = YieldFarming::unstake<PoolType_A, STARWrapper, AssetType_A>(signer, @SwapAdmin, cap);
        let token_val = Token::value<STARWrapper>(&token);
        Account::deposit<STARWrapper>(Signer::address_of(signer), token);
        (asset.value, token_val)
    }

    public fun harvest(signer: &signer, id: u64): Token::Token<STARWrapper> acquires StakeCapbabilityList {
        assert!(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList>(Signer::address_of(signer));
        let cap = Vector::borrow(&cap_list.items, id - 1);
        YieldFarming::harvest<PoolType_A, STARWrapper, AssetType_A>(Signer::address_of(signer), @SwapAdmin, 0, cap)
    }

    public fun query_expect_gain(user_addr: address, id: u64): u128 acquires StakeCapbabilityList {
        let cap_list = borrow_global_mut<StakeCapbabilityList>(user_addr);
        let cap = Vector::borrow(&cap_list.items, id - 1);
        YieldFarming::query_expect_gain<PoolType_A, STARWrapper, AssetType_A>(user_addr, @SwapAdmin, cap)
    }

    public fun query_stake_list(user_addr: address): vector<u64> {
        YieldFarming::query_stake_list<PoolType_A, AssetType_A>(user_addr)
    }

    public fun query_pool_info_v2(): (u128, u128, u128, u128) {
        YieldFarming::query_pool_info_v2<PoolType_A, AssetType_A>(@SwapAdmin)
    }

    public fun print_query_info_v2() {
        let (alloc_point, asset_total_amount, asset_total_weight, harvest_index) = query_pool_info_v2();

        Debug::print(&1000110001);
        Debug::print(&alloc_point);
        Debug::print(&asset_total_amount);
        Debug::print(&asset_total_weight);
        Debug::print(&harvest_index);
        Debug::print(&1000510005);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10001000


//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;

    use SwapAdmin::YieldFarmingWrapper::{STARWrapper};
    use SwapAdmin::CommonHelper;

    /// Initial reward token, registered and mint it
    fun accept_and_deposit(signer: signer) {
        // Resister and mint STARWrapper
        Token::register_token<STARWrapper>(&signer, 9u8);
        Account::do_accept_token<STARWrapper>(&signer);

        let star_token = Token::mint<STARWrapper>(&signer, CommonHelper::pow_amount<STARWrapper>(100000000));
        Account::deposit_to_self(&signer, star_token);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin

script {
    use StarcoinFramework::Account;
    use SwapAdmin::YieldFarmingWrapper::{STARWrapper, Self};
    use SwapAdmin::CommonHelper;

    /// Inital token into yield farming treasury
    fun init_token_into_treasury(account: signer) {
        let star_amount = CommonHelper::pow_amount<STARWrapper>(10000);

        let treasury = Account::withdraw(&account, star_amount);
        YieldFarmingWrapper::initialize(&account, treasury);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapConfig;

    //TODO remove the testcase after upgrade
    fun upgrade_for_turned_on_alloc_mode(signer: signer) {
        // open the upgrade switch
        TokenSwapConfig::set_alloc_mode_upgrade_switch(&signer, true);
        assert!(TokenSwapConfig::get_alloc_mode_upgrade_switch(), 1002);
    }
}
// check: EXECUTED


//# run --signers alice

script {
    use StarcoinFramework::Account;

    use SwapAdmin::YieldFarmingWrapper::{STARWrapper, Self};
    use SwapAdmin::CommonHelper;

    /// Alice joined and staking some asset
    fun stake_token_to_pool(signer: signer) {
        // Alice accept STARWrapper
        Account::do_accept_token<STARWrapper>(&signer);

        //when pool type = farm, boost factor == 1.0, then weight_factor = 100
        let asset_amount = CommonHelper::pow_amount<STARWrapper>(1);
        let asset_weight = asset_amount * 1;
        let stake_id = YieldFarmingWrapper::stake_v2(&signer, asset_amount, asset_weight, 100, 0);
        assert!(stake_id == 1, 1005);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10002000

//# run --signers alice
script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Signer;

    use SwapAdmin::YieldFarmingWrapper::{Self};

    /// Alice harvest after 1 seconds, checking whether has rewards.
    fun alice_query_token_amount(signer: signer) {
        let expect_amount = YieldFarmingWrapper::query_expect_gain(Signer::address_of(&signer), 1);
        Debug::print(&expect_amount);
        let lp_release_per_second = 800000000;
        assert!(expect_amount == lp_release_per_second, 1007);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10004000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;

    use SwapAdmin::YieldFarmingWrapper::{STARWrapper, Self};
    use SwapAdmin::CommonHelper;

    /// Alice harvest after 3 seconds, checking whether has rewards.
    fun alice_unstake_afeter_3_seconds(signer: signer) {
        let amount00 = YieldFarmingWrapper::query_expect_gain(Signer::address_of(&signer), 1);
        Debug::print(&amount00);

        // Unstake
        let (asset_val, token_val) = YieldFarmingWrapper::unstake(&signer, 1);
        Debug::print(&token_val);
        let lp_release_per_second = 800000000;
        assert!(asset_val == CommonHelper::pow_amount<STARWrapper>(1), 1010);
        assert!(token_val == (lp_release_per_second * 3), 1011);

        let (_, asset_total_amount, _, _) = YieldFarmingWrapper::query_pool_info_v2();
        assert!(asset_total_amount == 0, 1012);
    }
}
// check: EXECUTED

//# run --signers bob

script {
    use StarcoinFramework::Account;

    use SwapAdmin::YieldFarmingWrapper::{STARWrapper, Self};
    use SwapAdmin::CommonHelper;

    fun bob_stake_1(signer: signer) {
        Account::do_accept_token<STARWrapper>(&signer);


        // First stake operation, deadline after 60 seconds
        // when pool type = farm, boost factor == 1.0, then weight_factor = 100
        let asset_amount = CommonHelper::pow_amount<STARWrapper>(1);
        let asset_weight = asset_amount * 1;
        let stake_id = YieldFarmingWrapper::stake_v2(&signer, asset_amount, asset_weight, 100, 60);
        assert!(stake_id == 1, 10001);
    }
}
// check: EXECUTED

//# run --signers bob

script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;

    use SwapAdmin::YieldFarmingWrapper::{Self};

    /// bob harvest after 4 seconds, checking whether has rewards.
    fun bob_harvest_deadline60_after4sec_check_abort(signer: signer) {
        let amount1 = YieldFarmingWrapper::query_expect_gain(Signer::address_of(&signer), 1);
        Debug::print(&99999999);
        Debug::print(&amount1);
        let lp_release_per_second = 800000000;
        assert!(amount1 == (lp_release_per_second * 60), 10002);

        let token = YieldFarmingWrapper::harvest(&signer, 1);
        Account::deposit<YieldFarmingWrapper::STARWrapper>(Signer::address_of(&signer), token);
    }
}
// check: "Keep(ABORTED { code: 30209"

//# block --author 0x1 --timestamp 10005000

//# run --signers bob

script {
    use SwapAdmin::YieldFarmingWrapper::{STARWrapper, Self};
    use SwapAdmin::CommonHelper;

    fun bob_stake_2(signer: signer) {
        // Second stake operation, boost factor = 1.5
        // when pool type = farm, boost factor == 1.0, then weight_factor = 100
        let asset_amount = CommonHelper::pow_amount<STARWrapper>(1);
        let asset_weight = asset_amount * (150 as u128) / (100 as u128);
        let stake_id = YieldFarmingWrapper::stake_v2(&signer, asset_amount, asset_weight, 150, 0);
        assert!(stake_id == 2, 10003);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10006000

//# run --signers bob

script {
    use SwapAdmin::CommonHelper;
    use SwapAdmin::YieldFarmingWrapper::{STARWrapper, Self};

    fun bob_stake_3(signer: signer) {
        // Third stake operation, boost factor = 2.0
        // when pool type = farm, boost factor == 1.0, then weight_factor = 100
        let asset_amount = CommonHelper::pow_amount<STARWrapper>(1);
        let asset_weight = asset_amount * 2;
        let stake_id = YieldFarmingWrapper::stake_v2(&signer, asset_amount, asset_weight, 200, 0);

        assert!(stake_id == 3, 10004);
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
        Account::deposit<YieldFarmingWrapper::STARWrapper>(user_addr, token2);
        Debug::print(&amount2);
        //assert!(amount2 == 142857142, 10007);
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
        Account::deposit<YieldFarmingWrapper::STARWrapper>(Signer::address_of(&signer), token);
        Debug::print(&amount);
    }
}
// check: EXECUTED