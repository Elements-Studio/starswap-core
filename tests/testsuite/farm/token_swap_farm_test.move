//! account: alice, 10000000000000 0x1::STC::STC
//! account: bob, 10000000000000 0x1::STC::STC
//! account: admin, 0x4783d08fb16990bd35d83f3e23bf93b8, 10000000000000 0x1::STC::STC
//! account: liquidier, 10000000000000 0x1::STC::STC
//! account: exchanger
//! account: tokenholder, 0x49156896A605F092ba1862C50a9036c9


//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 86410000


//! new-transaction
//! sender: admin
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{Self, WETH, WBTC};

    fun init_token(signer: signer) {
        TokenMock::register_token<WETH>(&signer, 9u8);
        TokenMock::register_token<WBTC>(&signer, 9u8);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address admin = {{admin}};
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WETH, WBTC};

    fun alice_accept_token(signer: signer) {
        Account::do_accept_token<WBTC>(&signer);
        Account::do_accept_token<WETH>(&signer);
    }
}


//! new-transaction
//! sender: admin
address admin = {{admin}};
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x1::Math;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{Self, WBTC, WETH};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;

    fun admin_register_token_pair_and_mint(signer: signer) {
        //token pair register must be swap admin account
        TokenSwapRouter::register_swap_pair<WBTC, WETH>(&signer);
        assert(TokenSwapRouter::swap_pair_exists<WBTC, WETH>(), 1001);

        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));

            {
                // Resister and mint BTC
                CommonHelper::safe_mint<WBTC>(&signer, 100000000 * scaling_factor);

                let mint_token_to_alice = TokenMock::mint_token<WBTC>(100000000 * scaling_factor);
                Account::deposit<WBTC>(@alice, mint_token_to_alice);
            };

            {
                // Resister and mint ETH
                CommonHelper::safe_mint<WETH>(&signer, 100000000 * scaling_factor);

                let mint_token_to_alice = TokenMock::mint_token<WETH>(100000000 * scaling_factor);
                Account::deposit<WETH>(@alice, mint_token_to_alice);
            };

        let amount_btc_desired: u128 = 10 * scaling_factor;
        let amount_eth_desired: u128 = 50 * scaling_factor;
        let amount_btc_min: u128 = 1 * scaling_factor;
        let amount_eth_min: u128 = 1 * scaling_factor;
        TokenSwapRouter::add_liquidity<WBTC, WETH>(
            &signer,
            amount_btc_desired,
            amount_eth_desired,
            amount_btc_min,
            amount_eth_min);
        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<WBTC, WETH>();
        assert(total_liquidity > amount_btc_min, 1002);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGov;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WBTC, WETH};

    fun admin_governance_genesis(signer: signer) {
        TokenSwapGov::genesis_initialize(&signer);
        TokenSwapFarmRouter::add_farm_pool<WBTC, WETH>(&signer, 100000000);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x1::Signer;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WBTC, WETH};

    fun admin_stake(signer: signer) {
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, liquidity_amount);

        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        assert(stake_amount == liquidity_amount, 1003);

        let total_stake_amount = TokenSwapFarmRouter::query_total_stake<WBTC, WETH>();
        assert(total_stake_amount == liquidity_amount, 1004);
    }
}

//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 86420000

//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x1::Signer;
    use 0x1::Account;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WBTC, WETH};

    fun admin_harvest(signer: signer) {
        TokenSwapFarmRouter::harvest<WBTC, WETH>(&signer, 0);
        let rewards_amount = Account::balance<STAR::STAR>(Signer::address_of(&signer));
        assert(rewards_amount > 0, 1004);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 3
//! block-time: 86430000

//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x1::Signer;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WBTC, WETH};

    fun admin_unstake(signer: signer) {
        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        assert(stake_amount > 0, 1005);
        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, stake_amount);
        let after_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        assert(after_amount > 0, 1006);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address admin = {{admin}};
address alice = {{alice}};
script {
    //use 0x1::Account;
    //use 0x1::Token;
    use 0x1::Math;
    use 0x1::Signer;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WBTC, WETH};
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;

    fun alice_add_liquidity(signer: signer) {
        let precision: u8 = 9;
        let scaling_factor = Math::pow(10, (precision as u64));

        let amount_btc_desired: u128 = 10 * scaling_factor;
        let amount_eth_desired: u128 = 50 * scaling_factor;
        let amount_btc_min: u128 = 1 * scaling_factor;
        let amount_eth_min: u128 = 1 * scaling_factor;

        TokenSwapRouter::add_liquidity<WBTC, WETH>(
            &signer,
            amount_btc_desired,
            amount_eth_desired,
            amount_btc_min,
            amount_eth_min);

        let liquidity: u128 = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        assert(liquidity > amount_btc_min, 1007);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address admin = {{admin}};
address alice = {{alice}};
script {
    use 0x1::Signer;
    use 0x1::Debug;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WBTC, WETH};

    fun alice_stake(signer: signer) {
        let account = Signer::address_of(&signer);
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(account);
        assert(liquidity_amount > 0, 1008);
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, 10000);

        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        assert(stake_amount == 10000, 1009);

        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, 10000);
        let _stake_amount1 = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        Debug::print(&_stake_amount1);
        assert(_stake_amount1 == 20000, 1010);
    }
}
// check: EXECUTED

//! block-prologue
//! author: genesis
//! block-number: 4
//! block-time: 86440000

//! new-transaction
//! sender: alice
script {
    use 0x1::Signer;
    use 0x1::Debug;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmRouter;
    //use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenMock::{WBTC, WETH};

    fun alice_unstake(signer: signer) {
        let account = Signer::address_of(&signer);
        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        assert(stake_amount == 20000, 1011);

        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, 10000);

        let _stake_amount1 = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        assert(_stake_amount1 == 10000, 1012);

        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, 10000);

        let _stake_amount2 = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        Debug::print(&_stake_amount2);
        assert(_stake_amount2 == 0, 1013);
    }
}
// check: EXECUTED