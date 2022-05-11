address SwapAdmin {

module TokenSwapMutiPool {

    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;

    use SwapAdmin::IDizedSet;
    use SwapAdmin::TokenSwapConfig;
    use StarcoinFramework::Vector;

    const ERROR_NOT_ADMIN: u64 = 101;

    struct Pools<phantom PoolType, phantom AssetT> has key {
        pool_set: IDizedSet::Set<PoolItem<PoolType, AssetT>>,
    }

    struct PoolItem<phantom PoolType, phantom AssetT> has store {
        asset_weight: u128,
        asset_amount: u128,
        multiplier: u64,
    }

    struct Stakes<phantom PoolType, phantom AssetT> has key {
        stake_set: IDizedSet::Set<StakeItem<PoolType, AssetT>>
    }

    struct StakeItem<phantom PoolType, phantom AssetT> has store {
        asset_weight: u128,
        asset_amount: u128,
        multiplier: u64,
        pool_key: vector<u8>,
    }

    struct MutiPoolCapability<phantom PoolType, phantom AssetT> {}

    /// Initialize from total asset weight and amount
    public fun init<P, A>(signer: &signer): MutiPoolCapability<P, A> {
        move_to(signer, Pools{
            pool_set: IDizedSet::empty<PoolItem<P, A>>()
        });
        MutiPoolCapability<P, A>{}
    }

    /// Uninitialize called by caller
    public fun destroy<P, A>(cap: &MutiPoolCapability<P, A>) {
        let MutiPoolCapability<P, A>{} = cap;
    }

    /// Add new multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun add_pool<P, A>(signer: &signer, key: &vector<u8>, multiplier: u64) acquires Pools {
        let broker = Signer::address_of(signer);
        require_admin(broker);

        let pools = borrow_global_mut<Pools<P, A>>(broker);
        IDizedSet::push_back(&mut pools.pool_set, key, PoolItem<P, A>{
            asset_weight: 0,
            asset_amount: 0,
            multiplier
        });
    }

    /// Remove an exists multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun remove_pool<P, A>(signer: &signer, key: &vector<u8>) acquires Pools {
        let broker = Signer::address_of(signer);
        require_admin(broker);

        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let PoolItem<P, A>{
            asset_weight: _,
            asset_amount: _,
            multiplier: _,
        } = IDizedSet::remove(&mut pools.pool_set, key);
    }

    /// Update multiplier pool
    /// @param key: The key name of pool
    /// @return new weight
    ///
    public fun update<P, A>(signer: &signer, key: &vector<u8>, multiplier: u64): u128 acquires Pools {
        let broker = Signer::address_of(signer);
        require_admin(broker);

        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let pool_item = IDizedSet::borrow_mut(&mut pools.pool_set, key);

        pool_item.multiplier = multiplier;
        pool_item.asset_weight = pool_item.asset_amount * (multiplier as u128);
        pool_item.asset_weight
    }

    /// Add weight to a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun add_asset<P, A>(signer: &signer, pool_key: &vector<u8>, stake_id: u64, amount: u128) acquires Pools, Stakes {
        let broker = TokenSwapConfig::admin_address();
        let user = Signer::address_of(signer);

        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let pool_item = IDizedSet::borrow_mut(&mut pools.pool_set, pool_key);

        pool_item.asset_amount = pool_item.asset_amount + amount;
        pool_item.asset_weight = pool_item.asset_amount * (pool_item.multiplier as u128);

        if (!exists<Stakes<P, A>>(user)) {
            let stake_set = IDizedSet::empty<StakeItem<P, A>>();
            IDizedSet::push_back<StakeItem<P, A>>(&mut stake_set, &to_str(stake_id), StakeItem<P, A>{
                asset_weight: amount * (pool_item.multiplier as u128),
                asset_amount: amount,
                multiplier: pool_item.multiplier,
                pool_key: *pool_key
            });

            move_to(signer, Stakes<P, A>{
                stake_set,
            });
        } else {
            let stakes = borrow_global_mut<Stakes<P, A>>(user);
            IDizedSet::push_back<StakeItem<P, A>>(&mut stakes.stake_set, &to_str(stake_id), StakeItem<P, A>{
                asset_weight: amount * (pool_item.multiplier as u128),
                asset_amount: amount,
                multiplier: pool_item.multiplier,
                pool_key: *pool_key
            });
        }
    }

    /// Add weight from a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun remove_asset<P, A>(signer: &signer, pool_key: &vector<u8>, stake_id: u64) acquires Pools, Stakes {
        let broker = TokenSwapConfig::admin_address();
        let user = Signer::address_of(signer);

        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let pool_item = IDizedSet::borrow_mut(&mut pools.pool_set, pool_key);

        let stakes = borrow_global_mut<Stakes<P, A>>(user);
        let stake_item = IDizedSet::borrow<StakeItem<P, A>>(&mut stakes.stake_set, &to_str(stake_id));

        pool_item.asset_amount = pool_item.asset_amount - stake_item.asset_amount;
        pool_item.asset_weight = pool_item.asset_amount * (pool_item.multiplier as u128);
    }

    /// Query pool by key
    /// @return (multiplier, asset_weight, asset_amount)
    public fun query_pool_info<P, A>(pool_key: &vector<u8>): (u64, u128, u128) acquires Pools {
        let broker = TokenSwapConfig::admin_address();
        let pools = borrow_global_mut<Pools<P, A>>(broker);
        let pool_item = IDizedSet::borrow_mut(&mut pools.pool_set, pool_key);
        (
            pool_item.multiplier,
            pool_item.asset_weight,
            pool_item.asset_amount
        )
    }

    /// Query total amount and weight
    /// @return (multiplier, asset_weight, asset_amount)
    public fun query_total<P, A>(): (u128, u128) acquires Pools {
        let broker = TokenSwapConfig::admin_address();
        let pools = borrow_global_mut<Pools<P, A>>(broker);

        let len = IDizedSet::length(&pools.pool_set);
        let total_amount = 0;
        let total_weight = 0;

        if (len == 0) {
            return (total_amount, total_weight)
        };

        let idx = len - 1;
        loop {
            let pool = IDizedSet::borrow_idx(&pools.pool_set, idx);
            total_weight = total_weight + pool.asset_weight;
            total_amount = total_amount + pool.asset_amount;
            idx = idx - 1;
        }
    }

    public fun get_pool_key_by_multiplier(_mul: u64): vector<u8> {
        // TODO
        Vector::empty<u8>()
    }

    fun require_admin(user_addr: address) {
        assert!(TokenSwapConfig::admin_address() == user_addr, Errors::invalid_state(ERROR_NOT_ADMIN));
    }

    fun to_str(_id: u64): vector<u8> {
        // TODO
        Vector::empty<u8>()
    }
}
}
