// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x4783d08fb16990bd35d83f3e23bf93b8 {

module YieldFarmingV3 {
    use 0x1::Token;
    use 0x1::Signer;
    use 0x1::Timestamp;
    use 0x1::Errors;
    use 0x1::Math;
    use 0x1::Option;
    use 0x1::Vector;


    use 0x4783d08fb16990bd35d83f3e23bf93b8::BigExponential;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::YieldFarmingLibrary;

    const ERR_FARMING_INIT_REPEATE: u64 = 101;
    const ERR_FARMING_NOT_STILL_FREEZE: u64 = 102;
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
    const ERR_FARMING_MULTIPLIER_OVERFLOW: u64 = 117;

    /// The object of yield farming
    /// RewardTokenT meaning token of yield farming
    struct Farming<PoolType, RewardTokenT> has key, store {
        treasury_token: Token::Token<RewardTokenT>,
    }

    struct FarmingAsset<PoolType, AssetT> has key, store {
        asset_total_weight: u128,
        harvest_index: u128,
        last_update_timestamp: u64,
        // Release count per seconds
        release_per_second: u128,
        // Start time, by seconds, user can operate stake only after this timestamp
        start_time: u64,
        // Representing the pool is alive, false: not alive, true: alive.
        alive: bool,
    }

    /// To store user's asset token
    struct Stake<PoolType, AssetT> has key, store {
        id: u64,
        asset: AssetT,
        asset_weight: u128,
        last_harvest_index: u128,
        gain: u128,
        asset_multiplier: u64,
    }

    struct StakeList<PoolType, AssetT> has key, store {
        next_id: u64,
        items: vector<Stake<PoolType, AssetT>>,
    }

    /// Capability to modify parameter such as period and release amount
    struct ParameterModifyCapability<PoolType, AssetT> has key, store {}

    /// Harvest ability to harvest
    struct HarvestCapability<PoolType, AssetT> has key, store {
        stake_id: u64,
    }

    /// Called by token issuer
    /// this will declare a yield farming pool
    public fun initialize<
        PoolType: store,
        RewardTokenT: store>(account: &signer, treasury_token: Token::Token<RewardTokenT>) {
        let scaling_factor = Math::pow(10, BigExponential::exp_scale_limition());
        let token_scale = Token::scaling_factor<RewardTokenT>();
        assert(token_scale <= scaling_factor, Errors::limit_exceeded(ERR_FARMING_TOKEN_SCALE_OVERFLOW));
        assert(!exists_at<PoolType, RewardTokenT>(Signer::address_of(account)), Errors::invalid_state(ERR_FARMING_INIT_REPEATE));

        move_to(account, Farming<PoolType, RewardTokenT>{
            treasury_token,
        });
    }

    /// Add asset pools
    public fun add_asset<PoolType: store, AssetT: store>(
        account: &signer,
        release_per_second: u128,
        delay: u64): ParameterModifyCapability<PoolType, AssetT> {
        assert(
            !exists_asset_at<PoolType, AssetT>(Signer::address_of(account)),
            Errors::invalid_state(ERR_FARMING_INIT_REPEATE)
        );

        let now_seconds = Timestamp::now_seconds();

        move_to(account, FarmingAsset<PoolType, AssetT>{
            asset_total_weight: 0,
            harvest_index: 0,
            last_update_timestamp: now_seconds,
            release_per_second,
            start_time: now_seconds + delay,
            alive: true
        });
        ParameterModifyCapability<PoolType, AssetT>{}
    }

    /// Remove asset for make this pool to the state of not alive
    /// Please make sure all user unstaking from this pool
    //    public fun remove_asset<PoolType: store, AssetT: store>(
    //        broker: address,
    //        cap: ParameterModifyCapability) acquires FarmingAsset {
    //        let ParameterModifyCapability {} = cap;
    //        let FarmingAsset<PoolType, AssetT> {
    //            asset_total_weight: _,
    //            harvest_index: _,
    //            last_update_timestamp: _,
    //            release_per_second: _,
    //            start_time: _,
    //            alive: _,
    //        } = move_from<FarmingAsset<PoolType, AssetT>>(broker);
    //    }

    public fun modify_parameter<PoolType: store, RewardTokenT: store, AssetT: store>(
        _cap: &ParameterModifyCapability<PoolType, AssetT>,
        broker: address,
        release_per_second: u128,
        alive: bool) acquires FarmingAsset {
        // Not support to shuttingdown alive state.
        assert(alive, Errors::invalid_state(ERR_FARMING_ALIVE_STATE_INVALID));
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        // assert(farming_asset.alive != alive, Errors::invalid_state(ERR_FARMING_ALIVE_STATE_INVALID));

        let now_seconds = Timestamp::now_seconds();
        farming_asset.last_update_timestamp = now_seconds;

        // if the pool is alive, then update index
        if (farming_asset.alive) {
            farming_asset.harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);
        };

        farming_asset.release_per_second = release_per_second;
        farming_asset.alive = alive;
    }

    /// Call by stake user, staking amount of asset in order to get yield farming token
    public fun stake<PoolType: store, RewardTokenT: store, AssetT: store>(
        signer: &signer,
        broker: address,
        asset: AssetT,
        asset_weight: u128,
        asset_multiplier: u64,
        _cap: &ParameterModifyCapability<PoolType, AssetT>) : (HarvestCapability<PoolType, AssetT>, u64)
    acquires StakeList, FarmingAsset {
        assert(exists_asset_at<PoolType, AssetT>(broker), Errors::invalid_state(ERR_FARMING_ASSET_NOT_EXISTS));
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);

        assert(farming_asset.alive, Errors::invalid_state(ERR_FARMING_NOT_ALIVE));
        if (farming_asset.asset_total_weight > 0) {
            assert(
                ((asset_multiplier as u128) * asset_weight) < farming_asset.asset_total_weight,
                Errors::invalid_state(ERR_FARMING_MULTIPLIER_OVERFLOW)
            );
        };

        // Check locking time
        let now_seconds = Timestamp::now_seconds();
        assert(farming_asset.start_time <= now_seconds, Errors::invalid_state(ERR_FARMING_NOT_STILL_FREEZE));

        let account = Signer::address_of(signer);
        if (!exists<StakeList<PoolType, AssetT>>(account)) {
            move_to(signer, StakeList<PoolType, AssetT>{
                next_id: 0,
                items: Vector::empty<Stake<PoolType, AssetT>>(),
            });
        };

        let time_period = now_seconds - farming_asset.last_update_timestamp;
        let (harvest_index, total_asset_weight, gain) = if (farming_asset.asset_total_weight <= 0) {
            (
                0,
                asset_weight,
                farming_asset.release_per_second * (time_period as u128)
            )
        } else {
            (
                calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds),
                farming_asset.asset_total_weight + asset_weight,
                0
            )
        };

        let items = borrow_global_mut<StakeList<PoolType, AssetT>>(account);
        items.next_id = items.next_id + 1;
        Vector::push_back<Stake<PoolType, AssetT>>(&mut items.items, Stake<PoolType, AssetT>{
            id: items.next_id,
            asset,
            asset_weight,
            last_harvest_index: harvest_index,
            gain,
            asset_multiplier,
        });

        farming_asset.harvest_index = harvest_index;
        farming_asset.asset_total_weight = total_asset_weight;
        farming_asset.last_update_timestamp = now_seconds;

        // Return values
        (
            HarvestCapability<PoolType, AssetT>{ stake_id: items.next_id },
            items.next_id
        )
    }

    /// Unstake asset from farming pool
    public fun unstake<PoolType: store, RewardTokenT: store, AssetT: store>(
        signer: &signer,
        broker: address,
        cap: HarvestCapability<PoolType, AssetT>)
    : (AssetT, Token::Token<RewardTokenT>) acquires Farming, FarmingAsset, StakeList {
        // Destroy capability
        let HarvestCapability<PoolType, AssetT>{ stake_id } = cap;

        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker);
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);

        let items = borrow_global_mut<StakeList<PoolType, AssetT>>(Signer::address_of(signer));

        let Stake<PoolType, AssetT>{
            id: out_stake_id,
            asset: stake_asset,
            asset_weight: stake_asset_weight,
            last_harvest_index: stake_latest_harvest_index,
            gain: stake_gain,
            asset_multiplier: stake_asset_multiplier,
        } = pop_stake<PoolType, AssetT>(&mut items.items, stake_id);

        assert(stake_id == out_stake_id, Errors::invalid_state(ERR_FARMING_STAKE_INDEX_ERROR));

        // Calculate harvest
        let now_seconds = Timestamp::now_seconds();
        let new_harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);

        let asset_weight = stake_asset_weight * (stake_asset_multiplier as u128);
        let period_gain = YieldFarmingLibrary::calculate_withdraw_amount(
            new_harvest_index,
            stake_latest_harvest_index,
            asset_weight,
        );

        let withdraw_token = Token::withdraw<RewardTokenT>(&mut farming.treasury_token, stake_gain + period_gain);
        assert(farming_asset.asset_total_weight >= asset_weight, Errors::invalid_state(ERR_FARMING_NOT_ENOUGH_ASSET));

        // Update farm asset
        farming_asset.asset_total_weight = farming_asset.asset_total_weight - asset_weight;
        farming_asset.last_update_timestamp = now_seconds;

        if (farming_asset.alive) {
            farming_asset.harvest_index = new_harvest_index;
        };

        (stake_asset, withdraw_token)
    }

    /// Harvest yield farming token from stake
    public fun harvest<PoolType: store,
                       RewardTokenT: store,
                       AssetT: store>(
        account: address,
        broker: address,
        amount: u128,
        cap: &HarvestCapability<PoolType, AssetT>): Token::Token<RewardTokenT> acquires Farming, FarmingAsset, StakeList {
        let farming = borrow_global_mut<Farming<PoolType, RewardTokenT>>(broker);
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);

        // Get stake from stake list
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(account);
        let stake = get_stake<PoolType, AssetT>(&mut stake_list.items, cap.stake_id);

        let now_seconds = Timestamp::now_seconds();
        let new_harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset, now_seconds);

        let period_gain = YieldFarmingLibrary::calculate_withdraw_amount(
            new_harvest_index,
            stake.last_harvest_index,
            stake.asset_weight
        );

        let total_gain = stake.gain + period_gain;
        //assert(total_gain > 0, Errors::limit_exceeded(ERR_FARMING_HAVERST_NO_GAIN));
        assert(total_gain >= amount, Errors::limit_exceeded(ERR_FARMING_BALANCE_EXCEEDED));

        let withdraw_amount = if (amount <= 0) {
            total_gain
        } else {
            amount
        };

        let withdraw_token = Token::withdraw<RewardTokenT>(&mut farming.treasury_token, withdraw_amount);
        stake.gain = total_gain - withdraw_amount;
        stake.last_harvest_index = new_harvest_index;

        if (farming_asset.alive) {
            farming_asset.harvest_index = new_harvest_index;
        };
        farming_asset.last_update_timestamp = now_seconds;

        withdraw_token
    }

    /// The user can quering all yield farming amount in any time and scene
    public fun query_gov_token_amount<PoolType: store,
                                      RewardTokenT: store,
                                      AssetT: store>(account: address, broker: address): u128 acquires FarmingAsset, Stake {
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        let stake = borrow_global_mut<Stake<PoolType, AssetT>>(account);
        let now_seconds = Timestamp::now_seconds();

        let new_harvest_index = calculate_harvest_index_with_asset<PoolType, AssetT>(
            farming_asset,
            now_seconds
        );

        let new_gain = YieldFarmingLibrary::calculate_withdraw_amount(
            new_harvest_index,
            stake.last_harvest_index,
            stake.asset_weight
        );

        stake.gain + new_gain
    }

    /// Query total stake count from yield farming resource
    public fun query_total_stake<PoolType: store,
                                 AssetT: store>(broker: address): u128 acquires FarmingAsset {
        let farming_asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        farming_asset.asset_total_weight
    }

    /// Query stake weight from user staking objects.
    public fun query_stake<PoolType: store,
                           AssetT: store>(account: address, id: u64): u128 acquires StakeList {
        let stake_list = borrow_global_mut<StakeList<PoolType, AssetT>>(account);
        let stake = get_stake(&mut stake_list.items, id);
        assert(stake.id == id, Errors::invalid_state(ERR_FARMING_STAKE_INDEX_ERROR));
        stake.asset_weight
    }

    /// Queyry pool info from pool type
    /// return value: (alive, release_per_second, asset_total_weight, harvest_index)
    public fun query_info<PoolType: store, AssetT: store>(broker: address): (bool, u128, u128, u128) acquires FarmingAsset {
        let asset = borrow_global_mut<FarmingAsset<PoolType, AssetT>>(broker);
        (
            asset.alive,
            asset.release_per_second,
            asset.asset_total_weight,
            asset.harvest_index
        )
    }

    /// Update farming asset
    fun calculate_harvest_index_with_asset<PoolType, AssetT>(farming_asset: &FarmingAsset<PoolType, AssetT>, now_seconds: u64): u128 {
        // Recalculate harvest index
        if (farming_asset.asset_total_weight <= 0) {
            YieldFarmingLibrary::calculate_harvest_index_weight_zero(
                farming_asset.harvest_index,
                farming_asset.last_update_timestamp,
                now_seconds,
                farming_asset.release_per_second
            )
        } else {
            YieldFarmingLibrary::calculate_harvest_index(
                farming_asset.harvest_index,
                farming_asset.asset_total_weight,
                farming_asset.last_update_timestamp,
                now_seconds,
                farming_asset.release_per_second
            )
        }
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
        assert(Option::is_none<u64>(&idx), Errors::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
        Vector::borrow_mut<Stake<PoolType, AssetType>>(c, Option::destroy_some<u64>(idx))
    }

    fun pop_stake<PoolType: store,
                  AssetType: store>(c: &mut vector<Stake<PoolType, AssetType>>, id: u64): Stake<PoolType, AssetType> {
        let idx = find_idx_by_id<PoolType, AssetType>(c, id);
        assert(Option::is_none(&idx), Errors::invalid_state(ERR_FARMING_STAKE_NOT_EXISTS));
        Vector::remove<Stake<PoolType, AssetType>>(c, Option::destroy_some<u64>(idx))
    }

    /// Check the Farming of TokenT is exists.
    public fun exists_at<PoolType: store, RewardTokenT: store>(broker: address): bool {
        exists<Farming<PoolType, RewardTokenT>>(broker)
    }

    /// Check the Farming of AsssetT is exists.
    public fun exists_asset_at<PoolType: store, AssetT: store>(broker: address): bool {
        exists<FarmingAsset<PoolType, AssetT>>(broker)
    }
}
}