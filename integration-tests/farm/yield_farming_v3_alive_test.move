//# init -n test

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr bob --amount 10000000000000000

//# faucet --addr cindy --amount 10000000000000000

//# faucet --addr davied --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# publish

//# publish
module SwapAdmin::YieldFarmingWrapper {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Debug;

    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::YieldFarmingV3;
    use SwapAdmin::TokenSwapConfig;
    use StarcoinFramework::Option;

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
            release_per_second);

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
        let account_addr = Signer::address_of(account);
        let cap = borrow_global_mut<GovModfiyParamCapability>(account_addr);
        YieldFarmingV3::modify_global_release_per_second<MockPoolType, MockAssetType>(
            &cap.cap,
            Signer::address_of(account),
            amount
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
            let (stake_id, _) = YieldFarmingV3::get_info_from_cap(cap);
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

//# block --author 0x1 --timestamp 10001000

//# run --signers bob
script {
    use StarcoinFramework::Account;
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType};

    /// Inital token into yield farming treasury
    fun bob_accept(signer: signer) {
        Account::do_accept_token<MockTokenType>(&signer);
    }
}
// check: EXECUTED

//# run --signers cindy
script {
    use StarcoinFramework::Account;
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType};

    /// Inital token into yield farming treasury
    fun cindy_accept(signer: signer) {
        Account::do_accept_token<MockTokenType>(&signer);
    }
}
// check: EXECUTED

//# run --signers davied
script {
    use StarcoinFramework::Account;
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType};

    /// Inital token into yield farming treasury
    fun davied_accept(signer: signer) {
        Account::do_accept_token<MockTokenType>(&signer);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    /// Inital token into yield farming treasury
    fun alice_init_token_into_treasury(signer: signer) {
        // Accept token
        Token::register_token<MockTokenType>(&signer, 9u8);
        Account::do_accept_token<MockTokenType>(&signer);

        let usdx_token = Token::mint<MockTokenType>(&signer, CommonHelper::pow_amount<MockTokenType>(100000000));
        Account::deposit_to_self(&signer, usdx_token);

        Account::deposit<MockTokenType>(@bob, Token::mint<MockTokenType>(&signer, CommonHelper::pow_amount<MockTokenType>(1000000)));
        Account::deposit<MockTokenType>(@cindy, Token::mint<MockTokenType>(&signer, CommonHelper::pow_amount<MockTokenType>(1000000)));
        Account::deposit<MockTokenType>(@davied, Token::mint<MockTokenType>(&signer, CommonHelper::pow_amount<MockTokenType>(1000000)));

        let usdx_amount = CommonHelper::pow_amount<MockTokenType>(1000);

        let tresury = Account::withdraw(&signer, usdx_amount);
        YieldFarmingWrapper::initialize_global_pool(&signer, tresury, );
        YieldFarmingWrapper::reset_release_per_second(&signer, 0);
    }
}
// check: EXECUTED

//# run --signers bob
script {
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    fun bob_stake_1x_token_to_pool_failed(signer: signer) {
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 1, 0);
        assert!(stake_id == 1, 100001);
    }
}
// check: "Keep(ABORTED { code: 28929"

//# block --author 0x1 --timestamp 10002000

//# run --signers bob
script {
    use SwapAdmin::YieldFarmingWrapper;

    // Except harvest_index is 0 because of pool not aliving.
    fun after_10_second_check_harvest_index(_signer: signer) {
        let (_, _, _, harvest_index) = YieldFarmingWrapper::query_info();
        assert!(harvest_index == 0, 100002);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::YieldFarmingWrapper;

    fun alice_switch_to_alive(signer: signer) {
        YieldFarmingWrapper::set_alive(&signer, true);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10003000

//# run --signers bob
script {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Debug;

    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    fun bob_stake_1x_token_to_pool(signer: signer) {
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 1, 0);
        assert!(stake_id == 1, 10004);

        // get header rewards
        let header_rewards = YieldFarmingWrapper::harvest(&signer, 1);
        let amount = Token::value<MockTokenType>(&header_rewards);

        Debug::print(&amount);
        Debug::print(&CommonHelper::pow_amount<MockTokenType>(1));
        assert!(amount == CommonHelper::pow_amount<MockTokenType>(1), 10005);
        Account::deposit_to_self(&signer, header_rewards);

        let (
            _,
            _,
            asset_total_weight,
            harvest_index
        ) = YieldFarmingWrapper::query_info();

        assert!(asset_total_weight == CommonHelper::pow_amount<MockTokenType>(1), 10006);
        assert!(harvest_index == 0, 10006); // Bob get first gain
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10004000

//# run --signers alice
script {
    use SwapAdmin::YieldFarmingWrapper;

    fun alice_switch_to_unalive(signer: signer) {
        YieldFarmingWrapper::set_alive(&signer, false);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10005000

//# run --signers alice
script {
    use SwapAdmin::YieldFarmingWrapper;

    fun alice_switch_to_alive(signer: signer) {
        YieldFarmingWrapper::set_alive(&signer, true);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10006000

//# run --signers bob
script {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Debug;

    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    fun bob_harvest(signer: signer) {
        let harvest_token = YieldFarmingWrapper::harvest(&signer, 1);
        let amount = Token::value<MockTokenType>(&harvest_token);

        Debug::print(&amount);
        assert!(amount == CommonHelper::pow_amount<MockTokenType>(2), 10011);

        Account::deposit_to_self(&signer, harvest_token);

        // Unstake from pool
        let (asset_val, token_val) =  YieldFarmingWrapper::unstake(&signer, 1);
        assert!(asset_val == CommonHelper::pow_amount<MockTokenType>(1), 10012);
        assert!(token_val == 0, 10013);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 10007000

//# run --signers cindy
script {
    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    fun cindy_stake_1x_token_to_pool(signer: signer) {
        let stake_id = YieldFarmingWrapper::stake(&signer, CommonHelper::pow_amount<MockTokenType>(1), 1, 0);
        assert!(stake_id == 1, 10014);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::YieldFarmingWrapper;

    fun alice_switch_to_unalive(signer: signer) {
        YieldFarmingWrapper::set_alive(&signer, false);
    }
}
// check: EXECUTED


//# run --signers cindy
script {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Debug;

    use SwapAdmin::YieldFarmingWrapper::{MockTokenType, Self};
    use SwapAdmin::CommonHelper;

    fun cindy_harvest(signer: signer) {
        let harvest_token = YieldFarmingWrapper::harvest(&signer, 1);
        let amount = Token::value<MockTokenType>(&harvest_token);

        Debug::print(&amount);
        assert!(amount == CommonHelper::pow_amount<MockTokenType>(1), 10011);

        Account::deposit_to_self(&signer, harvest_token);
    }
}
// check: EXECUTED