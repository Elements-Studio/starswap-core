//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5 --public-keys BuyBackAccount=0x760670dd3a152f7130534758d366eea7540078832e0985cde498c40c9a2b6ae3 --addresses BuyBackAccount=0xa1869437e19a33eba1b7277218af539c

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000



//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};
    use SwapAdmin::TokenMock;
    use SwapAdmin::UpgradeScripts;

    fun initialize_governance_and_farm(swap_admin: signer) {
        UpgradeScripts::genesis_initialize_for_latest_version(
            &swap_admin,
            100000000,
            100000000,
        );

        TokenMock::register_token<WETH>(&swap_admin, 9u8);
        TokenMock::register_token<WBTC>(&swap_admin, 9u8);

        TokenSwapFarmRouter::add_farm_pool_v2<WBTC, WETH>(&swap_admin, 100);
    }
}

// This timestamp is two years after the time of the pledge + 1 second,otherwise the calculation will be incorrect.
//# block --author 0x1 --timestamp 1709518600000

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Math;
    use StarcoinFramework::Account;

    use SwapAdmin::TokenSwapGovPoolType::PoolTypeFarmPool;
    use SwapAdmin::STAR::{Self, STAR};
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapGov;

    fun withdraw_and_deposit_into_farm(swap_admin: signer) {
        let amount = 1 * Math::pow(10, (STAR::precision() as u64));

        let farm_before_balance = TokenSwapFarm::get_treasury_balance<PoolTypeFarmPool, STAR>();
        Debug::print(&farm_before_balance);

        TokenSwapGov::linear_withdraw_developerfund(&swap_admin, @SwapAdmin, amount);
        TokenSwapFarm::deposit<PoolTypeFarmPool, STAR>(&swap_admin, Account::withdraw<STAR>(&swap_admin, amount));

        let farm_after_balance = TokenSwapFarm::get_treasury_balance<PoolTypeFarmPool, STAR>();
        assert!((farm_after_balance - farm_before_balance) == amount, 1);
    }
}