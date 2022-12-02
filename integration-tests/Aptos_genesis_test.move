//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 1646445600000

//# publish
module SwapAdmin::SwapHelper{
    use SwapAdmin::UpgradeScripts;
    use SwapAdmin::TokenMock;
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::Math;
    use SwapAdmin::CommonHelper;
    use StarcoinFramework::Account;
    use StarcoinFramework::Token;
    use SwapAdmin::TokenSwapFarmRouter::add_farm_pool_v2;
    use StarcoinFramework::Signer::address_of;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::PoolTypeCommunity;

    public fun init(sender:&signer){
        UpgradeScripts::genesis_initialize_for_latest_version(
            sender,
            800000000,
            2000000,
        );


    }

    public fun add_farm<X:store + copy + drop,Y:store + copy + drop>(sender: &signer){
        if(!Token::is_registered_in<X>(address_of(sender)) ){
            TokenMock::register_token<X>(sender, 9u8);
        };

        if(!Token::is_registered_in<Y>(address_of(sender)) ){
            TokenMock::register_token<Y>(sender, 9u8);
        };

        TokenSwapRouter::register_swap_pair<X, Y>(sender);
        let scaling_factor = Math::pow(10, (9 as u64));
        CommonHelper::safe_mint<TokenMock::WBTC>(sender, 100000000 * scaling_factor);
        Account::deposit<TokenMock::WBTC>(@alice, TokenMock::mint_token<TokenMock::WBTC>(100000000 * scaling_factor));

        // Resister and mint ETH and deposit to alice
        CommonHelper::safe_mint<TokenMock::WETH>(sender, 100000000 * scaling_factor);
        Account::deposit<TokenMock::WETH>(@alice, TokenMock::mint_token<TokenMock::WETH>(100000000 * scaling_factor));

        let amount_btc_desired: u128 = 10 * scaling_factor;
        let amount_eth_desired: u128 = 50 * scaling_factor;
        let amount_btc_min: u128 = 1 * scaling_factor;
        let amount_eth_min: u128 = 1 * scaling_factor;

        TokenSwapRouter::add_liquidity<TokenMock::WBTC, TokenMock::WETH>(
            sender,
            amount_btc_desired,
            amount_eth_desired,
            amount_btc_min,
            amount_eth_min
        );

        add_farm_pool_v2<X,Y>(sender, 10);
    }

    public fun add_stake<X:store + copy + drop>(sender: &signer) {
        if(!Token::is_registered_in<X>(address_of(sender)) ){
            TokenMock::register_token<X>(sender, 9u8);
        };

        // Release 100 amount for one second
        TokenSwapSyrup::add_pool_v2<X>(sender, 50, 0);

        TokenSwapSyrup::put_stepwise_multiplier<X>(sender, 1000, 2u64);
        TokenSwapSyrup::put_stepwise_multiplier<X>(sender, 2000, 3u64);
    }

    public fun mint_token<X:store + copy + drop>(sender: &signer, to: address, amount :u128){
        CommonHelper::safe_mint<X>(sender, amount);
        Account::deposit<X>(to, TokenMock::mint_token<X>(amount));
    }

    public fun get_STAR(sender:&signer,to:address, amount:u128){
        TokenSwapGov::dispatch<PoolTypeCommunity>(sender, to, amount);
    }

}



//# run --signers SwapAdmin

script {
    use SwapAdmin::SwapHelper;

    fun UpgradeScript_genesis_initialize_for_latest_version(signer: signer) {
        SwapHelper::init(&signer);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::SwapHelper;
    use SwapAdmin::TokenMock::{WBTC, WETH};
    use SwapAdmin::STAR::STAR;

    fun admin_register_token_pair_and_mint(signer: signer) {
        SwapHelper::add_farm<WBTC,WETH>(&signer);
        SwapHelper::add_stake<STAR>(&signer);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_stake(signer: signer) {
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, liquidity_amount);

        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        Debug::print(&stake_amount);
        assert!(stake_amount == liquidity_amount, 10020);

        let total_stake_amount = TokenSwapFarmRouter::query_total_stake<WBTC, WETH>();
        assert!(total_stake_amount == liquidity_amount, 10021);
    }
}

//# block --author 0x1 --timestamp 1646445601000

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Account;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_harvest(signer: signer) {
        TokenSwapFarmRouter::harvest<WBTC, WETH>(&signer, 0);
        let rewards_amount = Account::balance<STAR::STAR>(Signer::address_of(&signer));
        assert!(rewards_amount > 0, 10030);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 1646445602000

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun admin_unstake(signer: signer) {
        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(Signer::address_of(&signer));
        assert!(stake_amount > 0, 10040);
        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, stake_amount);
        let after_amount = TokenSwapRouter::liquidity<WBTC, WETH>(Signer::address_of(&signer));
        assert!(after_amount > 0, 10041);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use StarcoinFramework::Math;
    use StarcoinFramework::Signer;
    use SwapAdmin::TokenMock::{WBTC, WETH};
    use SwapAdmin::TokenSwapRouter;

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
        assert!(liquidity > amount_btc_min, 10050);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 1646445603000

//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun alice_stake(signer: signer) {
        let account = Signer::address_of(&signer);
        let liquidity_amount = TokenSwapRouter::liquidity<WBTC, WETH>(account);
        assert!(liquidity_amount > 0, 10060);
        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, 10000);

        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        assert!(stake_amount == 10000, 10061);

        TokenSwapFarmRouter::stake<WBTC, WETH>(&signer, 10000);
        let _stake_amount1 = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        Debug::print(&_stake_amount1);
        assert!(_stake_amount1 == 20000, 10062);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 1646445604000

//# run --signers SwapAdmin
script {
    use SwapAdmin::SwapHelper;

    fun main(sender: signer){
        SwapHelper::get_STAR(&sender,@alice, 1000 * 1000 * 1000 * 100);
    }
}

//# run --signers alice
script {
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::STAR::STAR;
    use SwapAdmin::CommonHelper;

    fun main(sender: signer){
        TokenSwapSyrup::stake<STAR>(&sender, 1000, CommonHelper::pow_amount<STAR>(100));
    }
}

//# block --author 0x1 --timestamp 1665557289000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::STAR::STAR;

    fun update(signer: signer) {
        TokenSwapSyrup::upgrade_from_v1_0_11_to_v1_0_12<STAR>(&signer);
        TokenSwapSyrup::set_pool_release_per_second(&signer, 23000000);
        TokenSwapSyrup::update_token_pool_index<STAR>(&signer);
    }
}
// check: "Keep(ABORTED { code: 26113"

//# block --author 0x1 --timestamp 1666084255000


//# run --signers alice
script {
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun alice_unstake(signer: signer) {
        let account = Signer::address_of(&signer);
        let stake_amount = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        assert!(stake_amount == 20000, 10070);

        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, 10000);

        let _stake_amount1 = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        assert!(_stake_amount1 == 10000, 10072);

        TokenSwapFarmRouter::unstake<WBTC, WETH>(&signer, 10000);

        let _stake_amount2 = TokenSwapFarmRouter::query_stake<WBTC, WETH>(account);
        Debug::print(&_stake_amount2);
        assert!(_stake_amount2 == 0, 10073);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Debug::print;
    use StarcoinFramework::Token;
    use SwapAdmin::STAR::STAR;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::PoolTypeFarmPool;

    fun main(_account: signer){
        print(&Token::market_cap<STAR>() );
        print(&TokenSwapGov::get_total_of_linear_treasury<PoolTypeFarmPool>());
    }
}
//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::STAR::STAR;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::MultiChain::genesis_aptos_burn;
    use SwapAdmin::TokenMock::{WBTC, WETH};

    fun main(account: signer){
        TokenSwapFarm::update_token_pool_index<WBTC,WETH>(&account);
        TokenSwapFarm::set_pool_release_per_second(&account, (800000000 * 2) / 3);

        TokenSwapSyrup::update_token_pool_index<STAR>(&account);
        TokenSwapSyrup::set_pool_release_per_second(&account, (23000000 * 2) / 3);

        genesis_aptos_burn(&account);
    }
}



//# run --signers SwapAdmin
script {
    use StarcoinFramework::Token;
    use SwapAdmin::STAR::STAR;

    fun main(_account: signer){
        assert!( Token::market_cap<STAR>() == 88000000000000000 - 18079577467999999  , 100);
    }
}