address SwapAdmin {

module TokenSwapMutiPool {

    use SwapAdmin::IDizedSet;

    struct Pools<phantom PoolType, phantom AssetT> {
        pool_set: IDizedSet::Set<Pool<PoolType, AssetT>>,
    }

    struct Pool<phantom PoolType, phantom AssetT> {
        asset_weight: u128,
        asset_amount: u128,
        multiplier: u64,
    }

    /// Initialize from total asset weight and amount
    public fun new<P, A>(): Pools<P, A> {
        Pools<P, A>{ pool_set: IDizedSet::empty<Pool<P, A>>() }
    }

    /// Uninitialize called by caller
    public fun destroy<P, A>(pools: Pools<P, A>) {
        let Pools<P, A>{ pool_set } = pools;
        IDizedSet::destroy(pool_set);
    }

    /// Add new multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun add_pool<P, A>(pools: &mut Pools<P, A>, key: &vector<u8>, multiplier: u64) {
        IDizedSet::push_back(&mut pools.pool_set, key, Pool<P, A>{
            asset_weight: 0,
            asset_amount: 0,
            multiplier
        });
    }

    /// Remove an exists multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun remove_pool<P, A>(pools: &mut Pools<P, A>, key: &vector<u8>) {
        let Pool<P, A>{
            asset_weight: _,
            asset_amount: _,
            multiplier: _,
        } = IDizedSet::remove(&mut pools.pool_set, key);
    }

    /// Update multiplier pool
    /// @param key: The key name of pool
    /// @return new weight
    ///
    public fun update<P, A>(pools: &mut Pools<P, A>, key: &vector<u8>, multiplier: u64): u128 {
        let pool = IDizedSet::borrow_mut(&mut pools.pool_set, key);

        pool.multiplier = multiplier;
        pool.asset_weight = pool.asset_amount * (multiplier as u128);
        pool.asset_weight
    }

    /// Add weight to a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun add_asset<P, A>(pools: &mut Pools<P, A>, key: &vector<u8>, amount: u128) {
        let pool = IDizedSet::borrow_mut(&mut pools.pool_set, key);

        pool.asset_amount = pool.asset_amount + amount;
        pool.asset_weight = pool.asset_amount * (pool.multiplier as u128);
    }

    /// Add weight from a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun remove_asset<PoolType: store, AssetT: store>(pools: &mut Pools<PoolType, AssetT>, key: &vector<u8>, amount: u128) {
        let pool = IDizedSet::borrow_mut(&mut pools.pool_set, key);

        pool.asset_amount = pool.asset_amount - amount;
        pool.asset_weight = pool.asset_amount * (pool.multiplier as u128);
    }

    /// Query pool by key
    /// @return (multiplier, asset_weight, asset_amount)
    public fun query_pool_info<P, A>(pools: &mut Pools<P, A>, key: &vector<u8>): (u64, u128, u128) {
        let pool = IDizedSet::borrow_mut(&mut pools.pool_set, key);
        (
            pool.multiplier,
            pool.asset_weight,
            pool.asset_amount
        )
    }

    /// Query total amount and weight
    /// @return (multiplier, asset_weight, asset_amount)
    public fun query_total<P, A>(pools: &Pools<P, A>): (u128, u128) {
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

}
}
