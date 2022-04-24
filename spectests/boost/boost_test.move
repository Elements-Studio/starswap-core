//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr SwapAdmin --amount 10000000000000000

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr bob --amount 10000000000000000

//# faucet --addr cindy --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# publish

module SwapAdmin::YieldFarmingAndVestarWrapper {
    //module SwapAdmin::YieldFarmingWrapper {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Debug;

    use SwapAdmin::YieldFarmingV3 as YieldFarming;
    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeFarmPool};
    use SwapAdmin::TokenSwap::LiquidityToken;

    use SwapAdmin::TokenSwapVestarMinter;

    struct STARWrapper has copy, drop, store {}

    //    struct PoolType_A has copy, drop, store {}
    //
    //    struct AssetType_A has copy, drop, store { value: u128 }

    struct Token_X has copy, drop, store {}

    struct Token_Y has copy, drop, store {}

    struct GovModfiyParamCapability<phantom X, phantom Y> has key, store {
        cap: YieldFarming::ParameterModifyCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>,
    }

    struct StakeCapbabilityList<phantom X, phantom Y> has key, store {
        items: vector<YieldFarming::HarvestCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>>
    }

    public fun initialize<X: copy + drop + store, Y: copy + drop + store>(signer: &signer, treasury: Token::Token<STARWrapper>) {
        YieldFarming::initialize<PoolTypeFarmPool, STARWrapper>(signer, treasury);
        YieldFarming::initialize_global_pool_info<PoolTypeFarmPool>(signer, 800000000u128);
        let alloc_point = 10;
        let cap = YieldFarming::add_asset_v2<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(signer, alloc_point, 0);
        move_to(signer, GovModfiyParamCapability<X, Y>{
            cap,
        });
    }

    // only admin call
    public fun update_pool<X: copy + drop + store, Y: copy + drop + store>(_signer: &signer, alloc_point: u128, last_alloc_point: u128) acquires GovModfiyParamCapability {
        let cap = borrow_global<GovModfiyParamCapability<X, Y>>(@SwapAdmin);
        YieldFarming::update_pool<PoolTypeFarmPool, STARWrapper, Token::Token<LiquidityToken<X, Y>>>(
            &cap.cap,
            @SwapAdmin,
            alloc_point,
            last_alloc_point);
    }

    public fun stake_v2<X: copy + drop + store, Y: copy + drop + store>(signer: &signer, asset_amount: u128, asset_weight: u128, weight_factor: u64, asset: Token::Token<LiquidityToken<X, Y>>, deadline: u64): u64
    acquires GovModfiyParamCapability, StakeCapbabilityList {
        let cap = borrow_global_mut<GovModfiyParamCapability<X, Y>>(@SwapAdmin);
        let (harvest_cap, stake_id) = YieldFarming::stake_v2<PoolTypeFarmPool, STARWrapper, Token::Token<LiquidityToken<X, Y>>>(
            signer,
            @SwapAdmin,
            asset,
            asset_weight,
            asset_amount,
            weight_factor,
            deadline,
            &cap.cap);

        let user_addr = Signer::address_of(signer);
        if (!exists<StakeCapbabilityList<X, Y>>(user_addr)) {
            move_to(signer, StakeCapbabilityList<X, Y>{
                items: Vector::empty<YieldFarming::HarvestCapability<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>>(),
            });
        };

        let cap_list = borrow_global_mut<StakeCapbabilityList<X, Y>>(user_addr);
        Vector::push_back(&mut cap_list.items, harvest_cap);
        stake_id
    }

    public fun unstake<X: copy + drop + store, Y: copy + drop + store>(signer: &signer, id: u64): (u128, u128) acquires StakeCapbabilityList {
        assert!(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList<X, Y>>(Signer::address_of(signer));
        let cap = Vector::remove(&mut cap_list.items, id - 1);
        let (asset, token) = YieldFarming::unstake<PoolTypeFarmPool, STARWrapper, Token::Token<LiquidityToken<X, Y>>>(signer, @SwapAdmin, cap);
        let token_val = Token::value<STARWrapper>(&token);
        let asset_value = Token::value<LiquidityToken<X, Y>>(&asset);
        Account::deposit<STARWrapper>(Signer::address_of(signer), token);
        Account::deposit<LiquidityToken<X, Y>>(Signer::address_of(signer), asset);
        (asset_value, token_val)
    }

    public fun harvest<X: copy + drop + store, Y: copy + drop + store>(signer: &signer, id: u64): Token::Token<STARWrapper> acquires StakeCapbabilityList {
        assert!(id > 0, 10000);
        let cap_list = borrow_global_mut<StakeCapbabilityList<X, Y>>(Signer::address_of(signer));
        let cap = Vector::borrow(&cap_list.items, id - 1);
        YieldFarming::harvest<PoolTypeFarmPool, STARWrapper, Token::Token<LiquidityToken<X, Y>>>(Signer::address_of(signer), @SwapAdmin, 0, cap)
    }

    public fun query_expect_gain<X: copy + drop + store, Y: copy + drop + store>(user_addr: address, id: u64): u128 acquires StakeCapbabilityList {
        let cap_list = borrow_global_mut<StakeCapbabilityList<X, Y>>(user_addr);
        let cap = Vector::borrow(&cap_list.items, id - 1);
        YieldFarming::query_expect_gain<PoolTypeFarmPool, STARWrapper, Token::Token<LiquidityToken<X, Y>>>(user_addr, @SwapAdmin, cap)
    }

    public fun query_stake_list<X: copy + drop + store, Y: copy + drop + store>(user_addr: address): vector<u64> {
        YieldFarming::query_stake_list<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(user_addr)
    }

    public fun query_stake<X: copy + drop + store, Y: copy + drop + store>(user_addr: address, id: u64): u128 {
        YieldFarming::query_stake<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(user_addr, id)
    }

    public fun query_pool_info_v2<X: copy + drop + store, Y: copy + drop + store>(): (u128, u128, u128, u128) {
        YieldFarming::query_pool_info_v2<PoolTypeFarmPool, Token::Token<LiquidityToken<X, Y>>>(@SwapAdmin)
    }

    public fun print_query_info_v2<X: copy + drop + store, Y: copy + drop + store>() {
        let (alloc_point, asset_total_amount, asset_total_weight, harvest_index) = query_pool_info_v2<X, Y>();

        Debug::print(&1000110001);
        Debug::print(&alloc_point);
        Debug::print(&asset_total_amount);
        Debug::print(&asset_total_weight);
        Debug::print(&harvest_index);
        Debug::print(&1000510005);
    }

    /// boost for farm
    public fun boost_to_farm_pool<X: copy + drop + store, Y: copy + drop + store>(signer: &signer, boost_amount: u128, stake_id: u64)
    acquires GovModfiyParamCapability {
        let cap = borrow_global_mut<GovModfiyParamCapability<X, Y>>(@SwapAdmin);
        TokenSwapFarmBoost::boost_to_farm_pool<X, Y>(&cap.cap, signer, boost_amount, stake_id);
    }

    /// unboost for farm
    public fun unboost_from_farm_pool<X: copy + drop + store, Y: copy + drop + store>(signer: &signer)
    acquires GovModfiyParamCapability {
        let cap = borrow_global_mut<GovModfiyParamCapability<X, Y>>(@SwapAdmin);
        TokenSwapFarmBoost::unboost_from_farm_pool<X, Y>(&cap.cap, signer);
    }

    /// unboost for farm
    public fun get_boost_factor<X: copy + drop + store, Y: copy + drop + store>(account: address) {
        TokenSwapFarmBoost::get_boost_factor<X, Y>(account);
    }

    public fun update_boost_facotr<X: copy + drop + store, Y: copy + drop + store>(signer: &signer, new_boost_factor: u64)
    acquires GovModfiyParamCapability {
        let cap = borrow_global_mut<GovModfiyParamCapability<X, Y>>(@SwapAdmin);
        TokenSwapFarmBoost::update_boost_facotr<X, Y>(&cap.cap, signer, new_boost_factor);
    }


    struct CapabilityWrapper has key, store {
        mint_cap: TokenSwapVestarMinter::MintCapability,
        id: u64,
    }

    public fun vestar_initialize(signer: &signer) {
        let (
            mint_cap,
            treasury_cap
        ) = TokenSwapVestarMinter::init(signer);
        TokenSwapFarmBoost::set_treasury_cap(signer, treasury_cap);

        move_to(signer, CapabilityWrapper{
            mint_cap,
            id: 0
        });
    }

    public fun mint(signer: &signer, pledge_time_sec: u64, staked_amount: u128) acquires CapabilityWrapper {
        let cap = borrow_global_mut<CapabilityWrapper>(@SwapAdmin);
        cap.id = cap.id + 1;
        TokenSwapVestarMinter::mint_with_cap(signer, cap.id, pledge_time_sec, staked_amount, &cap.mint_cap);
    }

    public fun burn(signer: &signer) acquires CapabilityWrapper {
        let cap = borrow_global_mut<CapabilityWrapper>(@SwapAdmin);
        TokenSwapVestarMinter::burn_with_cap(signer, cap.id, &cap.mint_cap);
    }

    public fun value(signer: &signer): u128 {
        TokenSwapVestarMinter::value(Signer::address_of(signer))
    }
}

//# block --author 0x1 --timestamp 10001000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock;
    use SwapAdmin::YieldFarmingAndVestarWrapper::{Token_X, Token_Y};

    fun admin_init_token(signer: signer) {
        TokenMock::register_token<Token_X>(&signer, 9u8);
        TokenMock::register_token<Token_Y>(&signer, 9u8);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Math;
    use SwapAdmin::TokenMock;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::YieldFarmingAndVestarWrapper::{Token_X, Token_Y};

    fun admin_register_token_pair_and_mint(signer: signer) {
        //token pair register must be swap SwapAdmin account
        TokenSwapRouter::register_swap_pair<Token_X, Token_Y>(&signer);
        assert!(TokenSwapRouter::swap_pair_exists<Token_X, Token_Y>(), 1001);

        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));

        // Resister and mint Token_X and deposit to alice
        CommonHelper::safe_mint<Token_X>(&signer, 100000000 * scaling_factor);
        Account::deposit<Token_X>(@alice, TokenMock::mint_token<Token_X>(100000000 * scaling_factor));

        // Resister and mint Token_Y and deposit to alice
        CommonHelper::safe_mint<Token_Y>(&signer, 100000000 * scaling_factor);
        Account::deposit<Token_Y>(@alice, TokenMock::mint_token<Token_Y>(100000000 * scaling_factor));
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Math;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::YieldFarmingAndVestarWrapper::{Token_X, Token_Y};

    fun add_liquidity(signer: signer) {
        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));

        let amount_tokenx_desired: u128 = 1000 * scaling_factor;
        let amount_tokenydesired: u128 = 8000 * scaling_factor;
        let amount_tokenx_min: u128 = 1 * scaling_factor;
        let amount_tokenymin: u128 = 1 * scaling_factor;
        TokenSwapRouter::add_liquidity<Token_X, Token_Y>(
            &signer,
            amount_tokenx_desired,
            amount_tokenydesired,
            amount_tokenx_min,
            amount_tokenymin);
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<Token_X, Token_Y>();
        assert!(total_liquidity > 0, 1003);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;

    use SwapAdmin::YieldFarmingAndVestarWrapper::{STARWrapper};
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

    use SwapAdmin::YieldFarmingAndVestarWrapper::{STARWrapper, Token_X, Token_Y, Self};
    use SwapAdmin::CommonHelper;

    /// Inital token into yield farming treasury
    fun init_token_into_treasury(account: signer) {
        let star_amount = CommonHelper::pow_amount<STARWrapper>(10000);

        let treasury = Account::withdraw(&account, star_amount);
        YieldFarmingAndVestarWrapper::initialize<Token_X, Token_Y>(&account, treasury);
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

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapFarmScript;

    fun initialize_boost_event(signer: signer) {
        TokenSwapFarmScript::initialize_boost_event(signer);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::YieldFarmingAndVestarWrapper;

    fun init_vestar(signer: signer) {
        YieldFarmingAndVestarWrapper::vestar_initialize(&signer);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::YieldFarmingAndVestarWrapper;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::YieldFarmingAndVestarWrapper::{STARWrapper};
    use StarcoinFramework::Debug;

    fun vestar_mint(signer: signer) {
        let perday = 60 * 60 * 24;
        YieldFarmingAndVestarWrapper::mint(&signer, 7 * perday, CommonHelper::pow_amount<STARWrapper>(1) * 1000);
        Debug::print(&YieldFarmingAndVestarWrapper::value(&signer));
        assert!(YieldFarmingAndVestarWrapper::value(&signer) > 0, 10001);
    }
}
// check: EXECUTED


//# run --signers alice

script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Math;
    use SwapAdmin::CommonHelper;

    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::YieldFarmingAndVestarWrapper::{STARWrapper, Token_X, Token_Y, Self};

    /// Alice joined and staking some asset
    fun stake_token_to_pool(signer: signer) {
        // Alice accept STARWrapper
        Account::do_accept_token<STARWrapper>(&signer);

        //when pool type = farm, boost factor == 1.0, then weight_factor = 100
        let asset_amount = CommonHelper::pow_amount<STARWrapper>(1);
        let asset_weight = asset_amount * 1;

        //        let liquidity_amount = TokenSwapRouter::liquidity<Token_X, Token_Y>(Signer::address_of(&signer));
        let liquidity_amount: u128 = 1 * (Math::pow(10, 9u64));
        let liquidity_token = TokenSwapRouter::withdraw_liquidity_token<Token_X, Token_Y>(&signer, liquidity_amount);
        let stake_id = YieldFarmingAndVestarWrapper::stake_v2<Token_X, Token_Y>(&signer, asset_amount, asset_weight, 100, liquidity_token, 0);
        assert!(stake_id == 1, 1005);
    }
}
// check: EXECUTED

//# run --signers alice

script {
    use StarcoinFramework::Signer;

    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::YieldFarmingAndVestarWrapper::{Token_X, Token_Y, Self};

    /// Alice boost farm lp
    fun boost_to_farm_pool(signer: signer) {
        let user_addr = Signer::address_of(&signer);
        let boost_factor = TokenSwapFarmBoost::get_boost_factor<Token_X, Token_Y>(user_addr);
        assert!(boost_factor == 100, 1006);
        let (_, asset_total_amount, asset_total_weight, _) = YieldFarmingAndVestarWrapper::query_pool_info_v2<Token_X, Token_Y>();
        assert!(asset_total_weight == asset_total_amount, 1007);

        let vestar_amount = YieldFarmingAndVestarWrapper::value(&signer);
        YieldFarmingAndVestarWrapper::boost_to_farm_pool<Token_X, Token_Y>(&signer, vestar_amount, 1);

        let boost_factor_after = TokenSwapFarmBoost::get_boost_factor<Token_X, Token_Y>(user_addr);
        assert!(boost_factor_after >= boost_factor, 1011);
        let (_, asset_total_amount_after, asset_total_weight_after, _) = YieldFarmingAndVestarWrapper::query_pool_info_v2<Token_X, Token_Y>();
        assert!(asset_total_weight_after >= asset_total_amount_after, 1012);

        let calc_weight = TokenSwapFarmBoost::calculate_boost_weight(asset_total_amount, boost_factor_after);
        assert!(asset_total_weight_after == calc_weight, 1013);

        let vestar_amount_after = YieldFarmingAndVestarWrapper::value(&signer);
        assert!(vestar_amount_after == 0, 1014);
    }
}
// check: EXECUTED


//# block --author 0x1 --timestamp 10004000

//# run --signers alice
script {
    use StarcoinFramework::Signer;

    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::YieldFarmingAndVestarWrapper::{Token_X, Token_Y, Self};

    /// Alice harvest after 3 seconds, checking whether has rewards.
    fun unboost_from_farm_pool(signer: signer) {
        let user_addr = Signer::address_of(&signer);
        let boost_factor = TokenSwapFarmBoost::get_boost_factor<Token_X, Token_Y>(user_addr);
        assert!(boost_factor >= 100, 1017);

        // Unstake
        let (_asset_val, _token_val) = YieldFarmingAndVestarWrapper::unstake<Token_X, Token_Y>(&signer, 1);
        YieldFarmingAndVestarWrapper::unboost_from_farm_pool<Token_X, Token_Y>(&signer);

        let boost_factor_after = TokenSwapFarmBoost::get_boost_factor<Token_X, Token_Y>(user_addr);
        assert!(boost_factor_after == 100, 1018);
        let (_, asset_total_amount_after, asset_total_weight_after, _) = YieldFarmingAndVestarWrapper::query_pool_info_v2<Token_X, Token_Y>();
        assert!(asset_total_weight_after == asset_total_amount_after, 1019);

        let vestar_amount_after = YieldFarmingAndVestarWrapper::value(&signer);
        assert!(vestar_amount_after > 0, 1020);
    }
}
// check: EXECUTED


//# block --author 0x1 --timestamp 10006000

//# run --signers alice

script {
    use StarcoinFramework::Signer;
    use SwapAdmin::CommonHelper;
    use StarcoinFramework::Math;

    use SwapAdmin::TokenSwapRouter;

    use SwapAdmin::TokenSwapFarmBoost;
    use SwapAdmin::YieldFarmingAndVestarWrapper::{STARWrapper, Token_X, Token_Y, Self};

    /// Alice boost farm lp again
    fun boost_to_farm_pool_again(signer: signer) {
        let user_addr = Signer::address_of(&signer);

        let asset_amount = CommonHelper::pow_amount<STARWrapper>(5);
        let asset_weight = asset_amount * 1;

        let liquidity_amount: u128 = 5 * (Math::pow(10, 9u64));
        let liquidity_token = TokenSwapRouter::withdraw_liquidity_token<Token_X, Token_Y>(&signer, liquidity_amount);

        let predict_boost_factor = TokenSwapFarmBoost::predict_boost_factor<Token_X, Token_Y>(user_addr, asset_amount);
        YieldFarmingAndVestarWrapper::update_boost_facotr<Token_X, Token_Y>(&signer, predict_boost_factor);

        let stake_id = YieldFarmingAndVestarWrapper::stake_v2<Token_X, Token_Y>(&signer, asset_amount, asset_weight, 100, liquidity_token, 0);
        assert!(stake_id == 2, 1025);

        let boost_factor = TokenSwapFarmBoost::get_boost_factor<Token_X, Token_Y>(user_addr);
        assert!(boost_factor == predict_boost_factor, 1026);
        }
    }
// check: EXECUTED
