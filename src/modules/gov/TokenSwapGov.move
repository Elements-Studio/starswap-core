// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x8c109349c6bd91411d6bc962e080c4a3 {
module TokenSwapGov {
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Math;
    use 0x1::Signer;
    use 0x1::Timestamp;
    use 0x1::Errors;

    use 0x8c109349c6bd91411d6bc962e080c4a3::STAR;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapFarm;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapSyrup;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapConfig;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapGovPoolType::{
        PoolTypeCommunity,
        PoolTypeIDO,
        PoolTypeProtocolTreasury,
    };

    // 1e8
    const GOV_TOTAL: u128 = 100000000;

    // 10%
    const GOV_PERCENT_DEVELOPER_FUND: u64 = 10;
    // 5%
    const GOV_PERCENT_COMMUNITY: u64 = 5;
    // 60%
    const GOV_PERCENT_FARM: u64 = 60;
    // 10%
    const GOV_PERCENT_SYRUP: u64 = 10;
    // 1%
    const GOV_PERCENT_IDO: u64 = 1;
    // 14%
    const GOV_PERCENT_PROTOCOL_TREASURY: u64 = 14;


    // 5%
    const GOV_PERCENT_FARM_GENESIS: u64 = 5;
    // 5%
    const GOV_PERCENT_SYRUP_GENESIS: u64 = 5;
    // 2%
    const GOV_PERCENT_COMMUNITY_GENESIS: u64 = 2;
    // 2%
    const GOV_PERCENT_PROTOCOL_TREASURY_GENESIS: u64 = 2;


    const ERR_DEPRECATED_UPGRADE_ERROR: u64 = 201;


    #[test] use 0x1::Debug;
    #[test] public fun test_all_issued_amount() {
        let total = GOV_PERCENT_DEVELOPER_FUND +
                    GOV_PERCENT_COMMUNITY +
                    GOV_PERCENT_FARM +
                    GOV_PERCENT_SYRUP +
                    GOV_PERCENT_IDO +
                    GOV_PERCENT_PROTOCOL_TREASURY;

        Debug::print(&total);
        assert(total == 100, 1001);

        assert(calculate_amount_from_percent(GOV_PERCENT_DEVELOPER_FUND) == 10000000, 1002);
        assert(calculate_amount_from_percent(GOV_PERCENT_COMMUNITY) == 5000000, 1003);
        assert(calculate_amount_from_percent(GOV_PERCENT_FARM) == 60000000, 1004);
        assert(calculate_amount_from_percent(GOV_PERCENT_SYRUP) == 10000000, 1005);
        assert(calculate_amount_from_percent(GOV_PERCENT_IDO) == 1000000, 1006);
        assert(calculate_amount_from_percent(GOV_PERCENT_PROTOCOL_TREASURY) == 14000000, 1007);
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

        // Release 60% for farm. genesis release 5%.
        let farm_genesis = calculate_amount_from_percent(GOV_PERCENT_FARM_GENESIS) * (scaling_factor as u128);
        STAR::mint(account, farm_genesis);
        let farm_genesis_token = Account::withdraw<STAR::STAR>(account, farm_genesis);
        TokenSwapFarm::initialize_farm_pool(account, farm_genesis_token);


        // Release 10% for syrup token stake. genesis release 5%.
        let syrup_genesis = calculate_amount_from_percent(GOV_PERCENT_SYRUP_GENESIS) * (scaling_factor as u128);
        STAR::mint(account, syrup_genesis);
        let syrup_genesis_token = Account::withdraw<STAR::STAR>(account, syrup_genesis);
        TokenSwapSyrup::initialize(account, syrup_genesis_token);


        //Release 5% for community. genesis release 2%.
        let community_total = calculate_amount_from_percent(GOV_PERCENT_COMMUNITY_GENESIS) * (scaling_factor as u128);
        STAR::mint(account, community_total);
        move_to(account, GovTreasury<PoolTypeCommunity>{
            treasury: Account::withdraw<STAR::STAR>(account, community_total),
            locked_start_timestamp : now_timestamp,
            locked_total_timestamp : 0,
        });

        //  Release 1% for IDO
        let initial_liquidity_total = calculate_amount_from_percent(GOV_PERCENT_IDO) * (scaling_factor as u128);
        STAR::mint(account, initial_liquidity_total);
        move_to(account, GovTreasury<PoolTypeIDO>{
            treasury: Account::withdraw<STAR::STAR>(account, initial_liquidity_total),
            locked_start_timestamp : now_timestamp,
            locked_total_timestamp : 0,
        });
    }

    /// dispatch to acceptor from governance treasury pool
    public fun dispatch<PoolType: store>(account: &signer, acceptor: address, amount: u128) acquires GovTreasury {
        TokenSwapConfig::assert_global_freeze();

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


    fun calculate_amount_from_percent(percent: u64): u128 {
        let per: u128 = 100;
        ((GOV_TOTAL / per)) * (percent as u128)
    }

    /// Upgrade v2 to v3, only called in barnard net for compatibility
    /// TODO(9191stc): to be remove it before deploy to main net
    public(script) fun upgrade_v2_to_v3_for_syrup_on_testnet(_signer: signer, _amount: u128)  {
        abort Errors::deprecated(ERR_DEPRECATED_UPGRADE_ERROR)
    }

    public(script) fun upgrade_dao_treasury_genesis(signer: signer) {
        STAR::assert_genesis_address(&signer);
        //upgrade dao treasury genesis can only be execute once
        if(! exists<GovTreasury<PoolTypeProtocolTreasury>>(Signer::address_of(&signer))){
            let precision = STAR::precision();
            let scaling_factor = Math::pow(10, (precision as u64));
            let now_timestamp = Timestamp::now_seconds();

            //  Release 24% for dao treasury. genesis release 2%.
            let dao_treasury_genesis = calculate_amount_from_percent(GOV_PERCENT_PROTOCOL_TREASURY_GENESIS) * (scaling_factor as u128);
            STAR::mint(&signer, dao_treasury_genesis);
            move_to(&signer, GovTreasury<PoolTypeProtocolTreasury>{
                treasury: Account::withdraw<STAR::STAR>(&signer, dao_treasury_genesis),
                locked_start_timestamp : now_timestamp,
                locked_total_timestamp : 0,
            });
        };
    }

    fun upgrade_pool_type<PoolTypeOld: store, PoolTypeNew: store>(signer: &signer) acquires GovTreasury {
        STAR::assert_genesis_address(signer);
        let account = Signer::address_of(signer);

        let GovTreasury<PoolTypeOld> {
            treasury,
            locked_start_timestamp,
            locked_total_timestamp,
        } = move_from<GovTreasury<PoolTypeOld>>(account);
        move_to(signer, GovTreasury<PoolTypeNew> {
            treasury,
            locked_start_timestamp,
            locked_total_timestamp,
        });
    }

    public(script) fun upgrade_pool_type_genesis(signer: signer) {
        STAR::assert_genesis_address(&signer);
    }
}
}