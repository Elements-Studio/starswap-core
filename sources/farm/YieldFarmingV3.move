// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0


module swap_admin::YieldFarmingV3 {

    use std::error;
    use std::option;
    use std::signer;
    use std::string;
    use std::vector;

    use starcoin_framework::coin;
    use starcoin_framework::timestamp;

    use starcoin_std::debug;
    use starcoin_std::simple_map;
    use starcoin_std::type_info::type_name;

    use swap_admin::BigExponential;
    use swap_admin::STAR;
    use swap_admin::TokenSwapConfig;

    const ERR_DEPRECATED: u64 = 1;

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
    const ERR_INVALID_PARAMETER: u64 = 121;

    /// There are two concepts: **business pools** and **asset pools**, where a business pool contains multiple asset pools.
    ///
    //// 1. **Business pools** are represented by the structure `YieldFarmingGlobalPoolInfo`, with its type defined by the `TokenSwapGovPoolType.move` contract.
    ///  It controls the **total distribution amount per second** for all assets in the pool.
    ///
    /// 2. **Asset pools** are represented by the structure `FarmingAsset<phantom PoolType, phantom AssetT>`.
    /// The pool's assets are constrained by the parameter `AssetT`, and all `AssetT` assets share the per-second release amount defined in `PoolType`.
    /// The `alloc_point` indicates the **weight value** of the current asset pool.
    ///
    /// 3. When updating the `alloc_point` of an asset pool (indicating changes to the weight distribution across all pools),
    /// the **total allocation points** of the corresponding business pool must be recalculated.
    ///
    /// 4. For reward calculations: A user's rewards are determined by the pool's allocation points (`alloc_point`),
    /// which are used to compute the user's **weighted share**, and ultimately derive the final reward amount.
    ///
    struct YieldFarmingGlobalPoolInfo<phantom PoolType> has key, store {
        // total allocation points. Must be the sum of all allocation points in all pools,
        total_alloc_point: u128,
        //  Sigma (per pool alloc_point)
        pool_release_per_second: u128,
        // Registration of Asset type
        alloc_point_registration: simple_map::SimpleMap<string::String, u128>,
    }

    /// The object of yield farming
    /// RewardTokenT meaning token of yield farming
    struct Farming<phantom PoolType, phantom RewardTokenT> has key, store {
        treasury_token: coin::Coin<RewardTokenT>,
    }

    struct FarmingAsset<phantom PoolType, phantom AssetT> has key, store {
        // reform: before is actually equivalent to asset amount, after is equivalent to asset weight
        asset_total_weight: u128,
        // asset_total_weight: u128, // Sigma (per user lp_amount *  user boost_factor)
        asset_total_amount: u128,
        // Harvest index for current asset Pool
        harvest_index: u128,
        // This pool latest update time by user or calling
        last_update_timestamp: u64,
        // Start time, by seconds, user can operate stake only after this timestamp
        start_time: u64,
        // Pool alloc point
        alloc_point: u128,
    }

    /// To store user's asset token
    struct Stake<phantom PoolType, AssetT> has store, copy, drop {
        id: u64,
        asset: AssetT,
        asset_weight: u128,
        asset_amount: u128,
        // reform: before is actually equivalent to asset amount, after is equivalent to asset weight
        last_harvest_index: u128,
        gain: u128,
        //weight factor, if farm: weight_factor = user boost factor * 100; if stake: weight_factor = stepwise multiplier
        weight_factor: u64,
    }

    struct StakeList<phantom PoolType, AssetT> has key, store {
        next_id: u64,
        items: vector<Stake<PoolType, AssetT>>,
    }

    /// Capability to modify parameter such as period and release amount
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
    public fun initialize<PoolType: store, RewardTokenT>(
        account: &signer,
        treasury_token: coin::Coin<RewardTokenT>
    ) {
        let token_scale = coin::decimals<RewardTokenT>();
        assert!(
            token_scale <= BigExponential::exp_scale_limition(),
            error::out_of_range(ERR_FARMING_TOKEN_SCALE_OVERFLOW)
        );
        assert!(
            !exists_at<PoolType, RewardTokenT>(signer::address_of(account)),
            error::invalid_state(ERR_FARMING_INIT_REPEATE)
        );

        move_to(account, Farming<PoolType, RewardTokenT> {
            treasury_token,
        });
    }

    /// Called by admin
    /// this will config yield farming global pool info
    public fun initialize_global_pool_info<PoolType: store>(account: &signer, pool_release_per_second: u128) {
        TokenSwapConfig::assert_admin(account);

        assert!(!exists<YieldFarmingGlobalPoolInfo<PoolType>>(
            signer::address_of(account)),
            error::invalid_state(ERR_YIELD_FARMING_GLOBAL_POOL_INFO_ALREADY_EXIST)
        );

        move_to(account, YieldFarmingGlobalPoolInfo<PoolType> {
            total_alloc_point: 0,
            pool_release_per_second,
            alloc_point_registration: simple_map::new(),
        });
    }


    /// Called by admin
    /// this will reset release amount per second
    public fun modify_global_release_per_second_by_admin<PoolType: store>(
        account: &signer,
        pool_release_per_second: u128
    ) acquires YieldFarmingGlobalPoolInfo {
        let broker_addr = signer::address_of(account);
        assert!(pool_release_per_second > 0, error::invalid_state(ERR_INVALID_PARAMETER));
        assert!(
            exists<YieldFarmingGlobalPoolInfo<PoolType>>(broker_addr),
            error::invalid_state(ERR_INVALID_PARAMETER)
        );
        let pool_info =
            borrow_global_mut<YieldFarmingGlobalPoolInfo<PoolType>>(broker_addr);

        pool_info.pool_release_per_second = pool_release_per_second;
    }

    // /// DEPRECATED call
    // public fun modify_global_release_per_second<PoolType: store, AssetT: store>(
    //     _cap: &ParameterModifyCapability<PoolType, AssetT>,
    //     _broker: address,
    //     _pool_release_per_second: u128
    // ) {
    //     abort error::invalid_state(ERR_DEPRECATED)
    //     // assert!(pool_release_per_second > 0, error::invalid_state(ERR_INVALID_PARAMETER));
    //     // let pool_info =
    //     //     borrow_global_mut<YieldFarmingGlobalPoolInfo<PoolType>>(broker);
    //     // pool_info.pool_release_per_second = pool_release_per_second;
    // }

    /// Add asset pools v2
    /// Called only by admin
    public fun add_asset_v2<PoolType: store, AssetT: store>(
        account: &signer,
        alloc_point: u128, // pool alloc point
        delay: u64
    ): ParameterModifyCapability<PoolType, AssetT> acquires YieldFarmingGlobalPoolInfo {
        TokenSwapConfig::assert_admin(account);
        let address = signer::address_of(account);
        assert!(!exists_asset_at<PoolType, AssetT>(address), error::invalid_state(ERR_FARMING_INIT_REPEATE));
        let now_seconds = timestamp::now_seconds();

        //update global pool info total alloc point
        let golbal_pool_info = borrow_global_mut<YieldFarmingGlobalPoolInfo<PoolType>>(address);
        simple_map::add(&mut golbal_pool_info.alloc_point_registration, Self::get_asset_name<PoolType, AssetT>(), alloc_point);

        move_to(account, FarmingAsset<PoolType, AssetT> {
            asset_total_amount: 0,
            asset_total_weight: 0,
            harvest_index: 0,
            last_update_timestamp: now_seconds,
            start_time: now_seconds + delay,
            alloc_point,
        });

        Self::recal_total_alloc_point(golbal_pool_info);

        ParameterModifyCapability<PoolType, AssetT> {}
    }

    public fun deposit<PoolType: store, RewardTokenT>(
        treasury_token: coin::Coin<RewardTokenT>
    ) acquires Farming {
        let farming =
            borrow_global_mut<Farming<PoolType, RewardTokenT>>(STAR::token_address());
        coin::merge(&mut farming.treasury_token, treasury_token)
    }

    public fun withdraw<PoolType: store, RewardTokenT>(
        account: &signer,
        amount: u128
    ): coin::Coin<RewardTokenT> acquires Farming {
        STAR::assert_genesis_address(account);
        let farming =
            borrow_global_mut<Farming<PoolType, RewardTokenT>>(STAR::token_address());
        coin::extract<RewardTokenT>(&mut farming.treasury_token, (amount as u64))
    }

    /// modify parameter v2
    /// harvest_index = (current_timestamp - last_timestamp) * pool_release_per_second * (alloc_point/total_alloc_point)  / (asset_total_weight );
    /// gain = (current_index - last_index) * user_amount * boost_factor;
    /// asset_total_weight = Sigma (per user lp_amount *  user boost_factor)
    public fun update_pool<PoolType: store, RewardTokenT, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        broker: address,
        alloc_point: u128, //new pool alloc point
        _last_alloc_point: u128, //last pool alloc point
    ) acquires FarmingAsset, YieldFarmingGlobalPoolInfo {
        let now_seconds = timestamp::now_seconds();
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        // Calculate the index that has occurred first, and then update the pool info
        farming_asset.harvest_index = calculate_harvest_index_with_asset_v2<PoolType, AssetT>(
            farming_asset,
            now_seconds
        );
        farming_asset.last_update_timestamp = now_seconds;
        farming_asset.alloc_point = alloc_point;

        //update global pool info total alloc point
        let golbal_pool_info = borrow_global_mut<YieldFarmingGlobalPoolInfo<PoolType>>(broker);
        simple_map::upsert(
            &mut golbal_pool_info.alloc_point_registration,
            Self::get_asset_name<PoolType, AssetT>(),
            alloc_point,
        );
        Self::recal_total_alloc_point<PoolType>(golbal_pool_info);
    }

    /// call when weight_factor change, update pool info
    public fun update_pool_weight<PoolType: store, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        broker: address,
        new_asset_weight: u128, //new stake asset weight
        last_asset_weight: u128, //last stake asset weight
    ) acquires FarmingAsset, YieldFarmingGlobalPoolInfo {
        let now_seconds = timestamp::now_seconds();
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        // Calculate the index that has occurred first, and then update the pool info
        farming_asset.harvest_index = calculate_harvest_index_with_asset_v2<PoolType, AssetT>(
            farming_asset,
            now_seconds
        );
        //update pool asset weight
        farming_asset.last_update_timestamp = now_seconds;
        farming_asset.asset_total_weight = farming_asset.asset_total_weight - last_asset_weight + new_asset_weight;
    }

    /// call when weight_factor change, update stake info for user
    public fun update_pool_stake_weight<PoolType: store, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        broker: address,
        user_addr: address,
        stake_id: u64,
        new_weight_factor: u64, //new stake weight factor
        new_asset_weight: u128, //new stake asset weight
        _last_asset_weight: u128, //last stake asset weight
    ) acquires FarmingAsset, StakeList {
        let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);

        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let stake = Self::get_stake<PoolType, AssetT>(&mut stake_list.items, stake_id);

        let period_gain = calculate_withdraw_amount_v2(
            farming_asset.harvest_index,
            stake.last_harvest_index,
            stake.asset_weight
        );

        stake.gain = stake.gain + period_gain;
        stake.last_harvest_index = farming_asset.harvest_index;
        stake.asset_weight = new_asset_weight;
        stake.weight_factor = new_weight_factor;
    }

    /// Update the harvesting index of the pool for outside update some parameters
    /// This function is used to update the harvesting index of the pool and the related timestamp.
    public fun update_pool_index<PoolType: store, RewardTokenT, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        broker: address,
    ) acquires YieldFarmingGlobalPoolInfo, FarmingAsset {
        let now_seconds = timestamp::now_seconds();
        let farming_asset =
            borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);

        // Calculate the index that has occurred first, and then update the pool info
        farming_asset.harvest_index = calculate_harvest_index_with_asset_v2<PoolType, AssetT>(
            farming_asset,
            now_seconds
        );
        // Update pool harvest index
        farming_asset.last_update_timestamp = now_seconds;
    }

    /// Adjust total amount and total weight
    public fun adjust_total_amount<PoolType: store, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        broker: address,
        total_amount: u128,
        total_weight: u128,
    ) acquires FarmingAsset {
        let asset =
            borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);

        asset.asset_total_weight = total_weight;
        asset.asset_total_amount = total_amount;
    }

    /// Call by stake user, staking amount of asset in order to get yield farming token
    public fun stake_v2<PoolType: store, RewardTokenT, AssetT: store>(
        signer: &signer,
        broker_addr: address,
        asset: AssetT,
        asset_weight: u128,
        asset_amount: u128,
        weight_factor: u64, //if farm: weight_factor = user boost factor * 100; if stake: weight_factor = stepwise multiplier
        deadline: u64,
        _cap: &ParameterModifyCapability<PoolType, AssetT>)
    : (HarvestCapability<PoolType, AssetT>, u64) acquires StakeList, FarmingAsset, YieldFarmingGlobalPoolInfo {
        assert!(
            exists<FarmingAsset<PoolType, AssetT>>(broker_addr),
            error::invalid_state(ERR_FARMING_ASSET_NOT_EXISTS)
        );

        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker_addr);
        let now_seconds = timestamp::now_seconds();

        intra_pool_state_check_v2<PoolType, AssetT>(now_seconds, farming_asset);
        assert!(farming_asset.alloc_point > 0, error::invalid_state(ERR_FARMING_NOT_ALIVE));

        let user_addr = signer::address_of(signer);
        if (!exists<StakeList<PoolType, AssetT>>(user_addr)) {
            move_to(
                signer,
                StakeList<PoolType, AssetT> {
                    next_id: 0,
                    items: vector::empty<Stake<PoolType, AssetT>>(),
                }
            );
        };

        let (harvest_index, gain) = if (farming_asset.asset_total_weight <= 0) {
            let golbal_pool_info =
                borrow_global<YieldFarmingGlobalPoolInfo<PoolType>>(broker_addr);
            let time_period = now_seconds - farming_asset.last_update_timestamp;
            (
                0,
                golbal_pool_info.pool_release_per_second *
                    (time_period as u128) *
                    farming_asset.alloc_point /
                    golbal_pool_info.total_alloc_point
            )
        } else {
            (
                calculate_harvest_index_with_asset_v2<PoolType, AssetT>(
                    farming_asset,
                    now_seconds
                ),
                0
            )
        };

        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let stake_id = stake_list.next_id + 1;
        vector::push_back<Stake<PoolType, AssetT>>(
            &mut stake_list.items,
            Stake<PoolType, AssetT> {
                id: stake_id,
                asset,
                asset_amount,
                asset_weight,
                last_harvest_index: harvest_index,
                gain,
                weight_factor,
            }
        );

        farming_asset.harvest_index = harvest_index;
        farming_asset.asset_total_weight = farming_asset.asset_total_weight + asset_weight;
        farming_asset.last_update_timestamp = now_seconds;
        farming_asset.asset_total_amount = farming_asset.asset_total_amount + asset_amount;

        stake_list.next_id = stake_id;

        // Normalize deadline
        deadline = if (deadline > 0) { deadline + now_seconds } else { 0 };

        // Return values
        (
            HarvestCapability<PoolType, AssetT> {
                stake_id,
                deadline,
            },
            stake_id,
        )
    }


    /// Unstake asset from farming pool
    public fun unstake<PoolType: store, RewardTokenT, AssetT: store>(
        signer: &signer,
        broker: address,
        cap: HarvestCapability<PoolType, AssetT>
    ): (AssetT, coin::Coin<RewardTokenT>)
    acquires Farming, FarmingAsset, StakeList, YieldFarmingGlobalPoolInfo {
        // Destroy capability
        let HarvestCapability<PoolType, AssetT> { stake_id, deadline } = cap;

        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker);
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        let now_seconds = timestamp::now_seconds();

        //intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);
        assert!(now_seconds >= farming_asset.start_time, error::invalid_state(ERR_FARMING_NOT_READY));
        let items = borrow_global_mut<StakeList<PoolType, AssetT>>(signer::address_of(signer));

        let Stake<PoolType, AssetT> {
            id: out_stake_id,
            asset: staked_asset,
            asset_amount: asset_amount,
            asset_weight: asset_weight,
            last_harvest_index: staked_latest_harvest_index,
            gain: staked_gain,
            weight_factor: _weight_factor
        } = pop_stake<PoolType, AssetT>(&mut items.items, stake_id);

        assert!(stake_id == out_stake_id, error::invalid_state(ERR_FARMING_STAKE_INDEX_ERROR));
        assert_check_maybe_deadline(now_seconds, deadline);


        let new_harvest_index = calculate_harvest_index_with_asset_v2<PoolType, AssetT>(
            farming_asset,
            now_seconds
        );

        //TODO how to cacl compatible ? asset_weight = staked_asset_weight or asset_weight = staked_asset_weight * staked_weight_factor ?
        let period_gain = calculate_withdraw_amount_v2(
            new_harvest_index,
            staked_latest_harvest_index,
            asset_weight
        );

        let withdraw_token = coin::extract<RewardTokenT>(
            &mut farming.treasury_token,
            (staked_gain + period_gain as u64)
        );
        assert!(farming_asset.asset_total_weight >= asset_weight, error::invalid_state(ERR_FARMING_NOT_ENOUGH_ASSET));

        // Update farm asset
        farming_asset.harvest_index = new_harvest_index;
        farming_asset.asset_total_weight = farming_asset.asset_total_weight - asset_weight;
        farming_asset.asset_total_amount = farming_asset.asset_total_amount - asset_amount;
        farming_asset.last_update_timestamp = now_seconds;

        (staked_asset, withdraw_token)
    }

    /// Harvest yield farming token from stake
    public fun harvest<PoolType: store, RewardTokenT, AssetT: store>(
        user_addr: address,
        broker_addr: address,
        amount: u128,
        cap: &HarvestCapability<PoolType, AssetT>
    ): coin::Coin<RewardTokenT> acquires Farming, FarmingAsset, StakeList, YieldFarmingGlobalPoolInfo {
        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker_addr);
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker_addr);

        // Start check
        let now_seconds = timestamp::now_seconds();
        // intra_pool_state_check<PoolType, AssetT>(now_seconds, farming_asset);
        assert!(now_seconds >= farming_asset.start_time, error::invalid_state(ERR_FARMING_NOT_READY));

        // Get stake from stake list
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let stake = get_stake<PoolType, AssetT>(&mut stake_list.items, cap.stake_id);

        assert_check_maybe_deadline(now_seconds, cap.deadline);

        let new_harvest_index = calculate_harvest_index_with_asset_v2<PoolType, AssetT>(
            farming_asset,
            now_seconds
        );
        let period_gain = calculate_withdraw_amount_v2(
            new_harvest_index,
            stake.last_harvest_index,
            stake.asset_weight
        );

        let total_gain = stake.gain + period_gain;
        //assert!(total_gain > 0, error::limit_exceeded(ERR_FARMING_HAVERST_NO_GAIN));
        assert!(total_gain >= amount, error::out_of_range(ERR_FARMING_BALANCE_EXCEEDED));

        let withdraw_amount = if (amount <= 0) {
            total_gain
        } else {
            amount
        };

        // Update stake
        let withdraw_token = coin::extract<RewardTokenT>(
            &mut farming.treasury_token,
            (withdraw_amount as u64)
        );
        stake.gain = total_gain - withdraw_amount;
        stake.last_harvest_index = new_harvest_index;

        // Update farming asset
        farming_asset.harvest_index = new_harvest_index;
        farming_asset.last_update_timestamp = now_seconds;

        withdraw_token
    }


    /// The user can quering all yield farming amount in any time and scene
    public fun query_expect_gain<PoolType: store, RewardTokenT, AssetT: store>(
        user_addr: address,
        broker_addr: address,
        cap: &HarvestCapability<PoolType, AssetT>
    ): u128 acquires FarmingAsset, StakeList, YieldFarmingGlobalPoolInfo {
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker_addr);
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);

        debug::print(&string::utf8(b"YieldFarmingV3::query_expect_gain | show farming_asset and stake_list"));
        debug::print(&user_addr);
        debug::print(farming_asset);
        debug::print(stake_list);

        // Start check
        let now_seconds = timestamp::now_seconds();
        assert!(now_seconds >= farming_asset.start_time, error::invalid_state(ERR_FARMING_NOT_READY));

        // Calculate from latest timestamp to deadline timestamp if deadline valid
        now_seconds = if (now_seconds > cap.deadline) {
            now_seconds
        } else {
            cap.deadline
        };

        let stake = Self::get_stake(&mut stake_list.items, cap.stake_id);
        // Calculate new harvest index
        let new_harvest_index = calculate_harvest_index_with_asset_v2<PoolType, AssetT>(
            farming_asset,
            now_seconds
        );
        let new_gain = Self::calculate_withdraw_amount_v2(
            new_harvest_index,
            stake.last_harvest_index,
            stake.asset_weight
        );
        debug::print(&string::utf8(b"YieldFarmingV3::query_expect_gain | new gain: "));
        debug::print(&new_harvest_index);
        debug::print(&new_gain);
        stake.gain + new_gain
    }


    /// Get the total pledge amount under the specified Token type pool
    /// @return farming_asset_extend.asset_total_amount
    public fun query_total_stake<PoolType: store, AssetT: store>(
        broker: address
    ): u128 acquires FarmingAsset {
        let farming_asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.asset_total_amount
    }

    /// Query stake from user staking objects.
    public fun query_stake<PoolType: store, AssetT: store>(
        account: address,
        id: u64
    ): u128 acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(account);
        let stake = Self::get_stake(&mut stake_list.items, id);
        assert!(stake.id == id, error::invalid_state(ERR_FARMING_STAKE_INDEX_ERROR));
        stake.asset_amount
    }


    /// Get the total pledge weight under the specified Token type pool by account staking
    /// @return total stake weight by user
    public fun query_stake_weight<PoolType: store, AssetT: store>(account: address): u128 acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(account);
        let len = vector::length(&stake_list.items);
        if (len <= 0) {
            return 0
        };

        let i = 0;
        let account_total_stake_weight: u128 = 0;
        loop {
            if (i >= len) {
                break
            };
            let stake_item = vector::borrow(&stake_list.items, i);
            account_total_stake_weight = account_total_stake_weight + stake_item.asset_weight;
            i = i + 1;
        };
        account_total_stake_weight
    }

    /// Query stake id list from user
    public fun query_stake_list<PoolType: store, AssetT: store>(user_addr: address): vector<u64> acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let len = vector::length(&stake_list.items);
        if (len <= 0) {
            return vector::empty<u64>()
        };

        let ret_list = vector::empty<u64>();
        let idx = 0;
        loop {
            if (idx >= len) {
                break
            };
            let stake = vector::borrow<Stake<PoolType, AssetT>>(&stake_list.items, idx);
            vector::push_back(&mut ret_list, stake.id);
            idx = idx + 1;
        };
        ret_list
    }

    /// Query pool info from pool type v2
    /// return value: (alloc_point, asset_total_amount, asset_total_weight, harvest_index)
    public fun query_pool_info_v2<PoolType: store, AssetT: store>(
        broker: address
    ): (u128, u128, u128, u128) acquires FarmingAsset {
        let asset = borrow_global<FarmingAsset<PoolType, AssetT>>(broker);
        (
            asset.alloc_point,
            asset.asset_total_amount,
            asset.asset_total_weight,
            asset.harvest_index
        )
    }

    /// Queyry global pool info
    /// return value: (total_alloc_point, pool_release_per_second)
    public fun query_global_pool_info<PoolType: store>(
        broker: address
    ): (u128, u128) acquires YieldFarmingGlobalPoolInfo {
        let global_pool_info =
            borrow_global<YieldFarmingGlobalPoolInfo<PoolType>>(broker);
        (
            global_pool_info.total_alloc_point,
            global_pool_info.pool_release_per_second,
        )
    }


    /// calculate pool harvest index
    /// harvest_index = (current_timestamp - last_timestamp) * pool_release_per_second * (alloc_point/total_alloc_point)  / (asset_total_weight );
    /// if farm:   asset_total_weight = Sigma (per user lp_amount *  user boost_factor)
    /// if stake:  asset_total_weight = Sigma (per user lp_amount *  stepwise_multiplier)
    fun calculate_harvest_index_with_asset_v2<PoolType: store, AssetT: store>(
        farming_asset: &FarmingAsset<PoolType, AssetT>,
        now_seconds: u64
    ): u128 acquires YieldFarmingGlobalPoolInfo {
        assert!(
            farming_asset.last_update_timestamp <= now_seconds,
            error::invalid_argument(ERR_FARMING_TIMESTAMP_INVALID)
        );

        let golbal_pool_info =
            borrow_global<YieldFarmingGlobalPoolInfo<PoolType>>(@swap_admin);

        // Not any pool have alloc point
        if (golbal_pool_info.total_alloc_point <= 0) {
            return farming_asset.harvest_index
        };

        let time_period = now_seconds - farming_asset.last_update_timestamp;
        let global_pool_reward = golbal_pool_info.pool_release_per_second * (time_period as u128);
        let pool_reward = BigExponential::exp(
            global_pool_reward * farming_asset.alloc_point,
            golbal_pool_info.total_alloc_point
        );

        // calculate period harvest index and global pool info when asset_total_weight is zero
        let harvest_index_period = if (farming_asset.asset_total_weight <= 0) {
            BigExponential::mantissa(pool_reward)
        } else {
            BigExponential::mantissa(
                BigExponential::div_exp(pool_reward, BigExponential::exp_direct(farming_asset.asset_total_weight))
            )
        };
        BigExponential::to_safe_u128(((farming_asset.harvest_index as u256) + harvest_index_period))
    }

    fun recal_total_alloc_point<PoolType: store>(info: &mut YieldFarmingGlobalPoolInfo<PoolType>) {
        let values = simple_map::values(&info.alloc_point_registration);
        let total_value = 0;
        let len = vector::length(&values);
        loop {
            let i = 0;
            total_value = total_value + *vector::borrow(&values, i);
            i = i + 1;
            if (i >= len) {
                break
            }
        };
        info.total_alloc_point = total_value;
    }

    fun get_asset_name<PoolType, AssetT>(): string::String {
        let name = type_name<PoolType>();
        string::append(&mut name, string::utf8(b"::"));
        string::append(&mut name, type_name<AssetT>());
        name
    }

    /// calculate user gain index
    /// if farm:  gain = (current_index - last_index) * user_asset_weight; user_asset_weight = user_amount * boost_factor;
    /// if stake: gain = (current_index - last_index) * user_asset_weight; user_asset_weight = user_amount * stepwise_multiplier;
    public fun calculate_withdraw_amount_v2(
        harvest_index: u128,
        last_harvest_index: u128,
        user_asset_weight: u128
    ): u128 {
        assert!(
            harvest_index >= last_harvest_index,
            error::invalid_argument(ERR_FARMING_CALC_LAST_IDX_BIGGER_THAN_NOW)
        );
        let amount_u256 =
            (user_asset_weight as u256) * ((harvest_index - last_harvest_index) as u256);
        BigExponential::truncate(BigExponential::exp_from_u256(amount_u256))
    }

    /// Checking deadline time has arrived if deadline valid.
    fun assert_check_maybe_deadline(now_seconds: u64, deadline: u64) {
        // Calculate end time, if deadline is less than now then `deadline`, otherwise `now`.
        if (deadline > 0) {
            assert!(now_seconds > deadline, error::invalid_state(ERR_FARMING_OPT_AFTER_DEADLINE));
        };
    }


    /// Pool state check function
    fun intra_pool_state_check_v2<PoolType: store, AssetT: store>(
        now_seconds: u64,
        farming_asset: &FarmingAsset<PoolType, AssetT>
    ) {
        // Pool Start state check
        assert!(now_seconds >= farming_asset.start_time, error::invalid_state(ERR_FARMING_NOT_READY));
    }

    fun find_idx_by_id<PoolType: store, AssetType: store>(
        c: &vector<Stake<PoolType, AssetType>>,
        id: u64
    ): option::Option<u64> {
        let len = vector::length(c);
        if (len == 0) {
            return option::none()
        };
        let idx = len - 1;
        loop {
            let el = vector::borrow(c, idx);
            if (el.id == id) {
                return option::some(idx)
            };
            if (idx == 0) {
                return option::none()
            };
            idx = idx - 1;
        }
    }

    fun get_stake<PoolType: store, AssetType: store>(
        c: &mut vector<Stake<PoolType, AssetType>>,
        id: u64
    ): &mut Stake<PoolType, AssetType> {
        let idx = Self::find_idx_by_id<PoolType, AssetType>(c, id);
        assert!(option::is_some<u64>(&idx), error::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
        vector::borrow_mut<Stake<PoolType, AssetType>>(c, option::destroy_some<u64>(idx))
    }

    fun pop_stake<PoolType: store, AssetType: store>(
        c: &mut vector<Stake<PoolType, AssetType>>,
        id: u64
    ): Stake<PoolType, AssetType> {
        let idx = Self::find_idx_by_id<PoolType, AssetType>(c, id);
        assert!(option::is_some(&idx), error::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
        vector::remove<Stake<PoolType, AssetType>>(c, option::destroy_some<u64>(idx))
    }

    public fun get_stake_info<PoolType: store, AssetT: store>(
        account: &signer,
        stake_id: u64
    ): (u64, u128, u128, u128, u64, u128, u64) acquires StakeList {
        let user_addr = signer::address_of(account);
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(user_addr);
        let stake = Self::get_stake<PoolType, AssetT>(&mut stake_list.items, stake_id);

        (stake.id, stake.asset_weight, stake.last_harvest_index, stake.gain, 0, stake.asset_amount, stake.weight_factor)
    }

    /// View Treasury Remaining
    public fun get_treasury_balance<PoolType: store, RewardTokenT>(broker: address): u128 acquires Farming {
        let farming = borrow_global<Farming<PoolType, RewardTokenT>>(broker);
        (coin::value<RewardTokenT>(&farming.treasury_token) as u128)
    }

    /// Get global stake id
    public fun get_global_stake_id<PoolType: store, AssetT: store>(user_addr: address): u64 acquires StakeList {
        let stake_list = borrow_global<StakeList<PoolType, AssetT>>(user_addr);
        stake_list.next_id
    }

    /// Get information by given capability
    public fun get_info_from_cap<PoolT: store, AssetT: store>(cap: &HarvestCapability<PoolT, AssetT>): (u64, u64) {
        (cap.stake_id, cap.deadline)
    }

    /// Check the Farming of TokenT is exists.
    public fun exists_at<PoolType: store, RewardTokenT>(broker: address): bool {
        exists<Farming<PoolType, RewardTokenT>>(broker)
    }

    /// Check the Farming of AsssetT is exists.
    public fun exists_asset_at<PoolType: store, AssetT: store>(broker: address): bool {
        exists<FarmingAsset<PoolType, AssetT>>(broker)
    }

    /// Check stake at address exists.
    public fun exists_stake_at_address<PoolType: store, AssetT: store>(account: address): bool acquires StakeList {
        if (exists<StakeList<PoolType, AssetT>>(account)) {
            let stake_list = borrow_global<StakeList<PoolType, AssetT>>(account);
            let len = vector::length(&stake_list.items);
            if (len > 0) {
                return true
            };
        };
        return false
    }

    /// Check stake list at address exists.
    public fun exists_stake_list<PoolType: store, AssetT: store>(account: address): bool {
        return exists<StakeList<PoolType, AssetT>>(account)
    }
}