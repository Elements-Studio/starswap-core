address SwapAdmin {

module TokenSwapMultiPool {

    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Vector;
    use StarcoinFramework::BCS;
    use StarcoinFramework::Timestamp;

    use SwapAdmin::IDizedSet;
    use SwapAdmin::TokenSwapConfig;

    const ERROR_NOT_ADMIN: u64 = 101;
    const MUL_POOL_KEY_PREFIX: vector<u8> = b"MUL-";

    struct Pools<phantom PoolType, phantom AssetT> has key {
        pool_set: IDizedSet::Set<PoolItem<PoolType, AssetT>>,
        total_weight_no_pool: u128,
    }

    struct PoolItem<phantom PoolType, phantom AssetT> has store {
        asset_weight: u128,
        asset_amount: u128,
        multiplier: u64,
        update_records: vector<UpdateRecord>,
    }

    struct UpdateRecord has store {
        update_time: u64,
        multiplier: u64,
    }

    struct Stakes<phantom PoolType, phantom AssetT> has key {
        stake_set: IDizedSet::Set<StakeItem<PoolType, AssetT>>
    }

    struct StakeItem<phantom PoolType, phantom AssetT> has store {
        asset_weight: u128,
        asset_amount: u128,
        multiplier: u64,
        update_time: u64,
        pool_key: vector<u8>,
    }

    struct MutiPoolCapability<phantom PoolType, phantom AssetT> has key, store {}

    /// Initialize from total asset weight and amount
    public fun init<P, A>(signer: &signer, no_pool_weight: u128): MutiPoolCapability<P, A> {
        move_to(signer, Pools{
            pool_set: IDizedSet::empty<PoolItem<P, A>>(),
            total_weight_no_pool: no_pool_weight
        });
        MutiPoolCapability<P, A>{}
    }

    /// Uninitialize called by caller
    public fun destroy<P, A>(cap: &MutiPoolCapability<P, A>) {
        let MutiPoolCapability<P, A>{} = cap;
    }

    /// Add new multiplier pool by admin, update it if exists.
    /// @param key: The key name of pool
    ///
    public fun put_pool<P, A>(signer: &signer,
                              time_cycle: u64,
                              new_multiplier: u64,
                              _cap: &MutiPoolCapability<P, A>)
    acquires Pools {
        let broker = Signer::address_of(signer);
        require_admin(broker);

        let pool_key = get_pool_key_by_time(time_cycle);
        let pools = borrow_global_mut<Pools<P, A>>(broker);

        if (IDizedSet::exists_at(&pools.pool_set, &pool_key)) {
            update<P, A>(broker, &pool_key, new_multiplier)
        } else {
            IDizedSet::push_back(&mut pools.pool_set, &pool_key, PoolItem<P, A>{
                asset_weight: 0,
                asset_amount: 0,
                multiplier: new_multiplier,
                update_records: Vector::empty<UpdateRecord>(),
            });
        }
    }

    /// Remove an exists multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun remove_pool<P, A>(signer: &signer, time_cycle: u64, _cap: &MutiPoolCapability<P, A>) acquires Pools {
        let broker = Signer::address_of(signer);
        require_admin(broker);

        let pool_key = get_pool_key_by_time(time_cycle);
        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let PoolItem<P, A>{
            asset_weight: _,
            asset_amount: _,
            multiplier: _,
            update_records,
        } = IDizedSet::remove(&mut pools.pool_set, &pool_key);

        // Pop all record and destroy it
        loop {
            if (Vector::is_empty(&update_records)) {
                break
            };
            let UpdateRecord{
                update_time: _,
                multiplier: _
            } = Vector::pop_back(&mut update_records);
        };
        Vector::destroy_empty(update_records);
    }

    /// Add weight to a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun add_stake<P, A>(signer: &signer,
                               time_cycle: u64,
                               stake_id: u64,
                               amount: u128,
                               _cap: &MutiPoolCapability<P, A>)
    acquires Pools, Stakes {
        let broker = TokenSwapConfig::admin_address();
        let user = Signer::address_of(signer);

        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let pool_key = get_pool_key_by_time(time_cycle);
        let pool_item = IDizedSet::borrow_mut(&mut pools.pool_set, &pool_key);

        pool_item.asset_amount = pool_item.asset_amount + amount;
        pool_item.asset_weight = pool_item.asset_amount * (pool_item.multiplier as u128);

        if (!exists<Stakes<P, A>>(user)) {
            let stake_set = IDizedSet::empty<StakeItem<P, A>>();
            IDizedSet::push_back<StakeItem<P, A>>(&mut stake_set, &id_to_str(stake_id), StakeItem<P, A>{
                asset_weight: amount * (pool_item.multiplier as u128),
                asset_amount: amount,
                multiplier: pool_item.multiplier,
                pool_key,
                update_time: Timestamp::now_seconds(),
            });

            move_to(signer, Stakes<P, A>{
                stake_set,
            });
        } else {
            let stakes = borrow_global_mut<Stakes<P, A>>(user);
            IDizedSet::push_back<StakeItem<P, A>>(&mut stakes.stake_set, &id_to_str(stake_id), StakeItem<P, A>{
                asset_weight: amount * (pool_item.multiplier as u128),
                asset_amount: amount,
                multiplier: pool_item.multiplier,
                pool_key,
                update_time: Timestamp::now_seconds(),
            });
        }
    }

    /// Add weight from a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun remove_stake<P, A>(signer: &signer,
                                  stake_id: u64,
                                  _cap: &MutiPoolCapability<P, A>)
    acquires Pools, Stakes {
        let broker = TokenSwapConfig::admin_address();
        let user = Signer::address_of(signer);

        let stakes = borrow_global_mut<Stakes<P, A>>(user);
        let stake_item = IDizedSet::borrow<StakeItem<P, A>>(&mut stakes.stake_set, &id_to_str(stake_id));

        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let pool_item = IDizedSet::borrow_mut(&mut pools.pool_set, &stake_item.pool_key);

        pool_item.asset_amount = pool_item.asset_amount - stake_item.asset_amount;
        pool_item.asset_weight = pool_item.asset_amount * (pool_item.multiplier as u128);
    }

    public fun calculate_suitable_weight<P, A>(user: address,
                                               stake_id: u64,
                                               settle_time: u64): (u64, u128)
    acquires Pools, Stakes {
        let broker = TokenSwapConfig::admin_address();

        let stakes = borrow_global_mut<Stakes<P, A>>(user);
        let stake_item = IDizedSet::borrow<StakeItem<P, A>>(&mut stakes.stake_set, &id_to_str(stake_id));

        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let pool_item = IDizedSet::borrow_mut(&mut pools.pool_set, &stake_item.pool_key);

        compute_suitable_stake_weight_by_records(
            &pool_item.update_records,
            stake_item.asset_amount,
            stake_item.multiplier,
            stake_item.update_time,
            settle_time)
    }

    /// Compute weight by given records, and return suiteable new multiplier
    public fun compute_suitable_stake_weight_by_records(records: &vector<UpdateRecord>,
                                                        stake_amount: u128,
                                                        stake_multiplier: u64,
                                                        stake_start_time: u64,
                                                        stake_end_time: u64): (u64, u128) {
        let record_len = Vector::length(records);
        let idx = 0;
        let scale = 1000;
        let suitable_multiplier = stake_multiplier * scale;

        // query total stake time
        let stake_time_interval = stake_end_time - stake_start_time;
        let last_time = stake_start_time;

        if (record_len > 0) {
            loop {
                let record_item = Vector::borrow(records, idx);
                if (record_item.update_time > last_time) {
                    let time_weight = record_item.update_time - last_time;
                    suitable_multiplier = suitable_multiplier + ((record_item.multiplier * time_weight * scale) / stake_time_interval);
                };
                last_time = record_item.update_time;

                idx = idx + 1;
                if (idx >= record_len) {
                    break
                };
            };
        };
        (suitable_multiplier, (stake_amount * ((suitable_multiplier / scale) as u128)))
    }


    /// Query pool by key
    /// @return (multiplier, asset_weight, asset_amount)
    public fun query_pool_info<P, A>(time_cycle: u64): (u64, u128, u128)
    acquires Pools {
        let broker = TokenSwapConfig::admin_address();
        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let pool_key = get_pool_key_by_time(time_cycle);
        let pool_item = IDizedSet::borrow_mut(&mut pools.pool_set, &pool_key);
        (
            pool_item.multiplier,
            pool_item.asset_weight,
            pool_item.asset_amount
        )
    }

    /// Query total amount and weight in pool
    /// @return (pool_amount, pool_weight, no_pool_weight)
    public fun query_tvl<P, A>(): (u128, u128, u128) acquires Pools {
        let broker = TokenSwapConfig::admin_address();
        let pools = borrow_global_mut<Pools<P, A>>(broker);

        let len = IDizedSet::length(&pools.pool_set);
        let pool_amount = 0;
        let pool_weight = 0;

        if (len == 0) {
            return (pool_amount, pool_weight, pools.total_weight_no_pool)
        };

        let idx = len - 1;
        loop {
            let pool = IDizedSet::borrow_idx(&pools.pool_set, idx);
            pool_weight = pool_weight + pool.asset_weight;
            pool_amount = pool_amount + pool.asset_amount;
            if (idx <= 0) {
                break
            };
            idx = idx - 1;
        };
        (pool_amount, pool_weight, pools.total_weight_no_pool)
    }

    public fun get_pool_key_by_time(time_cycle: u64): vector<u8> {
        let result = Vector::empty<u8>();
        Vector::append(&mut result, MUL_POOL_KEY_PREFIX);
        Vector::append(&mut result, BCS::to_bytes(&time_cycle));
        result
    }

    /// Update multiplier pool
    /// @param key: The key name of pool
    /// @return new weight
    ///
    fun update<P, A>(broker: address,
                     key: &vector<u8>,
                     multiplier: u64)
    acquires Pools {
        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let pool_item = IDizedSet::borrow_mut(&mut pools.pool_set, key);

        pool_item.multiplier = multiplier;
        pool_item.asset_weight = pool_item.asset_amount * (multiplier as u128);

        Vector::push_back(&mut pool_item.update_records, UpdateRecord{
            update_time: Timestamp::now_seconds(),
            multiplier,
        });
    }

    fun id_to_str(_id: u64): vector<u8> {
        BCS::to_bytes(&_id)
    }

    fun require_admin(user_addr: address) {
        assert!(TokenSwapConfig::admin_address() == user_addr, Errors::invalid_state(ERROR_NOT_ADMIN));
    }
}
}
