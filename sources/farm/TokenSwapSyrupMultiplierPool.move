module SwapAdmin::TokenSwapSyrupMultiplierPool {
    use StarcoinFramework::Errors;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Option;

    const ERROR_ACCOUNT_NOT_ADMIN: u64 = 101;
    const ERROR_POOL_NOT_FOUND: u64 = 102;
    const ERROR_POOL_HAS_EXISTS: u64 = 103;
    const ERROR_POOL_WEIGHT_NOT_ZERO: u64 = 104;
    const ERROR_POOL_EMPTY: u64 = 105;
    const ERROR_POOL_PARAMETER_INVALID: u64 = 106;

    struct MultiplierPoolsGlobalInfo<phantom PoolType, phantom AssetType> has key, store {
        items: vector<MultiplierPool<PoolType, AssetType>>,
    }

    struct MultiplierPool<phantom PoolType, phantom AssetType> has key, store {
        key: vector<u8>,
        asset_weight: u128,
        asset_amount: u128,
        multiplier: u64,
    }

    struct PoolCapability<phantom PoolType, phantom AssetType> has key, store {
        holder: address,
    }

    /// Initialize from total asset weight and amount
    public fun initialize<PoolType: store, AssetType: store>(
        account: &signer
    ): PoolCapability<PoolType, AssetType> {
        move_to(account, MultiplierPoolsGlobalInfo<PoolType, AssetType> {
            items: Vector::empty<MultiplierPool<PoolType, AssetType>>(),
        });

        PoolCapability<PoolType, AssetType> {
            holder: Signer::address_of(account),
        }
    }

    /// Uninitialize called by caller
    public fun uninitialize<PoolType: store, AssetType: store>(cap: PoolCapability<PoolType, AssetType>) {
        let PoolCapability<PoolType, AssetType> { holder: _ } = cap;
    }

    /// Add new multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun add_pool<PoolType: store, AssetType: store>(
        cap: &PoolCapability<PoolType, AssetType>,
        broker: address,
        key: &vector<u8>,
        multiplier: u64
    ) acquires MultiplierPoolsGlobalInfo {
        verify_cap(broker, cap);

        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetType>>(broker);
        let idx = find_idx_by_id(&info.items, key);
        assert!(Option::is_none(&idx), Errors::invalid_state(ERROR_POOL_HAS_EXISTS));

        Vector::push_back(&mut info.items, MultiplierPool<PoolType, AssetType> {
            key: *key,
            asset_weight: 0,
            asset_amount: 0,
            multiplier,
        });
    }

    /// Remove an exists multiplier pool by admin
    /// @param key: The key name of pool
    ///
    public fun remove_pool<PoolType: store, AssetType: store>(
        broker: address,
        cap: &PoolCapability<PoolType, AssetType>,
        key: &vector<u8>
    ) acquires MultiplierPoolsGlobalInfo {
        verify_cap(broker, cap);

        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetType>>(broker);
        let idx = find_idx_by_id(&info.items, key);
        assert!(Option::is_some(&idx), Errors::invalid_state(ERROR_POOL_NOT_FOUND));

        let i = Option::destroy_some(idx);
        let multiplier_pool =
            Vector::borrow_mut<MultiplierPool<PoolType, AssetType>>(&mut info.items, i);

        assert!(multiplier_pool.asset_weight <= 0 && multiplier_pool.asset_amount <= 0,
            Errors::invalid_state(ERROR_POOL_WEIGHT_NOT_ZERO));

        // Unpacking Multiplier Pool
        let MultiplierPool<PoolType, AssetType> {
            key: _,
            asset_weight: _,
            asset_amount: _,
            multiplier: _
        } = Vector::remove(&mut info.items, i);
    }

    /// Add amount to a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun add_amount<PoolType: store, AssetType: store>(
        broker: address,
        cap: &PoolCapability<PoolType, AssetType>,
        key: &vector<u8>,
        asset_amount: u128
    ) acquires MultiplierPoolsGlobalInfo {
        verify_cap(broker, cap);


        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetType>>(broker);
        let multiplier_pool = find_pool_by_key(&mut info.items, key);

        multiplier_pool.asset_amount = multiplier_pool.asset_amount + asset_amount;
        multiplier_pool.asset_weight = multiplier_pool.asset_amount * (multiplier_pool.multiplier as u128);
    }

    /// Add amount from a pool
    /// @param key: The key name of pool
    /// @param amount: Amount of asset
    public fun remove_amount<PoolType: store, AssetType: store>(
        broker: address,
        cap: &PoolCapability<PoolType, AssetType>,
        key: &vector<u8>,
        asset_amount: u128
    ) acquires MultiplierPoolsGlobalInfo {
        verify_cap(broker, cap);

        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetType>>(broker);
        let multiplier_pool = find_pool_by_key(&mut info.items, key);

        multiplier_pool.asset_amount = multiplier_pool.asset_amount - asset_amount;
        multiplier_pool.asset_weight = multiplier_pool.asset_amount * (multiplier_pool.multiplier as u128);
    }

    /// Query pool by key
    /// @return (multiplier, asset_weight, asset_amount)
    public fun query_pool<PoolType: store, AssetType: store>(
        broker: address,
        key: &vector<u8>
    ): (u64, u128, u128) acquires MultiplierPoolsGlobalInfo {
        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetType>>(broker);
        let multiplier_pool = find_pool_by_key(&mut info.items, key);
        (
            multiplier_pool.multiplier,
            multiplier_pool.asset_weight,
            multiplier_pool.asset_amount
        )
    }

    /// Query all multiplier type of type pledge time
    /// @return (key_list, multiplier_list, asset_amount_list)
    /// key_list split by `|`
    public fun query_all_pools<PoolType: store, AssetType: store>(
        broker: address,
    ): (
        vector<u8>,
        vector<u64>,
        vector<u128>
    ) acquires MultiplierPoolsGlobalInfo {
        let info =
            borrow_global<MultiplierPoolsGlobalInfo<PoolType, AssetType>>(broker);
        let key_list = Vector::empty<u8>();
        let multiplier_list = Vector::empty<u64>();
        let asset_amount_list = Vector::empty<u128>();

        if (!Vector::is_empty<>(&info.items)) {
            let idx = 0;
            let len = Vector::length(&info.items);
            loop {
                if (idx > len) {
                    break
                };
                let item =
                    Vector::borrow(&info.items, idx);
                Vector::append(&mut key_list, *&item.key);
                Vector::append(&mut key_list, b"|");
                Vector::push_back(&mut multiplier_list, item.multiplier);
                Vector::push_back(&mut asset_amount_list, item.asset_amount);

                idx = idx + 1;
            };
        };
        (key_list, multiplier_list, asset_amount_list)
    }

    /// Query total staked amounts from multiplier pool
    /// @return (total_amount, total_weight)
    public fun query_total_amount<PoolType: store, AssetType: store>(
        broker: address,
    ): (u128, u128, ) acquires MultiplierPoolsGlobalInfo {
        let (
            _,
            multiplier_list,
            amount_list
        ) = query_all_pools<PoolType, AssetType>(broker);
        assert!(
            Vector::is_empty(&multiplier_list) ||
                Vector::is_empty(&amount_list),
            Errors::invalid_state(ERROR_POOL_EMPTY)
        );
        assert!(
            Vector::length(&multiplier_list) == Vector::is_empty(&amount_list),
            Errors::invalid_state(ERROR_POOL_PARAMETER_INVALID)
        );

        let total_amount: u128 = 0;
        let total_weight: u128 = 0;
        let idx = 0;
        let len = Vector::length(&amount_list);
        loop {
            if (idx > len) {
                break
            };

            let stepwise_amount = Vector::borrow(&amount_list, idx);
            total_amount = total_amount + stepwise_amount;
            total_weight = total_weight + stepwise_amount * Vector::borrow(&multiplier_list, idx);

            idx = idx + 1;
        };
        (total_amount, total_weight)
    }

    /// Check the key has exists
    public fun has<PoolType: store, AssetType: store>(
        broker: address,
        key: &vector<u8>
    ): bool acquires MultiplierPoolsGlobalInfo {
        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetType>>(broker);
        Option::is_some(&find_idx_by_id<PoolType, AssetType>(&info.items, key))
    }

    /// Set mulitplier pool amount with amount
    /// @param key: The key name of pool
    /// @param amount: amount need to be set
    public fun set_pool_amount<PoolType: store, AssetType: store>(
        broker: address,
        cap: &PoolCapability<PoolType, AssetType>,
        key: &vector<u8>,
        amount: u128
    ) acquires MultiplierPoolsGlobalInfo {
        verify_cap(broker, cap);

        let info =
            borrow_global_mut<MultiplierPoolsGlobalInfo<PoolType, AssetType>>(broker);
        let multiplier_pool = find_pool_by_key(&mut info.items, key);
        multiplier_pool.asset_amount = amount;
        multiplier_pool.asset_weight = multiplier_pool.asset_amount * (multiplier_pool.multiplier as u128);
    }

    /// Find by key which is from user
    fun find_pool_by_key<PoolType: store, AssetType: store>(
        c: &mut vector<MultiplierPool<PoolType, AssetType>>,
        key: &vector<u8>
    ): &mut MultiplierPool<PoolType, AssetType> {
        let idx = find_idx_by_id<PoolType, AssetType>(c, key);
        assert!(Option::is_some(&idx), Errors::invalid_state(ERROR_POOL_NOT_FOUND));
        Vector::borrow_mut<MultiplierPool<PoolType, AssetType>>(c, Option::destroy_some<u64>(idx))
    }

    fun find_idx_by_id<PoolType: store, AssetType: store>(
        c: &vector<MultiplierPool<PoolType, AssetType>>,
        key: &vector<u8>
    ): Option::Option<u64> {
        let len = Vector::length(c);
        if (len == 0) {
            return Option::none()
        };
        let idx = len - 1;
        loop {
            let el = Vector::borrow(c, idx);
            if (*&el.key == *key) {
                return Option::some(idx)
            };
            if (idx == 0) {
                return Option::none()
            };
            idx = idx - 1;
        }
    }

    fun verify_cap<PoolType: store, AssetType: store>(
        broker: address,
        cap: &PoolCapability<PoolType, AssetType>
    ) {
        assert!(broker == cap.holder, Errors::invalid_state(ERROR_ACCOUNT_NOT_ADMIN));
    }
}

