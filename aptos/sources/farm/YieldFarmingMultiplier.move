module SwapAdmin::YieldFarmingMultiplier {
    use std::error;
    use std::signer;
    use std::vector;
    use std::option;

    const ERROR_ACCOUNT_NOT_ADMIN: u64 = 101;
    const ERROR_POOL_NOT_FOUND: u64 = 102;
    const ERROR_POOL_HAS_EXISTS: u64 = 103;
    const ERROR_POOL_WEIGHT_NOT_ZERO: u64 = 104;

    struct MultiplierPoolsGlobalInfo<phantom PoolType, phantom AssetT> has key, store {
        vec: vector<MultiplierPool<PoolType, AssetT>>,
    }

    struct MultiplierPool<phantom PoolType, phantom AssetT> has key, store {
        key: vector<u8>,
        asset_weight: u128,
        asset_amount: u128,
        multiplier: u64,
    }

    struct PoolCapability<phantom PoolType, phantom AssetT> has key, store {}

    /// Initialize from total asset weight and amount
    public fun init<PoolType: store, AssetT: store>(signer: &signer): PoolCapability<PoolType, AssetT> {
        require_admin(signer);
        move_to(signer, MultiplierPoolsGlobalInfo<PoolType, AssetT>{
            vec: vector::empty<MultiplierPool<PoolType, AssetT>>(),
        });
        PoolCapability<PoolType, AssetT>{}
    }

    /// Uninitialize called by caller
    public fun uninitialize<PoolType: store, AssetT: store>(cap: PoolCapability<PoolType, AssetT>) {
        let PoolCapability<PoolType, AssetT>{} = cap;
    }

    /// Add new multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun add<PoolType: store, AssetT: store>(signer: &signer,
                                                   key: &vector<u8>,
                                                   multiplier: u64) acquires MultiplierPoolsGlobalInfo {
        require_admin(signer);

        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetT>>(@SwapAdmin);
        let idx = find_idx_by_id(&info.vec, key);
        assert!(option::is_none(&idx), error::invalid_state(ERROR_POOL_HAS_EXISTS));

        vector::push_back(&mut info.vec, MultiplierPool<PoolType, AssetT>{
            key: *key,
            asset_weight: 0,
            asset_amount: 0,
            multiplier,
        });
    }

    /// Remove an exists multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun remove<PoolType: store, AssetT: store>(signer: &signer,
                                                      key: &vector<u8>) acquires MultiplierPoolsGlobalInfo {
        require_admin(signer);

        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetT>>(@SwapAdmin);
        let idx = find_idx_by_id(&info.vec, key);
        assert!(option::is_some(&idx), error::invalid_state(ERROR_POOL_NOT_FOUND));

        let i = option::destroy_some(idx);
        let multiplier_pool =
            vector::borrow_mut<MultiplierPool<PoolType, AssetT>>(&mut info.vec, i);
        assert!(multiplier_pool.asset_weight <= 0 && multiplier_pool.asset_amount <= 0,
            error::invalid_state(ERROR_POOL_WEIGHT_NOT_ZERO));

        // Unpacking Multiplier Pool
        let MultiplierPool<PoolType, AssetT>{
            key: _,
            asset_weight: _,
            asset_amount: _,
            multiplier: _
        } = vector::remove(&mut info.vec, i);
    }

    /// Update multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun update<PoolType: store, AssetT: store>(signer: &signer,
                                                      key: &vector<u8>,
                                                      multiplier: u64) acquires MultiplierPoolsGlobalInfo {
        require_admin(signer);

        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetT>>(@SwapAdmin);
        let multiplier_pool = find_pool_by_key(&mut info.vec, key);

        multiplier_pool.multiplier = multiplier;
        multiplier_pool.asset_weight = multiplier_pool.asset_amount * (multiplier as u128);
    }

    /// Add weight to a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun add_amount<PoolType: store,
                          AssetT: store>(key: &vector<u8>, asset_amount: u128) acquires MultiplierPoolsGlobalInfo {
        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetT>>(@SwapAdmin);
        let multiplier_pool = find_pool_by_key(&mut info.vec, key);

        multiplier_pool.asset_amount = multiplier_pool.asset_amount + asset_amount;
        multiplier_pool.asset_weight = multiplier_pool.asset_amount * (multiplier_pool.multiplier as u128);
    }

    public fun remove_weight<PoolType: store,
                             AssetT: store>(key: &vector<u8>, asset_amount: u128) acquires MultiplierPoolsGlobalInfo {
        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetT>>(@SwapAdmin);
        let multiplier_pool = find_pool_by_key(&mut info.vec, key);

        multiplier_pool.asset_amount = multiplier_pool.asset_amount - asset_amount;
        multiplier_pool.asset_weight = multiplier_pool.asset_amount * (multiplier_pool.multiplier as u128);
    }

    /// Query pool by key
    /// @return (multiplier, asset_weight, asset_amount)
    public fun query_pool<PoolType: store, AssetT: store>(key: &vector<u8>): (u64, u128, u128) acquires MultiplierPoolsGlobalInfo {
        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetT>>(@SwapAdmin);
        let multiplier_pool = find_pool_by_key(&mut info.vec, key);
        (
            multiplier_pool.multiplier,
            multiplier_pool.asset_weight,
            multiplier_pool.asset_amount
        )
    }

    /// Find by key which is from user
    fun find_pool_by_key<PoolType: store,
                         AssetT: store>(c: &mut vector<MultiplierPool<PoolType, AssetT>>,
                                        key: &vector<u8>): &mut MultiplierPool<PoolType, AssetT> {
        let idx = find_idx_by_id<PoolType, AssetT>(c, key);
        assert!(option::is_some(&idx), error::invalid_state(ERROR_POOL_NOT_FOUND));
        vector::borrow_mut<MultiplierPool<PoolType, AssetT>>(c, option::destroy_some<u64>(idx))
    }

    fun find_idx_by_id<PoolType: store,
                       AssetType: store>(c: &vector<MultiplierPool<PoolType, AssetType>>,
                                         key: &vector<u8>)
    : option::Option<u64> {
        let len = vector::length(c);
        if (len == 0) {
            return option::none()
        };
        let idx = len - 1;
        loop {
            let el = vector::borrow(c, idx);
            if (*&el.key == *key) {
                return option::some(idx)
            };
            if (idx == 0) {
                return option::none()
            };
            idx = idx - 1;
        }
    }

    fun require_admin(signer: &signer) {
        assert!(signer::address_of(signer) == @SwapAdmin, error::invalid_state(ERROR_ACCOUNT_NOT_ADMIN));
    }
}