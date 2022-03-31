// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {

module YieldFarmingV4 {
    use StarcoinFramework::Token;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Math;
    use StarcoinFramework::Option;
    use StarcoinFramework::Vector;

    use SwapAdmin::BigExponential;
    use SwapAdmin::YieldFarmingLibrary;
    use SwapAdmin::TokenSwapConfig;

    const ERR_FARMING_INIT_REPEATE: u64 = 101;
    const ERR_FARMING_NOT_READY: u64 = 102;
    const ERR_FARMING_STAKE_EXISTS: u64 = 103;
    const ERR_FARMING_STAKE_NOT_EXISTS: u64 = 104;
    const ERR_FARMING_HAVERST_NO_GAIN: u64 = 105;
    const ERR_FARMING_TOTAL_WEIGHT_IS_ZERO: u64 = 106;
    const ERR_FARMING_BALANCE_EXCEEDED: u64 = 108;
    const ERR_FARMING_NOT_ENOUGH_ASSET: u64 = 109;
    const ERR_FARMING_TIMESTAMP_INVALID: u64 = 110;
    const ERR_FARMING_TOKEN_SCALE_OVERFLOW: u64 = 111;
    const ERR_FARMING_CALC_LAST_IDX_BIGGER_THAN_NOW: u64 = 112;
    const ERR_FARMING_NOT_ALIVE: u64 = 113;
    const ERR_FARMING_ALIVE_STATE_INVALID: u64 = 114;
    const ERR_FARMING_ASSET_NOT_EXISTS: u64 = 115;
    const ERR_FARMING_STAKE_INDEX_ERROR: u64 = 116;
    const ERR_FARMING_MULTIPLIER_INVALID: u64 = 117;
    const ERR_FARMING_OPT_AFTER_DEADLINE: u64 = 118;
    const ERR_YIELD_FARMING_GLOBAL_POOL_INFO_ALREADY_EXIST: u64 = 120;

    /// The object of yield farming
    /// RewardTokenT meaning token of yield farming
    struct Farming<phantom PoolType, phantom RewardTokenT> has key, store {
        treasury_token: Token::Token<RewardTokenT>,
    }

//    struct FarmingAsset<phantom PoolType, phantom AssetT> has key, store {
//        asset_total_weight: u128,
//        harvest_index: u128,
//        last_update_timestamp: u64,
//        // Release count per seconds
//        release_per_second: u128,
//        // Start time, by seconds, user can operate stake only after this timestamp
//        start_time: u64,
//        // Representing the pool is alive, false: not alive, true: alive.
//        alive: bool,
//    }

//    /// To store user's asset token
//    struct Stake<phantom PoolType, AssetT> has store, copy, drop {
//        id: u64,
//        asset: AssetT,
//        asset_weight: u128,
//        last_harvest_index: u128,
//        gain: u128,
//        asset_multiplier: u64,
//    }
//
//    struct StakeList<phantom PoolType, AssetT> has key, store {
//        next_id: u64,
//        items: vector<Stake<PoolType, AssetT>>,
//    }



    struct YieldFarmingAsset<phantom PoolType, phantom AssetT> has key, store {
        asset_total_weight: u128, // ∑ (per user lp_amount *  user boost_factor)
        asset_total_amount: u128, //∑ (per user lp_amount)
        alloc_point: u128,  //pool alloc point
        harvest_index: u128,
        last_update_timestamp: u64,
        // Start time, by seconds, user can operate stake only after this timestamp
        start_time: u64,
        //        alive: bool  // alive不再需要，将alloc_point调整为0，达到关闭的目的
    }

    /// To store user's asset token
    struct Stake<phantom PoolType, phantom AssetT> has store, copy, drop {
        id: u64, //option, Option<u64>
        asset: AssetT,
        asset_weight: u128,
        asset_amount: u128,
        //weight factor, if farm: weight_factor = user boost factor * 100; if stake: weight_factor = stepwise multiplier
        weight_factor: u128,
        last_harvest_index: u128,
        gain: u128,
    }

    struct StakeList<phantom PoolType, AssetT> has key, store {
        next_id: u64,
        items: vector<Stake<PoolType, AssetT>>,
    }


    struct YieldFarmingGlobalPoolInfo<phantom PoolType> has key, store {
        // total allocation points. Must be the sum of all allocation points in all pools.
        total_alloc_point: u128, //∑ (per pool alloc_point)
        pool_release_per_second: u128, // pool_release_per_second
    }



    /// Capability to modify parameter such as period and alloc point
    struct ParameterModifyCapability<phantom PoolType, phantom AssetT> has key, store {}

    /// Harvest ability to harvest
    struct HarvestCapability<phantom PoolType, phantom AssetT> has key, store {
        stake_id: u64,
        // Indicates the deadline from start_time for the current harvesting permission,
        // which meaning a timestamp, by seconds
        deadline: u64,
    }

    /// Called by token issuer
    /// this will declare a yield farming pool
    public fun initialize<
        PoolType: store,
        RewardTokenT: store>(account: &signer, treasury_token: Token::Token<RewardTokenT>) {
        let scaling_factor = Math::pow(10, BigExponential::exp_scale_limition());
        let token_scale = Token::scaling_factor<RewardTokenT>();
        assert!(token_scale <= scaling_factor, Errors::limit_exceeded(ERR_FARMING_TOKEN_SCALE_OVERFLOW));
        assert!(!exists_at<PoolType, RewardTokenT>(Signer::address_of(account)), Errors::invalid_state(ERR_FARMING_INIT_REPEATE));

        move_to(account, Farming<PoolType, RewardTokenT>{
            treasury_token,
        });
    }

    /// Called by admin
    /// this will config yield farming global pool info
    public fun initialize_global_pool_info<
        PoolType: store>(account: &signer, pool_release_per_second: u128) {
        TokenSwapConfig::assert_admin(account);
        assert!(!exists_at<YieldFarmingGlobalPoolInfo<PoolType>>(Signer::address_of(account)), Errors::invalid_state(ERR_YIELD_FARMING_GLOBAL_POOL_INFO_ALREADY_EXIST));

        move_to(account, YieldFarmingGlobalPoolInfo<PoolType>{
            total_alloc_point: 0,
            pool_release_per_second: pool_release_per_second,
        });
    }

//    struct YieldFarmingGlobalPoolInfo<phantom PoolType> has key, store {
//        // total allocation points. Must be the sum of all allocation points in all pools.
//        total_alloc_point: u128, //∑ (per pool alloc_point)
//        pool_release_per_second: u128, // pool_release_per_second
//    }


//    /// deprecated call
//    /// Add asset pools
//    public fun add_asset<PoolType: store, AssetT: store>(
//        account: &signer,
//        release_per_second: u128,
//        delay: u64): ParameterModifyCapability<PoolType, AssetT> {
//        assert!(
//            !exists_asset_at<PoolType, AssetT>(Signer::address_of(account)),
//            Errors::invalid_state(ERR_FARMING_INIT_REPEATE)
//        );
//
//        let now_seconds = Timestamp::now_seconds();
//
//        move_to(account, YieldFarmingAsset<PoolType, AssetT>{
//            asset_total_weight: 0,
//            harvest_index: 0,
//            last_update_timestamp: now_seconds,
//            release_per_second,
//            start_time: now_seconds + delay,
//            alive: false
//        });
//        ParameterModifyCapability<PoolType, AssetT> {}
//    }


//    // Add a new lp to the pool. Can only be called by the owner.
//    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
//    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate) public onlyOwner {
//        if (_withUpdate) {
//            massUpdatePools();
//        }
//        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
//        totalAllocPoint = totalAllocPoint.add(_allocPoint);
//        poolInfo.push(PoolInfo({
//        lpToken: _lpToken,
//        allocPoint: _allocPoint,
//        lastRewardBlock: lastRewardBlock,
//        accCakePerShare: 0
//        }));
//        updateStakingPool();
//    }

    /// Add asset pools v2
    /// Called only by admin
    public fun add_asset<PoolType: store, AssetT: store>(
        account: &signer,
        alloc_point: u128,  //pool alloc point
        delay: u64): ParameterModifyCapability<PoolType, AssetT> acquires YieldFarmingGlobalPoolInfo {
        TokenSwapConfig::assert_admin(account);
        let address = Signer::address_of(account);
        assert!(!exists_asset_at<PoolType, AssetT>(address), Errors::invalid_state(ERR_FARMING_INIT_REPEATE));
        let now_seconds = Timestamp::now_seconds();

        //update global pool info total alloc point
        let golbal_pool_info = borrow_global_mut<YieldFarmingGlobalPoolInfo<PoolType>>(address);
        golbal_pool_info.total_alloc_point = golbal_pool_info.total_alloc_point + alloc_point;

        move_to(account, YieldFarmingAsset<PoolType, AssetT>{
            asset_total_weight: 0,
            asset_total_amount: 0,
            alloc_point: alloc_point,
            harvest_index: 0,
            last_update_timestamp: now_seconds,
            start_time: now_seconds + delay,
        });
        ParameterModifyCapability<PoolType, AssetT> {}
    }

//    fun update_golbal_pool_info<PoolType: store>(account: &signer,) acquires YieldFarmingGlobalPoolInfo {
//        TokenSwapConfig::assert_admin(account);
//    }



    //    // Update reward variables of the given pool to be up-to-date.
    //    function updatePool(uint256 _pid) public {
    //        PoolInfo storage pool = poolInfo[_pid];
    //        if (block.number <= pool.lastRewardBlock) {
    //            return;
    //        }
    //        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    //        if (lpSupply == 0) {
    //            pool.lastRewardBlock = block.number;
    //            return;
    //        }
    //        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
    //        uint256 cakeReward = multiplier.mul(cakePerBlock).mul(pool.allocPoint).div(totalAllocPoint);
    //        cake.mintFor(address(syrup), cakeReward);
    //        pool.accCakePerShare = pool.accCakePerShare.add(cakeReward.mul(1e12).div(lpSupply));
    //        pool.lastRewardBlock = block.number;
    //    }



//    /// deprecated call
//    public fun modify_parameter<PoolType: store, RewardTokenT: store, AssetT: store>(
//        _cap: &ParameterModifyCapability<PoolType, AssetT>,
//        broker: address,
//        release_per_second: u128,
//        alive: bool) acquires FarmingAsset {
//
//        let now_seconds = Timestamp::now_seconds();
//        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker);
//
//        // if the pool is alive, then update index
//        if (farming_asset.alive) {
//            farming_asset.harvest_index =
//                calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);
//        };
//
//        farming_asset.last_update_timestamp = now_seconds;
//        farming_asset.release_per_second = release_per_second;
//        farming_asset.alive = alive;
//    }

    //
    //    struct YieldFarmingAsset<phantom PoolType, phantom AssetT> has key, store {
    //        asset_total_weight: u128, // ∑ (per user lp_amount *  user boost_factor)
    //        asset_total_amount: u128, //∑ (per user lp_amount)
    //        alloc_point: u64,  //pool alloc point
    //        harvest_index: u128,
    //        last_update_timestamp: u64,
    //        // Start time, by seconds, user can operate stake only after this timestamp
    //        start_time: u64,
    //    }

    // modify parameter v2
    /// harvest_index = (current_timestamp - last_timestamp) * pool_release_per_second * (alloc_point/total_alloc_point)  / (asset_total_weight );
    /// gain = (current_index - last_index) * user_amount * boost_factor;
    /// asset_total_weight = ∑ (per user lp_amount *  user boost_factor)
    public fun update_pool<PoolType: store, RewardTokenT: store, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        broker: address,
        alloc_point: u128, //new pool alloc point
        last_alloc_point: u128, //last pool alloc point
    )  acquires YieldFarmingAsset, YieldFarmingGlobalPoolInfo {
        let now_seconds = Timestamp::now_seconds();
        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker);
        // Calculate the index that has occurred first, and then update the pool info
        farming_asset.harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);
        farming_asset.alloc_point = alloc_point;
        farming_asset.last_update_timestamp = now_seconds;

        //update global pool info total alloc point
        let golbal_pool_info = borrow_global_mut<YieldFarmingGlobalPoolInfo<PoolType>>(broker);
        golbal_pool_info.total_alloc_point = golbal_pool_info.total_alloc_point - last_alloc_point + alloc_point;
    }


//    /// Call by stake user, staking amount of asset in order to get yield farming token
//    public fun stake<PoolType: store, RewardTokenT: store, AssetT: store>(
//        signer: &signer,
//        broker_addr: address,
//        asset: AssetT,
//        asset_weight: u128,
//        asset_multiplier: u64,
//        deadline: u64,
//        _cap: &ParameterModifyCapability<PoolType, AssetT>) : (HarvestCapability<PoolType, AssetT>, u64)
//    acquires StakeList, YieldFarmingAsset {
//        assert!(exists_asset_at<PoolType, AssetT>(broker_addr), Errors::invalid_state(ERR_FARMING_ASSET_NOT_EXISTS));
//        assert!(asset_multiplier > 0, Errors::invalid_state(ERR_FARMING_MULTIPLIER_INVALID));
//
//        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker_addr);
//        let now_seconds = Timestamp::now_seconds();
//
//        intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);
//
//        let user_addr = Signer::address_of(signer);
//        if (!exists<StakeList<PoolType, AssetT>>(user_addr)) {
//            move_to(signer, StakeList<PoolType, AssetT>{
//                next_id: 0,
//                items: Vector::empty<Stake<PoolType, AssetT>>(),
//            });
//        };
//
//        let (harvest_index, total_asset_weight, gain) = if (farming_asset.asset_total_weight <= 0) {
//            let time_period = now_seconds - farming_asset.last_update_timestamp;
//            (
//                0,
//                asset_weight * (asset_multiplier as u128),
//                farming_asset.release_per_second * (time_period as u128)
//            )
//        } else {
//            (
//                calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds),
//                farming_asset.asset_total_weight + (asset_weight * (asset_multiplier as u128)),
//                0
//            )
//        };
//
//        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
//        let stake_id = stake_list.next_id + 1;
//        Vector::push_back<Stake<PoolType, AssetT>>(&mut stake_list.items, Stake<PoolType, AssetT>{
//            id: stake_id,
//            asset,
//            asset_weight,
//            last_harvest_index: harvest_index,
//            gain,
//            asset_multiplier,
//        });
//
//        farming_asset.harvest_index = harvest_index;
//        farming_asset.asset_total_weight = total_asset_weight;
//        farming_asset.last_update_timestamp = now_seconds;
//
//        stake_list.next_id = stake_id;
//
//        // Normalize deadline
//        deadline = if (deadline > 0) {
//            deadline + now_seconds
//        } else {
//            0
//        };
//
//        // Return values
//        (
//            HarvestCapability<PoolType, AssetT>{
//                stake_id,
//                deadline,
//            },
//            stake_id,
//        )
//    }

//    struct Stake<phantom PoolType, phantom AssetT> has store, copy, drop {
//        id: Option<u64>, //option
//        asset: AssetT,
//        asset_weight: u128,
//        asset_amount: u128,
//        ///weight factor, if farm: weight_factor = user boost factor; if stake: weight_factor = stepwise multiplier
//        weight_factor: u128,
//        //        asset_weight: u128,
//        last_harvest_index: u128,
//        gain: u128,
//    }

//    struct YieldFarmingAsset<phantom PoolType, phantom AssetT> has key, store {
//        asset_total_weight: u128, // ∑ (per user lp_amount *  user boost_factor)
//        asset_total_amount: u128, //∑ (per user lp_amount)
//        alloc_point: u128,  //pool alloc point
//        harvest_index: u128,
//        last_update_timestamp: u64,
//        // Start time, by seconds, user can operate stake only after this timestamp
//        start_time: u64,
//        //        alive: bool  // alive不再需要，将alloc_point调整为0，达到关闭的目的
//    }

    /// Call by stake user, staking amount of asset in order to get yield farming token
    public fun stake<PoolType: store, RewardTokenT: store, AssetT: store>(
        signer: &signer,
        broker_addr: address,
        asset: AssetT,
        asset_weight: u128,
        asset_amount: u128,
        weight_factor: u64, //if farm: weight_factor = user boost factor * 100; if stake: weight_factor = stepwise multiplier
        deadline: u64,
        _cap: &ParameterModifyCapability<PoolType, AssetT>) : (HarvestCapability<PoolType, AssetT>, u64)
    acquires StakeList, YieldFarmingAsset, YieldFarmingGlobalPoolInfo {
        assert!(exists_asset_at<YieldFarmingAsset<PoolType, AssetT>>(broker_addr), Errors::invalid_state(ERR_FARMING_ASSET_NOT_EXISTS));
//        assert!(asset_multiplier > 0, Errors::invalid_state(ERR_FARMING_MULTIPLIER_INVALID));

        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker_addr);
        let now_seconds = Timestamp::now_seconds();

        intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);

        let user_addr = Signer::address_of(signer);
        if (!exists<StakeList<PoolType, AssetT>>(user_addr)) {
            move_to(signer, StakeList<PoolType, AssetT>{
                next_id: 0,
                items: Vector::empty<Stake<PoolType, AssetT>>(),
            });
        };

//        let (harvest_index, total_asset_weight, gain) = if (farming_asset.asset_total_weight <= 0) {
//            let time_period = now_seconds - farming_asset.last_update_timestamp;
//            (
//                0,
//                asset_weight * (asset_multiplier as u128),
//                farming_asset.release_per_second * (time_period as u128)
//            )
//        } else {
//            (
//                calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds),
//                farming_asset.asset_total_weight + (asset_weight * (asset_multiplier as u128)),
//                0
//            )
//        };

        let (harvest_index, gain) = if (farming_asset.asset_total_weight <= 0) {
            let golbal_pool_info = borrow_global<YieldFarmingGlobalPoolInfo<PoolType>>(broker_addr);
            let time_period = now_seconds - farming_asset.last_update_timestamp;
            (
                0,
                golbal_pool_info.pool_release_per_second * (time_period as u128) * farming_asset.alloc_point / golbal_pool_info.total_alloc_point
            )
        } else {
            (
                calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds),
                0
            )
        };


        //    struct Stake<phantom PoolType, phantom AssetT> has store, copy, drop {
        //        id: Option<u64>, //option
        //        asset: AssetT,
        //        asset_weight: u128,
        //        asset_amount: u128,
        //        ///weight factor, if farm: weight_factor = user boost factor; if stake: weight_factor = stepwise multiplier
        //        weight_factor: u128,
        //        last_harvest_index: u128,
        //        gain: u128,
        //    }

        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let stake_id = stake_list.next_id + 1;
        Vector::push_back<Stake<PoolType, AssetT>>(&mut stake_list.items, Stake<PoolType, AssetT>{
            id: stake_id,
            asset,
            asset_weight,
            asset_amount,
            weight_factor,
            last_harvest_index: harvest_index,
            gain,
        });

        farming_asset.harvest_index = harvest_index;
        farming_asset.asset_total_weight = farming_asset.asset_total_weight + asset_weight;
        farming_asset.asset_total_amount = farming_asset.asset_total_amount + asset_amount;
        farming_asset.last_update_timestamp = now_seconds;

        stake_list.next_id = stake_id;

        // Normalize deadline
        deadline = if (deadline > 0) {
            deadline + now_seconds
        } else {
            0
        };

        // Return values
        (
            HarvestCapability<PoolType, AssetT>{
                stake_id,
                deadline,
            },
            stake_id,
        )
    }



//    /// Unstake asset from farming pool
//    public fun unstake<PoolType: store, RewardTokenT: store, AssetT: store>(
//        signer: &signer,
//        broker: address,
//        cap: HarvestCapability<PoolType, AssetT>)
//    : (AssetT, Token::Token<RewardTokenT>) acquires Farming, YieldFarmingAsset, StakeList {
//        // Destroy capability
//        let HarvestCapability<PoolType, AssetT>{ stake_id, deadline } = cap;
//
//        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker);
//        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker);
//        let now_seconds = Timestamp::now_seconds();
//
//        //intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);
//        assert!(now_seconds >= farming_asset.start_time, Errors::invalid_state(ERR_FARMING_NOT_READY));
//
//        let items = borrow_global_mut<StakeList<PoolType, AssetT>>(Signer::address_of(signer));
//
//        let Stake<PoolType, AssetT>{
//            id: out_stake_id,
//            asset: staked_asset,
//            asset_weight: staked_asset_weight,
//            last_harvest_index: staked_latest_harvest_index,
//            gain: staked_gain,
//            asset_multiplier: staked_asset_multiplier,
//        } = pop_stake<PoolType, AssetT>(&mut items.items, stake_id);
//
//        assert!(stake_id == out_stake_id, Errors::invalid_state(ERR_FARMING_STAKE_INDEX_ERROR));
//        assert_check_maybe_deadline(now_seconds, deadline);
//
//        let (new_harvest_index, now_seconds) = if (farming_asset.alive) {
//            (calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds), now_seconds)
//        } else {
//            (farming_asset.harvest_index, farming_asset.last_update_timestamp)
//        };
//
//        let asset_weight = staked_asset_weight * (staked_asset_multiplier as u128);
//        let period_gain = YieldFarmingLibrary::calculate_withdraw_amount(
//            new_harvest_index,
//            staked_latest_harvest_index,
//            asset_weight,
//        );
//
//        let withdraw_token = Token::withdraw<RewardTokenT>(&mut farming.treasury_token, staked_gain + period_gain);
//        assert!(farming_asset.asset_total_weight >= asset_weight, Errors::invalid_state(ERR_FARMING_NOT_ENOUGH_ASSET));
//
//        // Update farm asset
//        farming_asset.harvest_index = new_harvest_index;
//        farming_asset.asset_total_weight = farming_asset.asset_total_weight - asset_weight;
//        farming_asset.last_update_timestamp = now_seconds;
//
//        (staked_asset, withdraw_token)
//    }




    //    struct Stake<phantom PoolType, phantom AssetT> has store, copy, drop {
    //        id: Option<u64>, //option
    //        asset: AssetT,
    //        asset_weight: u128,
    //        asset_amount: u128,
    //        ///weight factor, if farm: weight_factor = user boost factor; if stake: weight_factor = stepwise multiplier
    //        weight_factor: u128,
    //        last_harvest_index: u128,
    //        gain: u128,
    //    }

    /// Unstake asset from farming pool
    /// TODO need to check if weight_factor changed
    public fun unstake<PoolType: store, RewardTokenT: store, AssetT: store>(
        signer: &signer,
        broker: address,
        cap: HarvestCapability<PoolType, AssetT>)
    : (AssetT, Token::Token<RewardTokenT>) acquires Farming, YieldFarmingAsset, StakeList {
        // Destroy capability
        let HarvestCapability<PoolType, AssetT>{ stake_id, deadline } = cap;

        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker);
        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker);
        let now_seconds = Timestamp::now_seconds();

        //intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);
        assert!(now_seconds >= farming_asset.start_time, Errors::invalid_state(ERR_FARMING_NOT_READY));

        let items = borrow_global_mut<StakeList<PoolType, AssetT>>(Signer::address_of(signer));

        let Stake<PoolType, AssetT>{
            id: out_stake_id,
            asset: staked_asset,
            asset_weight: staked_asset_weight,
            asset_amount: staked_asset_amount,
            weight_factor: staked_weight_factor,
            last_harvest_index: staked_latest_harvest_index,
            gain: staked_gain,
//            asset_multiplier: staked_asset_multiplier,
        } = pop_stake<PoolType, AssetT>(&mut items.items, stake_id);

        assert!(stake_id == out_stake_id, Errors::invalid_state(ERR_FARMING_STAKE_INDEX_ERROR));
        assert_check_maybe_deadline(now_seconds, deadline);

        let new_harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);
        let period_gain = calculate_withdraw_amount(new_harvest_index,staked_latest_harvest_index, asset_weight);

        let withdraw_token = Token::withdraw<RewardTokenT>(&mut farming.treasury_token, staked_gain + period_gain);
        assert!(farming_asset.asset_total_weight >= asset_weight, Errors::invalid_state(ERR_FARMING_NOT_ENOUGH_ASSET));

        // Update farm asset
        farming_asset.harvest_index = new_harvest_index;
        farming_asset.asset_total_weight = farming_asset.asset_total_weight - asset_weight;
        farming_asset.asset_total_amount = farming_asset.asset_total_amount - asset_amount;
        farming_asset.last_update_timestamp = now_seconds;

        (staked_asset, withdraw_token)
    }


//    /// Harvest yield farming token from stake
//    public fun harvest<PoolType: store,
//                       RewardTokenT: store,
//                       AssetT: store>(
//        user_addr: address,
//        broker_addr: address,
//        amount: u128,
//        cap: &HarvestCapability<PoolType, AssetT>): Token::Token<RewardTokenT> acquires Farming, YieldFarmingAsset, StakeList {
//        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker_addr);
//        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker_addr);
//
//        // Start check
//        let now_seconds = Timestamp::now_seconds();
//        // intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);
//        assert!(now_seconds >= farming_asset.start_time, Errors::invalid_state(ERR_FARMING_NOT_READY));
//
//        // Get stake from stake list
//        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
//        let stake = get_stake<PoolType, AssetT>(&mut stake_list.items, cap.stake_id);
//
//        assert_check_maybe_deadline(now_seconds, cap.deadline);
//
//        let (new_harvest_index, now_seconds) = if (farming_asset.alive) {
//            (calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds), now_seconds)
//        } else {
//            (farming_asset.harvest_index, farming_asset.last_update_timestamp)
//        };
//
//        // Debug::print(stake);
//        let asset_weight = stake.asset_weight * (stake.asset_multiplier as u128);
//        let period_gain = YieldFarmingLibrary::calculate_withdraw_amount(
//            new_harvest_index,
//            stake.last_harvest_index,
//            asset_weight,
//        );
//
//        let total_gain = stake.gain + period_gain;
//        //assert!(total_gain > 0, Errors::limit_exceeded(ERR_FARMING_HAVERST_NO_GAIN));
//        assert!(total_gain >= amount, Errors::limit_exceeded(ERR_FARMING_BALANCE_EXCEEDED));
//
//        let withdraw_amount = if (amount <= 0) {
//            total_gain
//        } else {
//            amount
//        };
//
//        // Update stake
//        let withdraw_token = Token::withdraw<RewardTokenT>(&mut farming.treasury_token, withdraw_amount);
//        stake.gain = total_gain - withdraw_amount;
//        stake.last_harvest_index = new_harvest_index;
//
//        // Update farming asset
//        farming_asset.harvest_index = new_harvest_index;
//        farming_asset.last_update_timestamp = now_seconds;
//
//        withdraw_token
//    }



    /// Harvest yield farming token from stake
    public fun harvest<PoolType: store,
                       RewardTokenT: store,
                       AssetT: store>(
        user_addr: address,
        broker_addr: address,
        amount: u128,
        cap: &HarvestCapability<PoolType, AssetT>): Token::Token<RewardTokenT> acquires Farming, YieldFarmingAsset, StakeList {
        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker_addr);
        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker_addr);

        // Start check
        let now_seconds = Timestamp::now_seconds();
        // intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);
        assert!(now_seconds >= farming_asset.start_time, Errors::invalid_state(ERR_FARMING_NOT_READY));

        // Get stake from stake list
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let stake = get_stake<PoolType, AssetT>(&mut stake_list.items, cap.stake_id);

        assert_check_maybe_deadline(now_seconds, cap.deadline);

//        let (new_harvest_index, now_seconds) = if (farming_asset.alive) {
//            (calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds), now_seconds)
//        } else {
//            (farming_asset.harvest_index, farming_asset.last_update_timestamp)
//        };
        let new_harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);
        let period_gain = calculate_withdraw_amount(new_harvest_index,stake.last_harvest_index, stake.asset_weight);
//
//        // Debug::print(stake);
//        let asset_weight = stake.asset_weight * (stake.asset_multiplier as u128);
//        let period_gain = YieldFarmingLibrary::calculate_withdraw_amount(
//            new_harvest_index,
//            stake.last_harvest_index,
//            asset_weight,
//        );

        let total_gain = stake.gain + period_gain;
        //assert!(total_gain > 0, Errors::limit_exceeded(ERR_FARMING_HAVERST_NO_GAIN));
        assert!(total_gain >= amount, Errors::limit_exceeded(ERR_FARMING_BALANCE_EXCEEDED));

        let withdraw_amount = if (amount <= 0) {
            total_gain
        } else {
            amount
        };

        // Update stake
        let withdraw_token = Token::withdraw<RewardTokenT>(&mut farming.treasury_token, withdraw_amount);
        stake.gain = total_gain - withdraw_amount;
        stake.last_harvest_index = new_harvest_index;

        // Update farming asset
        farming_asset.harvest_index = new_harvest_index;
        farming_asset.last_update_timestamp = now_seconds;

        withdraw_token
    }

    /// The user can quering all yield farming amount in any time and scene
    public fun query_expect_gain<PoolType: store,
                                 RewardTokenT: store,
                                 AssetT: store>(user_addr: address,
                                                broker_addr: address,
                                                cap: &HarvestCapability<PoolType, AssetT>)
    : u128 acquires FarmingAsset, StakeList {
        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker_addr);
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);

        // Start check
        let now_seconds = Timestamp::now_seconds();
        assert!(now_seconds >= farming_asset.start_time, Errors::invalid_state(ERR_FARMING_NOT_READY));

        // Calculate from latest timestamp to deadline timestamp if deadline valid
        let exp_seconds = if (now_seconds > cap.deadline) {
            now_seconds
        } else {
            cap.deadline
        };

        // Calculate new harvest index
        let new_harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(
            farming_asset,
            exp_seconds
        );

        let stake = get_stake(&mut stake_list.items, cap.stake_id);
//        let asset_weight = stake.asset_weight * (stake.asset_multiplier as u128);
//        let new_gain = YieldFarmingLibrary::calculate_withdraw_amount(
//            new_harvest_index,
//            stake.last_harvest_index,
//            asset_weight
//        );
        let new_gain = calculate_withdraw_amount(new_harvest_index,stake.last_harvest_index, stake.asset_weight);

        stake.gain + new_gain
    }

    /// Query total stake amount from yield farming resource
    public fun query_total_stake<PoolType: store,
                                 AssetT: store>(broker: address): u128 acquires FarmingAsset {
        let farming_asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.asset_total_amount
    }

    /// Query stake amount from user staking objects.
    public fun query_stake<PoolType: store,
                           AssetT: store>(account: address, id: u64): u128 acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(account);
        let stake = get_stake(&mut stake_list.items, id);
        assert!(stake.id == id, Errors::invalid_state(ERR_FARMING_STAKE_INDEX_ERROR));
        stake.asset_amount
    }

    /// Query stake id list from user
    public fun query_stake_list<PoolType: store,
                                AssetT: store>(user_addr: address): vector<u64> acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let len = Vector::length(&stake_list.items);
        if (len <= 0) {
            return Vector::empty<u64>()
        };

        let ret_list = Vector::empty<u64>();
        let idx = 0;
        loop {
            if (idx >= len) {
                break
            };
            let stake = Vector::borrow<Stake<PoolType, AssetT>>(&stake_list.items, idx);
            Vector::push_back(&mut ret_list, stake.id);
            idx = idx + 1;
        };
        ret_list
    }

//    /// Queyry pool info from pool type
//    /// return value: (alive, release_per_second, asset_total_weight, harvest_index)
//    public fun query_info<PoolType: store, AssetT: store>(broker: address): (bool, u128, u128, u128) acquires FarmingAsset {
//        let asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker);
//        (
//            asset.alive,
//            asset.release_per_second,
//            asset.asset_total_weight,
//            asset.harvest_index
//        )
//    }

    public fun query_pool_info<PoolType: store, AssetT: store>(broker: address): (bool, u128, u128, u128) acquires FarmingAsset {
        let asset = borrow_global_mut<YieldFarmingAsset<PoolType, AssetT>>(broker);
        (
            asset.asset_total_weight,
            asset.asset_total_amount,
            asset.alloc_point,
            asset.harvest_index
        )
    }

//    struct YieldFarmingGlobalPoolInfo<phantom PoolType> has key, store {
//        // total allocation points. Must be the sum of all allocation points in all pools.
//        total_alloc_point: u128, //∑ (per pool alloc_point)
//        pool_release_per_second: u128, // pool_release_per_second
//    }

    public fun query_global_pool_info<PoolType: store>(broker: address): (bool, u128) acquires YieldFarmingGlobalPoolInfo {
        let global_pool_info = borrow_global_mut<YieldFarmingGlobalPoolInfo<PoolType>>(broker);
        (
            global_pool_info.total_alloc_point,
            global_pool_info.pool_release_per_second
        )
    }


//    /// Update farming asset
//    fun calculate_harvest_index_with_asset<PoolType: store, AssetT: store>(
//        farming_asset: &FarmingAsset<PoolType, AssetT>,
//        now_seconds: u64): u128 {
//        // Debug::print(farming_asset);
//        // Debug::print(&now_seconds);
//        YieldFarmingLibrary::calculate_harvest_index_with_asse_info(
//            farming_asset.asset_total_weight,
//            farming_asset.harvest_index,
//            farming_asset.last_update_timestamp,
//            farming_asset.release_per_second,
//            now_seconds
//        )
//    }

    /// calculate pool harvest index
    /// harvest_index = (current_timestamp - last_timestamp) * pool_release_per_second * (alloc_point/total_alloc_point)  / (asset_total_weight );
    /// if farm:   asset_total_weight = ∑ (per user lp_amount *  user boost_factor)
    /// if stake:  asset_total_weight = ∑ (per user lp_amount *  stepwise_multiplier)
    fun calculate_harvest_index_with_asset<PoolType: store, AssetT: store>(
        farming_asset: &YieldFarmingAsset<PoolType, AssetT>,
        now_seconds: u64): u128  acquires YieldFarmingGlobalPoolInfo {
        assert!(farming_asset.last_update_timestamp <= now_seconds, Errors::invalid_argument(ERR_FARMING_TIMESTAMP_INVALID));

        let golbal_pool_info = borrow_global<YieldFarmingGlobalPoolInfo<PoolType>>(TokenSwapConfig::admin_address());
        let time_period = now_seconds - farming_asset.last_update_timestamp;
        let global_pool_reward = golbal_pool_info.pool_release_per_second * (time_period as u128);
        let pool_reward = BigExponential::exp(global_pool_reward * farming_asset.alloc_point, golbal_pool_info.total_alloc_point);

        /// calculate period harvest index and global pool info when asset_total_weight is zero
        let harvest_index_period = if (farming_asset.asset_total_weight <= 0){
            BigExponential::mantissa(pool_reward);
        } else {
            BigExponential::mantissa(BigExponential::div_exp(pool_reward, BigExponential::exp_direct(farming_asset.asset_total_weight)));
        };
        let index_accumulated = U256::add(
            U256::from_u128(harvest_index),
            harvest_index_period
        );
        BigExponential::to_safe_u128(index_accumulated)
    }

    /// calculate user gain index
    /// if farm:  gain = (current_index - last_index) * user_asset_weight; user_asset_weight = user_amount * boost_factor;
    /// if stake: gain = (current_index - last_index) * user_asset_weight; user_asset_weight = user_amount * stepwise_multiplier;
    public fun calculate_withdraw_amount(harvest_index: u128,
                                         last_harvest_index: u128,
                                         user_asset_weight: u128): u128 {
        assert!(harvest_index >= last_harvest_index, Errors::invalid_argument(ERR_FARMING_CALC_LAST_IDX_BIGGER_THAN_NOW));
        let amount_u256 = U256::mul(U256::from_u128(user_asset_weight), U256::from_u128(harvest_index - last_harvest_index));
        BigExponential::truncate(BigExponential::exp_from_u256(amount_u256))
    }


    /// Checking deadline time has arrived if deadline valid.
    fun assert_check_maybe_deadline(now_seconds: u64, deadline: u64) {
        // Calculate end time, if deadline is less than now then `deadline`, otherwise `now`.
        if (deadline > 0) {
            assert!(now_seconds > deadline, Errors::invalid_state(ERR_FARMING_OPT_AFTER_DEADLINE));
        };
    }

//    /// Pool state check function
//    fun intra_pool_state_check<PoolType: store,
//                               AssetT: store>(now_seconds: u64,
//                                              farming_asset: &FarmingAsset<PoolType, AssetT>) {
//        // Check is alive
//        assert!(farming_asset.alive, Errors::invalid_state(ERR_FARMING_NOT_ALIVE));
//
//        // Pool Start state check
//        assert!(now_seconds >= farming_asset.start_time, Errors::invalid_state(ERR_FARMING_NOT_READY));
//    }

    /// Pool state check function
    fun intra_pool_state_check<PoolType: store,
                               AssetT: store>(now_seconds: u64,
                                              farming_asset: &YieldFarmingAsset<PoolType, AssetT>) {
        // Check is alive
//        assert!(farming_asset.alive, Errors::invalid_state(ERR_FARMING_NOT_ALIVE));

        // Pool Start state check
        assert!(now_seconds >= farming_asset.start_time, Errors::invalid_state(ERR_FARMING_NOT_READY));
    }

    fun find_idx_by_id<PoolType: store,
                       AssetType: store>(c: &vector<Stake<PoolType, AssetType>>, id: u64): Option::Option<u64> {
        let len = Vector::length(c);
        if (len == 0) {
            return Option::none()
        };
        let idx = len - 1;
        loop {
            let el = Vector::borrow(c, idx);
            if (el.id == id) {
                return Option::some(idx)
            };
            if (idx == 0) {
                return Option::none()
            };
            idx = idx - 1;
        }
    }

    fun get_stake<PoolType: store,
                  AssetType: store>(c: &mut vector<Stake<PoolType, AssetType>>, id: u64): &mut Stake<PoolType, AssetType> {
        let idx = find_idx_by_id<PoolType, AssetType>(c, id);
        assert!(Option::is_some<u64>(&idx), Errors::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
        Vector::borrow_mut<Stake<PoolType, AssetType>>(c, Option::destroy_some<u64>(idx))
    }

    fun pop_stake<PoolType: store,
                  AssetType: store>(c: &mut vector<Stake<PoolType, AssetType>>, id: u64): Stake<PoolType, AssetType> {
        let idx = find_idx_by_id<PoolType, AssetType>(c, id);
        assert!(Option::is_some(&idx), Errors::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
        Vector::remove<Stake<PoolType, AssetType>>(c, Option::destroy_some<u64>(idx))
    }

    /// Check the Farming of TokenT is exists.
    public fun exists_at<PoolType: store, RewardTokenT: store>(broker: address): bool {
        exists<Farming<PoolType, RewardTokenT>>(broker)
    }

    /// Check the Farming of AsssetT is exists.
    public fun exists_asset_at<PoolType: store, AssetT: store>(broker: address): bool {
        exists<YieldFarmingAsset<PoolType, AssetT>>(broker)
    }

    /// Check stake at address exists.
    public fun exists_stake_at_address<PoolType: store, AssetT: store>(account: address): bool acquires StakeList{
        if (exists<StakeList<PoolType, AssetT>>(account) ){
            let stake_list = borrow_global<StakeList<PoolType, AssetT>>(account);
            let len = Vector::length(&stake_list.items);
            if (len > 0) {
                return true
            };
        };
        return false
    }
}
}