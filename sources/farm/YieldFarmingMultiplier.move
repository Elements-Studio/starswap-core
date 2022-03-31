address SwapAdmin {

module YieldFarmingMultiplier {

    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Option;
    use StarcoinFramework::U256;

    use SwapAdmin::YieldFarmingLibrary;
    use SwapAdmin::BigExponential;

    const ERROR_ACCOUNT_NOT_ADMIN: u64 = 101;
    const ERROR_POOL_NOT_FOUND: u64 = 102;

    struct PoolVec<phantom PoolType, phantom AssetT> has key, store {
        vec: vector<MultiplierPool<PoolType, AssetT>>,
        tvl: u128,
        harvest_index: u128,
        last_update_timestamp: u64,
    }

    struct MultiplierPool<phantom PoolType, phantom AssetT> has key, store {
        key: vector<u8>,
        tvl: u128,
        harvest_index: u128,
        last_update_timestamp: u64,
        multiplier: u64,
    }

    struct PoolCapability<phantom PoolType, phantom AssetT> has key, store {}

    public fun init<PoolType: store, AssetT: store>(signer: &signer, tvl: u128): PoolCapability<PoolType, AssetT> {
        require_admin(signer);
        move_to(signer, PoolVec<PoolType, AssetT>{
            vec: Vector::empty<MultiplierPool<PoolType, AssetT>>(),
            tvl,
            harvest_index,
            last_update_timestamp,
        });
        PoolCapability<PoolType, AssetT>{}
    }

    public fun destroy<PoolType: store, AssetT: store>(cap: PoolCapability<PoolType, AssetT>) {
        let PoolCapability<PoolType, AssetT>{} = cap;
    }

    public fun update_pool<PoolType: store, AssetT: store>(signer: &signer,
                                                           key: &vector<u8>,
                                                           multiplier: u64) acquires PoolVec {
        require_admin(signer);

        let now_sec = Timestamp::now_seconds();
        let pool_vec = borrow_global_mut<PoolVec<PoolType, AssetT>>(@SwapAdmin);
        let idx = find_idx_by_id(&pool_vec.vec, key);
        if (Option::is_none(&idx)) {
            Vector::push_back(&mut pool_vec.vec, MultiplierPool<PoolType, AssetT>{
                key: *key,
                tvl: 0,
                harvest_index: 0,
                last_update_timestamp: now_sec,
                multiplier,
            });
        } else {
            let multiplier_pool =
                Vector::borrow_mut<MultiplierPool<PoolType, AssetT>>(&mut pool_vec.vec, Option::destroy_some(idx));
            multiplier_pool.multiplier = multiplier;
        }
    }

    /// Add weight to pool
    public fun add_weight<PoolType: store,
                          AssetT: store>(key: &vector<u8>,
                                         _multiplier: u64,
                                         weight: u128) acquires PoolVec {
        let pool_vec =
            borrow_global_mut<PoolVec<PoolType, AssetT>>(@SwapAdmin);
        let multiplier_pool =
            find_pool_by_key<PoolType, AssetT>(&mut pool_vec.vec, key);

        pool_vec.tvl = pool_vec.tvl + weight;
        multiplier_pool.tvl = multiplier_pool.tvl + weight;
    }

    public fun remove_weight<PoolType: store,
                             AssetT: store>(key: &vector<u8>,
                                            weight: u128) acquires PoolVec {
        let pool_vec =
            borrow_global_mut<PoolVec<PoolType, AssetT>>(@SwapAdmin);
        let multiplier_pool =
            find_pool_by_key<PoolType, AssetT>(&mut pool_vec.vec, key);

        pool_vec.tvl = pool_vec.tvl - weight;
        multiplier_pool.tvl = multiplier_pool.tvl - weight;
    }

    /// Compute harvest amount from a new harvest index and weight
    public fun compute_harvest_amount<PoolType: store, AssetT: store>(
        harvest_index: u128,
        key: &vector<u8>,
        weight: u128): u128 acquires PoolVec {
        let pool_vec =
            borrow_global_mut<PoolVec<PoolType, AssetT>>(@SwapAdmin);
        let multiplier_pool =
            find_pool_by_key<PoolType, AssetT>(&mut pool_vec.vec, key);

        YieldFarmingLibrary::calculate_withdraw_amount(harvest_index, multiplier_pool.harvest_index, weight)
    }

    /// Settling all pool while caller need
    public fun settle_all_pool<PoolType: store, AssetT: store>(allocate_amount: u128) acquires PoolVec {
        let pool_vec = borrow_global_mut<PoolVec<PoolType, AssetT>>(@SwapAdmin);
        let c = &mut pool_vec.vec;
        let len = Vector::length(c);

        let now_seconds = Timestamp::now_seconds();

        // Compute how many indexes are freed
        let addtion_index = U256::to_u128(&YieldFarmingLibrary::calculate_addtion_harvest_index(
            pool_vec.tvl,
            pool_vec.last_update_timestamp,
            Timestamp::now_seconds(),
            allocate_amount,
        ));

        if (len > 0) {
            // Compute the percentage of each pool in turn
            let idx = len - 1;
            loop {
                let el = Vector::borrow_mut(c, idx);
                let numr = el.tvl * addtion_index;
                let denom = pool_vec.tvl;
                let partial_index = U256::to_u128(&BigExponential::mantissa(BigExponential::exp(numr, denom)));
                el.harvest_index = el.harvest_index + partial_index;
                el.last_update_timestamp = now_seconds;

                idx = idx - 1;
            }
        };
        // Update new harvest index
        pool_vec.harvest_index = pool_vec.harvest_index + addtion_index;
        pool_vec.last_update_timestamp = now_seconds;
    }

    /// Find by key which is from user
    fun find_pool_by_key<PoolType: store,
                         AssetT: store>(vec: &mut vector<MultiplierPool<PoolType, AssetT>>,
                                        key: &vector<u8>): &mut MultiplierPool<PoolType, AssetT> {
        let idx = find_idx_by_id<PoolType, AssetT>(vec, key);
        assert!(Option::is_some(&idx), Errors::invalid_state(ERROR_POOL_NOT_FOUND));
        Vector::borrow_mut<MultiplierPool<PoolType, AssetT>>(vec, Option::destroy_some<u64>(idx))
    }

    fun find_idx_by_id<PoolType: store,
                       AssetType: store>(c: &vector<MultiplierPool<PoolType, AssetType>>,
                                         key: &vector<u8>)
    : Option::Option<u64> {
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

    fun require_admin(signer: &signer) {
        assert!(Signer::address_of(signer) == @SwapAdmin, Errors::invalid_state(ERROR_ACCOUNT_NOT_ADMIN));
    }
}
}
