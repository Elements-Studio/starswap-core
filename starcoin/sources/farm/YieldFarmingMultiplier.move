address SwapAdmin {

module YieldFarmingMultiplier {
    use StarcoinFramework::Errors;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Option;

    const ERR_DEPRECATED: u64 = 1;

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
    public fun init<PoolType: store, AssetT: store>(
        _signer: &signer
    ): PoolCapability<PoolType, AssetT> {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// Uninitialize called by caller
    public fun uninitialize<PoolType: store, AssetT: store>(cap: PoolCapability<PoolType, AssetT>) {
        let PoolCapability<PoolType, AssetT>{} = cap;
    }

    /// Add new multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun add<PoolType: store, AssetT: store>(
        _signer: &signer,
        _key: &vector<u8>,
        _multiplier: u64
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// Remove an exists multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun remove<PoolType: store, AssetT: store>(
        _signer: &signer,
        _key: &vector<u8>
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// Update multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun update<PoolType: store, AssetT: store>(
        _signer: &signer,
        _key: &vector<u8>,
        _multiplier: u64) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// Add weight to a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun add_amount<PoolType: store,
                          AssetT: store>(
        _key: &vector<u8>,
        _asset_amount: u128
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    public fun remove_weight<PoolType: store,
                             AssetT: store>(
        _key: &vector<u8>,
        _asset_amount: u128
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// Query pool by key
    /// @return (multiplier, asset_weight, asset_amount)
    public fun query_pool<PoolType: store, AssetT: store>(
        _key: &vector<u8>
    ): (
        u64,
        u128,
        u128
    ) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    /// Find by key which is from user
    fun find_pool_by_key<PoolType: store, AssetT: store>(
        _c: &mut vector<MultiplierPool<PoolType, AssetT>>,
        _key: &vector<u8>): &mut MultiplierPool<PoolType, AssetT> {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    fun find_idx_by_id<PoolType: store,
                       AssetType: store>(
        _c: &vector<MultiplierPool<PoolType, AssetType>>,
        _key: &vector<u8>)
    : Option::Option<u64> {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    fun require_admin(signer: &signer) {
        assert!(Signer::address_of(signer) == @SwapAdmin, Errors::invalid_state(ERROR_ACCOUNT_NOT_ADMIN));
    }
}
}
