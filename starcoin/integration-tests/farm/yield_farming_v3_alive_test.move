//# init -n test

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr bob --amount 10000000000000000

//# faucet --addr cindy --amount 10000000000000000

//# faucet --addr davied --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# publish
module alice::YieldFarmingWarpper {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Debug;

    use SwapAdmin::CommonHelper;
    use SwapAdmin::YieldFarmingV3 as YieldFarming;

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

    public fun set_alive(signer: &signer, alive: bool) acquires GovModfiyParamCapability {
        let user_addr = Signer::address_of(signer);
        let cap = borrow_global<GovModfiyParamCapability>(user_addr);
        YieldFarming::modify_parameter<PoolType_A, Usdx, AssetType_A>(
            &cap.cap,
            Signer::address_of(signer),
            CommonHelper::pow_amount<Usdx>(1),
            alive);
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
        assert!(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList>(Signer::address_of(signer));
        let cap = Vector::remove(&mut cap_list.items, id - 1);
        let (asset, token) = YieldFarming::unstake<PoolType_A, Usdx, AssetType_A>(signer, @alice, cap);
        let token_val = Token::value<Usdx>(&token);
        Account::deposit<Usdx>(Signer::address_of(signer), token);
        (asset.value, token_val)
    }

    public fun harvest(signer: &signer, id: u64): Token::Token<Usdx> acquires StakeCapbabilityList {
        assert!(id > 0, 10000);
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

//# block --author 0x1 --timestamp 10001000

//# run --signers bob
script {
    use StarcoinFramework::Account;
    use alice::YieldFarmingWarpper::{Usdx};

    /// Inital token into yield farming treasury
    fun bob_accept(signer: signer) {
        Account::do_accept_token<Usdx>(&signer);
    }
}
// check: EXECUTED

//# run --signers cindy
script {
    use StarcoinFramework::Account;
    use alice::YieldFarmingWarpper::{Usdx};

    /// Inital token into yield farming treasury
    fun cindy_accept(signer: signer) {
        Account::do_accept_token<Usdx>(&signer);
    }
}
// check: EXECUTED

//# run --signers davied
script {
    use StarcoinFramework::Account;
    use alice::YieldFarmingWarpper::{Usdx};

    /// Inital token into yield farming treasury
    fun davied_accept(signer: signer) {
        Account::do_accept_token<Usdx>(&signer);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use SwapAdmin::CommonHelper;

    /// Inital token into yield farming treasury
    fun alice_init_token_into_treasury(signer: signer) {
        // Accept token
        Token::register_token<Usdx>(&signer, 9u8);
        Account::do_accept_token<Usdx>(&signer);

        let usdx_token = Token::mint<Usdx>(&signer, CommonHelper::pow_amount<Usdx>(100000000));
        Account::deposit_to_self(&signer, usdx_token);

        Account::deposit<Usdx>(@bob, Token::mint<Usdx>(&signer, CommonHelper::pow_amount<Usdx>(1000000)));
        Account::deposit<Usdx>(@cindy, Token::mint<Usdx>(&signer, CommonHelper::pow_amount<Usdx>(1000000)));
        Account::deposit<Usdx>(@davied, Token::mint<Usdx>(&signer, CommonHelper::pow_amount<Usdx>(1000000)));

        let usdx_amount = CommonHelper::pow_amount<Usdx>(1000);

        let tresury = Account::withdraw(&signer, usdx_amount);
        YieldFarmingWarpper::initialize(&signer, tresury);
        YieldFarmingWarpper::set_alive(&signer, false);
    }
}
// check: EXECUTED

//# run --signers bob
script {
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use SwapAdmin::CommonHelper;

    fun bob_stake_1x_token_to_pool_failed(signer: signer) {
        let stake_id = YieldFarmingWarpper::stake(&signer, CommonHelper::pow_amount<Usdx>(1), 1, 0);
        assert!(stake_id == 1, 100001);
    }
}
// check: "Keep(ABORTED { code: 28929"

//# block --author 0x1 --timestamp 10002000

//# run --signers bob
script {
    use alice::YieldFarmingWarpper;

    // Except harvest_index is 0 because of pool not aliving.
    fun after_10_second_check_harvest_index(_signer: signer) {
        let (_, _, _, harvest_index) = YieldFarmingWarpper::query_info();
        assert!(harvest_index == 0, 100002);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use alice::YieldFarmingWarpper;

    fun alice_switch_to_alive(signer: signer) {
        YieldFarmingWarpper::set_alive(&signer, true);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10003000

//# run --signers bob
script {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Debug;

    use alice::YieldFarmingWarpper::{Usdx, Self};
    use SwapAdmin::CommonHelper;

    fun bob_stake_1x_token_to_pool(signer: signer) {
        let stake_id = YieldFarmingWarpper::stake(&signer, CommonHelper::pow_amount<Usdx>(1), 1, 0);
        assert!(stake_id == 1, 10004);

        // get header rewards
        let header_rewards = YieldFarmingWarpper::harvest(&signer, 1);
        let amount = Token::value<Usdx>(&header_rewards);

        Debug::print(&amount);
        Debug::print(&CommonHelper::pow_amount<Usdx>(1));
        assert!(amount == CommonHelper::pow_amount<Usdx>(1), 10005);
        Account::deposit_to_self(&signer, header_rewards);

        let (
            _,
            _,
            asset_total_weight,
            harvest_index
        ) = YieldFarmingWarpper::query_info();

        assert!(asset_total_weight == CommonHelper::pow_amount<Usdx>(1), 10006);
        assert!(harvest_index == 0, 10006); // Bob get first gain
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10004000

//# run --signers alice
script {
    use alice::YieldFarmingWarpper;

    fun alice_switch_to_unalive(signer: signer) {
        YieldFarmingWarpper::set_alive(&signer, false);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10005000

//# run --signers alice
script {
    use alice::YieldFarmingWarpper;

    fun alice_switch_to_alive(signer: signer) {
        YieldFarmingWarpper::set_alive(&signer, true);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10006000

//# run --signers bob
script {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Debug;

    use alice::YieldFarmingWarpper::{Usdx, Self};
    use SwapAdmin::CommonHelper;

    fun bob_harvest(signer: signer) {
        let harvest_token = YieldFarmingWarpper::harvest(&signer, 1);
        let amount = Token::value<Usdx>(&harvest_token);

        Debug::print(&amount);
        assert!(amount == CommonHelper::pow_amount<Usdx>(2), 10011);

        Account::deposit_to_self(&signer, harvest_token);

        // Unstake from pool
        let (asset_val, token_val) =  YieldFarmingWarpper::unstake(&signer, 1);
        assert!(asset_val == CommonHelper::pow_amount<Usdx>(1), 10012);
        assert!(token_val == 0, 10013);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10007000

//# run --signers cindy
script {
    use alice::YieldFarmingWarpper::{Usdx, Self};
    use SwapAdmin::CommonHelper;

    fun cindy_stake_1x_token_to_pool(signer: signer) {
        let stake_id = YieldFarmingWarpper::stake(&signer, CommonHelper::pow_amount<Usdx>(1), 1, 0);
        assert!(stake_id == 1, 10014);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use alice::YieldFarmingWarpper;

    fun alice_switch_to_unalive(signer: signer) {
        YieldFarmingWarpper::set_alive(&signer, false);
    }
}
// check: EXECUTED


//# run --signers cindy
script {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Debug;

    use alice::YieldFarmingWarpper::{Usdx, Self};
    use SwapAdmin::CommonHelper;

    fun cindy_harvest(signer: signer) {
        let harvest_token = YieldFarmingWarpper::harvest(&signer, 1);
        let amount = Token::value<Usdx>(&harvest_token);

        Debug::print(&amount);
        assert!(amount == CommonHelper::pow_amount<Usdx>(1), 10011);

        Account::deposit_to_self(&signer, harvest_token);
    }
}
// check: EXECUTED