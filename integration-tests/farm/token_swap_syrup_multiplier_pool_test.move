//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# publish
module SwapAdmin::MultiplierPoolHelper {
    use StarcoinFramework::BCS;
    use SwapAdmin::TokenSwapSyrupMultiplierPool;

    struct MockPoolType has store {}

    struct MockAssetType has store {}

    struct PoolCapabilityWarpper has key {
        cap: TokenSwapSyrupMultiplierPool::PoolCapability<MockPoolType, MockAssetType>,
    }

    public fun initialize(account: &signer) {
        let cap = TokenSwapSyrupMultiplierPool::initialize<
            MockPoolType,
            MockAssetType
        >(
            account,
        );

        TokenSwapSyrupMultiplierPool::add_pool<MockPoolType, MockAssetType>(
            &cap,
            @SwapAdmin,
            &BCS::to_bytes<u64>(&10),
            10,
        );

        move_to(account, PoolCapabilityWarpper {
            cap
        });
    }

    public fun add_amount(amount: u128) acquires PoolCapabilityWarpper {
        let cap = borrow_global_mut<PoolCapabilityWarpper>(@SwapAdmin);
        TokenSwapSyrupMultiplierPool::add_amount<MockPoolType, MockAssetType>(
            @SwapAdmin,
            &cap.cap,
            &BCS::to_bytes<u64>(&10),
            amount,
        );
    }

    public fun remove_amount(amount: u128) acquires PoolCapabilityWarpper {
        let cap = borrow_global_mut<PoolCapabilityWarpper>(@SwapAdmin);
        TokenSwapSyrupMultiplierPool::remove_amount<MockPoolType, MockAssetType>(
            @SwapAdmin,
            &cap.cap,
            &BCS::to_bytes<u64>(&10),
            amount,
        );
    }

    public fun query_pool(): (u64, u128, u128) {
        TokenSwapSyrupMultiplierPool::query_pool_by_key<MockPoolType, MockAssetType>(@SwapAdmin, &BCS::to_bytes<u64>(&10))
    }
}

//# run --signers SwapAdmin
script {
    use SwapAdmin::MultiplierPoolHelper;

    fun swapadmin_initialize(account: signer) {
        MultiplierPoolHelper::initialize(&account);

        let (
            multiplier,
            asset_weight,
            asset_amount,
        ) = MultiplierPoolHelper::query_pool();

        assert!(multiplier == 10, 10001);
        assert!(asset_weight == 0, 10003);
        assert!(asset_amount == 0, 10002);
    }
}

//# run --signers SwapAdmin
script {
    use SwapAdmin::MultiplierPoolHelper;
    use StarcoinFramework::Debug;

    fun add_amount(_account: signer) {
        MultiplierPoolHelper::add_amount(100);
        let (
            multiplier,
            asset_weight,
            asset_amount,
        ) = MultiplierPoolHelper::query_pool();
        Debug::print(&asset_amount);
        assert!(multiplier == 10, 10001);
        assert!(asset_amount == 100, 10002);
        assert!(asset_weight == asset_amount * (multiplier as u128), 10003);
    }
}

//# run --signers SwapAdmin
script {
    use SwapAdmin::MultiplierPoolHelper;

    fun remove_amount(_account: signer) {
        MultiplierPoolHelper::remove_amount(100);
        let (
            multiplier,
            asset_weight,
            asset_amount,
        ) = MultiplierPoolHelper::query_pool();
        assert!(multiplier == 10, 10011);
        assert!(asset_weight == asset_amount * (multiplier as u128), 10013);
        assert!(asset_amount == 0, 10012);
    }
}


