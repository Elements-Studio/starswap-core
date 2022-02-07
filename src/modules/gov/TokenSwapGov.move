// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module TokenSwapGov {
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::Math;
    use 0x1::Signer;

    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarm;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrup;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovPoolType::{
    PoolTypeTeam,
    PoolTypeInvestor,
    PoolTypeTechMaintenance,
    PoolTypeMarket,
    PoolTypeStockManagement,
    PoolTypeDaoCrosshain
    };

    // 1e8
    const GOV_TOTAL: u128 = 100000000;
    // 10%
    const GOV_PERCENT_TEAM: u64 = 10;
    // 10%
    const GOV_PERCENT_INVESTOR: u64 = 10;
    // 15%
    const GOV_PERCENT_LIQUIDITY: u64 = 15;
    // 15%
    const GOV_PERCENT_SYRUP: u64 = 15;
    // 2%
    const GOV_PERCENT_MAINTAINANCE: u64 = 2;
    // 5%
    const GOV_PERCENT_MARKET_MANAGE: u64 = 5;
    // 1%
    const GOV_PERCENT_STOCK_MANAGE: u64 = 1;
    // 42%
    const GOV_PERCENT_DAO_CROSSCHAIN: u64 = 42;

    #[test] use 0x1::Debug;

    #[test] public fun test_all_issued_amount() {
        let total = GOV_PERCENT_TEAM +
                    GOV_PERCENT_INVESTOR +
                    GOV_PERCENT_LIQUIDITY +
                    GOV_PERCENT_SYRUP +
                    GOV_PERCENT_MAINTAINANCE +
                    GOV_PERCENT_MARKET_MANAGE +
                    GOV_PERCENT_STOCK_MANAGE +
                    GOV_PERCENT_DAO_CROSSCHAIN;
        Debug::print(&total);
        assert(total == 100, 1001);

        assert(calculate_amount_from_percent(GOV_PERCENT_INVESTOR) == 10000000, 1002);
        assert(calculate_amount_from_percent(GOV_PERCENT_LIQUIDITY) == 15000000, 1003);
        assert(calculate_amount_from_percent(GOV_PERCENT_SYRUP) == 15000000, 1004);
        assert(calculate_amount_from_percent(GOV_PERCENT_DAO_CROSSCHAIN) == 42000000, 1005);
    }


    struct GovCapability has key, store {
        mint_cap: Token::MintCapability<STAR::STAR>,
        burn_cap: Token::BurnCapability<STAR::STAR>,
    }

    struct GovTreasury<PoolType> has key, store {
        treasury: Token::Token<STAR::STAR>
    }

    /// Initial as genesis that will create pool list by Starswap Ecnomic Model list
    public fun genesis_initialize(account: &signer) {
        STAR::assert_genesis_address(account);
        STAR::init(account);

        let precision = STAR::precision();
        let scaling_factor = Math::pow(10, (precision as u64));
        let total = GOV_TOTAL * scaling_factor;

        // Mint genesis tokens
        let (mint_cap, burn_cap) = STAR::mint(account, total);

        // Freeze token capability which named `mint` and `burn` now
        move_to(account, GovCapability{
            mint_cap,
            burn_cap
        });

        // Release 15% for liquidity token stake
        let lptoken_stake_total = calculate_amount_from_percent(GOV_PERCENT_LIQUIDITY) * (scaling_factor as u128);
        let lptoken_stake_total_token = Account::withdraw<STAR::STAR>(account, lptoken_stake_total);
        TokenSwapFarm::initialize_farm_pool(account, lptoken_stake_total_token);

        // Release 15% for syrup token stake
        let syrup_stake_total = calculate_amount_from_percent(GOV_PERCENT_SYRUP) * (scaling_factor as u128);
        let syrup_stake_total_token = Account::withdraw<STAR::STAR>(account, syrup_stake_total);
        TokenSwapSyrup::initialize(account, syrup_stake_total_token);

        // Release 10% for team in 2 years
        let team_total = calculate_amount_from_percent(GOV_PERCENT_TEAM) * (scaling_factor as u128);
        move_to(account, GovTreasury<PoolTypeTeam>{
            treasury: Account::withdraw<STAR::STAR>(account, team_total),
        });

        // Release 10% for investor in 2 years
        let investor_total = calculate_amount_from_percent(GOV_PERCENT_INVESTOR) * (scaling_factor as u128);
        move_to(account, GovTreasury<PoolTypeInvestor>{
            treasury: Account::withdraw<STAR::STAR>(account, investor_total),
        });

        // Release technical maintenance 2% value management in 1 year
        let maintenance_total = calculate_amount_from_percent(GOV_PERCENT_MAINTAINANCE) * (scaling_factor as u128);
        move_to(account, GovTreasury<PoolTypeTechMaintenance>{
            treasury: Account::withdraw<STAR::STAR>(account, maintenance_total),
        });

        // Release market management 5% value management in 1 year
        let market_management = calculate_amount_from_percent(GOV_PERCENT_MARKET_MANAGE) * (scaling_factor as u128);
        move_to(account, GovTreasury<PoolTypeMarket>{
            treasury: Account::withdraw<STAR::STAR>(account, market_management),
        });

        // Release 1% for stock market value
        let stock_management = calculate_amount_from_percent(GOV_PERCENT_STOCK_MANAGE) * (scaling_factor as u128);
        move_to(account, GovTreasury<PoolTypeStockManagement>{
            treasury: Account::withdraw<STAR::STAR>(account, stock_management),
        });

        // Release 42% for DAO and cross chain .
        let dao_and_crosschain_total = calculate_amount_from_percent(GOV_PERCENT_DAO_CROSSCHAIN) * (scaling_factor as u128);
        move_to(account, GovTreasury<PoolTypeDaoCrosshain>{
            treasury: Account::withdraw<STAR::STAR>(account, dao_and_crosschain_total),
        });
    }

    /// dispatch to acceptor from governance treasury pool
    public fun dispatch<PoolType: store>(account: &signer, acceptor: address, amount: u128) acquires GovTreasury {
        let treasury = borrow_global_mut<GovTreasury<PoolType>>(Signer::address_of(account));
        let disp_token = Token::withdraw<STAR::STAR>(&mut treasury.treasury, amount);
        Account::deposit<STAR::STAR>(acceptor, disp_token);
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