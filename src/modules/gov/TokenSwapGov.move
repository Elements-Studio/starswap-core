// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x8c109349c6bd91411d6bc962e080c4a3 {
module TokenSwapGov {
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Math;
    use 0x1::Signer;
    use 0x1::Timestamp;

    use 0x8c109349c6bd91411d6bc962e080c4a3::STAR;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapFarm;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapSyrup;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapGovPoolType::{
        PoolTypeInitialLiquidity,
        PoolTypeCommunity,
    };

    // 1e8
    const GOV_TOTAL: u128 = 100000000;

    // 10%
    const GOV_PERCENT_TEAM: u64 = 10;
    // 10%
    const GOV_PERCENT_COMMUNITY: u64 = 2;
    // 15%
    const GOV_PERCENT_FARM: u64 = 40;
    // 15%
    const GOV_PERCENT_SYRUP: u64 = 20;
    // 2%
    const GOV_PERCENT_INITIAL_LIQUIDITY: u64 = 1;
    // 5%
    const GOV_PERCENT_DAO_TREASURY: u64 = 27;


    // 5%
    const GOV_PERCENT_FARM_GENESIS: u64 = 5;
    // 5%
    const GOV_PERCENT_SYRUP_GENESIS: u64 = 5;


    #[test] use 0x1::Debug;

    #[test] public fun test_all_issued_amount() {
        let total = GOV_PERCENT_TEAM +
                    GOV_PERCENT_COMMUNITY +
                    GOV_PERCENT_FARM +
                    GOV_PERCENT_SYRUP +
                    GOV_PERCENT_INITIAL_LIQUIDITY +
                    GOV_PERCENT_DAO_TREASURY;

        Debug::print(&total);
        assert(total == 100, 1001);

        assert(calculate_amount_from_percent(GOV_PERCENT_TEAM) == 10000000, 1002);
        assert(calculate_amount_from_percent(GOV_PERCENT_COMMUNITY) == 2000000, 1002);
        assert(calculate_amount_from_percent(GOV_PERCENT_FARM) == 40000000, 1002);
        assert(calculate_amount_from_percent(GOV_PERCENT_SYRUP) == 20000000, 1003);
        assert(calculate_amount_from_percent(GOV_PERCENT_INITIAL_LIQUIDITY) == 1000000, 1004);
        assert(calculate_amount_from_percent(GOV_PERCENT_DAO_TREASURY) == 27000000, 1005);
    }


    struct GovCapability has key, store {
        mint_cap: Token::MintCapability<STAR::STAR>,
        burn_cap: Token::BurnCapability<STAR::STAR>,
    }

    struct GovTreasury<PoolType> has key, store {
        treasury: Token::Token<STAR::STAR>,
        locked_start_timestamp: u64,    // locked start time
        locked_total_timestamp: u64,    // locked total time
    }

    /// Initial as genesis that will create pool list by Starswap Ecnomic Model list
    public fun genesis_initialize(account: &signer) {
        STAR::assert_genesis_address(account);
        STAR::init(account);

        let precision = STAR::precision();
        let scaling_factor = Math::pow(10, (precision as u64));
        let now_timestamp = Timestamp::now_seconds();

        // Release 40% for farm. genesis release 5%.
        let farm_genesis = calculate_amount_from_percent(GOV_PERCENT_FARM_GENESIS) * (scaling_factor as u128);
        STAR::mint(account, farm_genesis);
        let farm_genesis_token = Account::withdraw<STAR::STAR>(account, farm_genesis);
        TokenSwapFarm::initialize_farm_pool(account, farm_genesis_token);


        // Release 20% for syrup token stake. genesis release 5%.
        let syrup_genesis = calculate_amount_from_percent(GOV_PERCENT_SYRUP_GENESIS) * (scaling_factor as u128);
        STAR::mint(account, syrup_genesis);
        let syrup_genesis_token = Account::withdraw<STAR::STAR>(account, syrup_genesis);
        TokenSwapSyrup::initialize(account, syrup_genesis_token);


        //  Release 2% for community
        let community_total = calculate_amount_from_percent(GOV_PERCENT_COMMUNITY) * (scaling_factor as u128);
        STAR::mint(account, community_total);
        move_to(account, GovTreasury<PoolTypeCommunity>{
            treasury: Account::withdraw<STAR::STAR>(account, community_total),
            locked_start_timestamp : now_timestamp,
            locked_total_timestamp : 0,
        });

        //  Release 1% for initial liquidity
        let initial_liquidity_total = calculate_amount_from_percent(GOV_PERCENT_INITIAL_LIQUIDITY) * (scaling_factor as u128);
        STAR::mint(account, initial_liquidity_total);
        move_to(account, GovTreasury<PoolTypeInitialLiquidity>{
            treasury: Account::withdraw<STAR::STAR>(account, initial_liquidity_total),
            locked_start_timestamp : now_timestamp,
            locked_total_timestamp : 0,
        });
    }

    /// dispatch to acceptor from governance treasury pool
    public fun dispatch<PoolType: store>(account: &signer, acceptor: address, amount: u128) acquires GovTreasury {
        let now_timestamp = Timestamp::now_seconds();
        let treasury = borrow_global_mut<GovTreasury<PoolType>>(Signer::address_of(account));
        if((treasury.locked_start_timestamp + treasury.locked_total_timestamp) <= now_timestamp ) {
            let disp_token = Token::withdraw<STAR::STAR>(&mut treasury.treasury, amount);
            Account::deposit<STAR::STAR>(acceptor, disp_token);
        }
    }

    /// Get balance of treasury
    public fun get_balance_of_treasury<PoolType: store>(): u128 acquires GovTreasury {
        let treasury = borrow_global_mut<GovTreasury<PoolType>>(STAR::token_address());
        Token::value<STAR::STAR>(&treasury.treasury)
    }

    /// Upgrade v2 to v3, only called in barnard net for compatibility
    /// TODO(9191stc): to be remove it before deploy to main net
    public(script) fun upgrade_v2_to_v3_for_syrup_on_testnet(signer: signer, amount: u128) acquires GovCapability {

        let account = Signer::address_of(&signer);
        STAR::assert_genesis_address(&signer);

        let gov_cap = borrow_global<GovCapability>(account);
        let mint_token = Token::mint_with_capability<STAR::STAR>(&gov_cap.mint_cap, amount);

        TokenSwapSyrup::initialize(&signer, mint_token);
    }

    fun calculate_amount_from_percent(percent: u64): u128 {
        let per: u128 = 100;
        ((GOV_TOTAL / per)) * (percent as u128)
    }
}
}