// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapGov {
    use std::error;
    use std::option;
    use std::signer;

    use aptos_std::math64;
    use aptos_framework::account;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;
    use aptos_framework::timestamp;

    use SwapAdmin::CommonHelper;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeCommunity, PoolTypeIDO, PoolTypeProtocolTreasury, PoolTypeFarmPool, PoolTypeSyrup, PoolTypeDeveloperFund};
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::WrapperUtil;

    #[test_only]
    use SwapAdmin::SafeMath;

    //2022-11-10 09:00:00 UTC+8
    const GENESIS_TIMESTAMP: u64 = 1668042000;


    // 1e8
    const GOV_TOTAL: u128 = 100000000;

    //Aptos Farm genesis amount
    const APTOS_FARM_GENESIS_AMOUNT: u128 = 14258869866666666;

    //Aptos Syrup genesis amount
    const APTOS_SYRUP_GENESIS_AMOUNT: u128 = 3302057664999999;


    //Aptos Commuity genesis amount
    const APTOS_COMMUNITY_GENESIS_AMOUNT: u128 = 1000000;

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

    // 1 year =  1 * 365 * 86400

    // farm 2 year
    const GOV_PERCENT_FARM_LOCK_TIME: u64 = 2 * 365 * 86400;

    // syrup 1 year
    const GOV_PERCENT_SYRUP_LOCK_TIME: u64 = 1 * 365 * 86400;

    // community 2 year
    const GOV_PERCENT_COMMUNITY_LOCK_TIME: u64 = 2 * 365 * 86400;

    //developerfund 2 year
    const GOV_PERCENT_DEVELOPER_FUND_LOCK_TIME: u64 = 2 * 365 * 86400;


    const ERR_DEPRECATED: u64 = 1;
    const ERR_DEPRECATED_UPGRADE_ERROR: u64 = 201;
    const ERR_WITHDRAW_AMOUNT_TOO_MANY: u64 = 202;
    const ERR_WITHDRAW_AMOUNT_IS_ZERO: u64 = 203;

    #[test] public fun test_all_issued_amount() {
        let total =
            GOV_PERCENT_DEVELOPER_FUND +
                GOV_PERCENT_COMMUNITY +
                GOV_PERCENT_FARM +
                GOV_PERCENT_SYRUP +
                GOV_PERCENT_IDO +
                GOV_PERCENT_PROTOCOL_TREASURY;

        assert!(total == 100, 1001);
        assert!(calculate_amount_from_percent(GOV_PERCENT_DEVELOPER_FUND) == 10000000, 1002);
        assert!(calculate_amount_from_percent(GOV_PERCENT_COMMUNITY) == 5000000, 1003);
        assert!(calculate_amount_from_percent(GOV_PERCENT_FARM) == 60000000, 1004);
        assert!(calculate_amount_from_percent(GOV_PERCENT_SYRUP) == 10000000, 1005);
        assert!(calculate_amount_from_percent(GOV_PERCENT_IDO) == 1000000, 1006);
        assert!(calculate_amount_from_percent(GOV_PERCENT_PROTOCOL_TREASURY) == 14000000, 1007);
    }

    #[test] public fun test_all_linear_treasury() {
        let precision = STAR::precision();
        let scaling_factor = math64::pow(10, (precision as u64));

        let total = (GOV_PERCENT_DEVELOPER_FUND - 0) +
            (GOV_PERCENT_COMMUNITY - GOV_PERCENT_COMMUNITY_GENESIS) +
            (GOV_PERCENT_FARM - GOV_PERCENT_FARM_GENESIS) +
            (GOV_PERCENT_SYRUP - GOV_PERCENT_SYRUP_GENESIS) +
            (GOV_PERCENT_PROTOCOL_TREASURY - GOV_PERCENT_PROTOCOL_TREASURY_GENESIS) +
            GOV_PERCENT_IDO -
            GOV_PERCENT_IDO;

        assert!(total == 85, 1011);
        assert!(
            calculate_amount_from_percent(
                GOV_PERCENT_FARM - GOV_PERCENT_FARM_GENESIS
            ) * (scaling_factor as u128) == 55000000000000000,
            1012
        );
        assert!(
            calculate_amount_from_percent(
                GOV_PERCENT_COMMUNITY - GOV_PERCENT_COMMUNITY_GENESIS
            ) * (scaling_factor as u128) == 3000000000000000,
            1013
        );
        assert!(
            calculate_amount_from_percent(GOV_PERCENT_DEVELOPER_FUND) * (scaling_factor as u128) == 10000000000000000,
            1014
        );
        assert!(
            calculate_amount_from_percent(
                GOV_PERCENT_SYRUP - GOV_PERCENT_SYRUP_GENESIS
            ) * (scaling_factor as u128) == 5000000000000000,
            1015
        );
    }

    #[test] public fun test_time_linear_withdraw() {
        let precision = STAR::precision();
        let scaling_factor = math64::pow(10, (precision as u64));

        // Calculate the amount that can be withdrawn in an hour
        let start_timestamp = 3600  ;
        let now_timestamp = 7200  ;


        let elapsed_time = now_timestamp - start_timestamp;

        let farm_total_timestamp = GOV_PERCENT_FARM_LOCK_TIME;
        let syrup_total_timestamp = GOV_PERCENT_SYRUP_LOCK_TIME;
        let community_total_timestamp = GOV_PERCENT_COMMUNITY_LOCK_TIME;
        let developer_fund_total_timestamp = GOV_PERCENT_DEVELOPER_FUND_LOCK_TIME;

        let farm_can_withdraw_amount = if (elapsed_time >= farm_total_timestamp) {
            calculate_amount_from_percent(GOV_PERCENT_FARM - GOV_PERCENT_FARM_GENESIS)
        }else {
            let second_release = SafeMath::mul_div(
                calculate_amount_from_percent(GOV_PERCENT_FARM - GOV_PERCENT_FARM_GENESIS),
                (scaling_factor as u128),
                (farm_total_timestamp as u128)
            );
            ((now_timestamp - start_timestamp) as u128) * second_release
        };

        let syrup_can_withdraw_amount = if (elapsed_time >= syrup_total_timestamp) {
            calculate_amount_from_percent(GOV_PERCENT_SYRUP - GOV_PERCENT_SYRUP_GENESIS)
        }else {
            let second_release = SafeMath::mul_div(
                calculate_amount_from_percent(GOV_PERCENT_SYRUP - GOV_PERCENT_SYRUP_GENESIS),
                (scaling_factor as u128),
                (syrup_total_timestamp as u128)
            );
            ((now_timestamp - start_timestamp) as u128) * second_release
        };

        let community_can_withdraw_amount = if (elapsed_time >= community_total_timestamp) {
            calculate_amount_from_percent(GOV_PERCENT_COMMUNITY - GOV_PERCENT_COMMUNITY_GENESIS)
        }else {
            let second_release = SafeMath::mul_div(
                calculate_amount_from_percent(GOV_PERCENT_COMMUNITY - GOV_PERCENT_COMMUNITY_GENESIS),
                (scaling_factor as u128),
                (community_total_timestamp as u128)
            );
            ((now_timestamp - start_timestamp) as u128) * second_release
        };

        let developer_fund_can_withdraw_amount = if (elapsed_time >= developer_fund_total_timestamp) {
            calculate_amount_from_percent(GOV_PERCENT_DEVELOPER_FUND)
        }else {
            let second_release = SafeMath::mul_div(
                calculate_amount_from_percent(GOV_PERCENT_DEVELOPER_FUND),
                (scaling_factor as u128),
                (developer_fund_total_timestamp as u128)
            );
            ((now_timestamp - start_timestamp) as u128) * second_release
        };

        assert!(farm_can_withdraw_amount == 3139269404400, 1021);
        assert!(syrup_can_withdraw_amount == 570776252400, 1022);
        assert!(community_can_withdraw_amount == 171232873200, 1023);
        assert!(developer_fund_can_withdraw_amount == 570776252400, 1024);
    }

    #[test_only]
    public fun get_genesis_timestamp():u64{
        GENESIS_TIMESTAMP
    }

    struct GovCapability has key, store {
        mint_cap: coin::MintCapability<STAR::STAR>,
        burn_cap: coin::BurnCapability<STAR::STAR>,
    }

    struct GovTreasuryV2<phantom PoolType> has key, store {
        linear_total: u128,
        //LinearGovTreasury total amount
        linear_treasury: Coin<STAR::STAR>,
        genesis_treasury: Coin<STAR::STAR>,
        locked_start_timestamp: u64,
        // locked start time
        locked_total_timestamp: u64,
        // locked total time
    }

    struct LinearGovTreasuryWithdrawEvent<phantom PoolType> has drop, store {
        amount: u128,
        remainder: u128,
        signer: address,
        receiver: address,
    }

    struct GenesisGovTreasuryWithdrawEvent<phantom PoolType> has drop, store {
        amount: u128,
        remainder: u128,
        signer: address,
        receiver: address,
    }

    struct GovTreasuryEvent<phantom PoolType> has key, store {
        withdraw_linearGovTreasury_event_handler: event::EventHandle<LinearGovTreasuryWithdrawEvent<PoolType>>,
        withdraw_genesisGovTreasury_event_handler: event::EventHandle<GenesisGovTreasuryWithdrawEvent<PoolType>>,
    }

    /// Initial as genesis that will create pool list by Starswap Ecnomic Model list
    public fun genesis_initialize(account: &signer) {
        STAR::assert_genesis_address(account);
        STAR::init(account);
        CommonHelper::safe_accept_token<STAR::STAR>(account);

        let precision = STAR::precision();
        let scaling_factor = math64::pow(10, (precision as u64));

        // Release farm APTOS_FARM_GENESIS_AMOUNT . release 5% Farm yield, and  release 800,000,000,000,000 to genesis swap pool.
        let farm_release = APTOS_FARM_GENESIS_AMOUNT / 100 * 5 ;
        STAR::mint(account, APTOS_FARM_GENESIS_AMOUNT);
        let farm_genesis_token = coin::withdraw<STAR::STAR>(account, (farm_release as u64));
        TokenSwapFarm::initialize_farm_pool(account, farm_genesis_token);


        // Release  syrup token stake. release 5% syrup yield.
        let syrup_release = APTOS_SYRUP_GENESIS_AMOUNT / 100 * 5 ;
        STAR::mint(account, APTOS_SYRUP_GENESIS_AMOUNT);
        let syrup_genesis_token = coin::withdraw<STAR::STAR>(account, (syrup_release as u64));
        TokenSwapSyrup::initialize(account, syrup_genesis_token);

        STAR::mint(account, APTOS_COMMUNITY_GENESIS_AMOUNT * (scaling_factor as u128));
    }

    /// dispatch to acceptor from governance treasury pool
    public fun dispatch<PoolType>(
        account: &signer,
        acceptor: address,
        amount: u128
    ) acquires GovTreasuryV2, GovTreasuryEvent {
        TokenSwapConfig::assert_global_freeze();

        assert!(amount != 0, error::invalid_argument(ERR_WITHDRAW_AMOUNT_IS_ZERO));

        let can_withdraw_amount = get_balance_of_treasury<PoolType>();
        assert!(can_withdraw_amount >= amount, error::invalid_argument(ERR_WITHDRAW_AMOUNT_TOO_MANY));

        let treasury = borrow_global_mut<GovTreasuryV2<PoolType>>(signer::address_of(account));
        let disp_token = coin::extract<STAR::STAR>(&mut treasury.genesis_treasury, (amount as u64));

        coin::deposit<STAR::STAR>(acceptor, disp_token);

        let treasury_event = borrow_global_mut<GovTreasuryEvent<PoolType>>(signer::address_of(account));
        event::emit_event(
            &mut treasury_event.withdraw_genesisGovTreasury_event_handler,
            GenesisGovTreasuryWithdrawEvent<PoolType> {
                amount,
                remainder: WrapperUtil::coin_value<STAR::STAR>(&treasury.genesis_treasury),
                signer: signer::address_of(account),
                receiver: acceptor,
            }
        );
    }

    /// Initialize the economic model of linear release
    public fun linear_initialize(account: &signer) {
        STAR::assert_genesis_address(account);

        let precision = STAR::precision();
        let scaling_factor = math64::pow(10, (precision as u64));


        // linear APTOS_FARM_GENESIS_AMOUNT - 5 % - 80w for farm linear.
        let farm_linear_total = (
            APTOS_FARM_GENESIS_AMOUNT -
                (APTOS_FARM_GENESIS_AMOUNT / 100 * 5 ) -
                (800 * 1000 * (scaling_factor as u128))
        );
        move_to(account, GovTreasuryV2<PoolTypeFarmPool> {
            linear_total: farm_linear_total,
            linear_treasury: coin::withdraw<STAR::STAR>(account, (farm_linear_total as u64)),
            genesis_treasury: coin::zero<STAR::STAR>(),
            locked_start_timestamp: GENESIS_TIMESTAMP,
            locked_total_timestamp: GOV_PERCENT_FARM_LOCK_TIME,
        });

        move_to(account, GovTreasuryEvent {
            withdraw_linearGovTreasury_event_handler: account::new_event_handle<LinearGovTreasuryWithdrawEvent<PoolTypeFarmPool>>(
                account
            ),
            withdraw_genesisGovTreasury_event_handler: account::new_event_handle<GenesisGovTreasuryWithdrawEvent<PoolTypeFarmPool>>(
                account
            ),
        });

        // linear APTOS_SYRUP_GENESIS_AMOUNT - 5 % for syrup.
        let syrup_linear_total = APTOS_SYRUP_GENESIS_AMOUNT - (APTOS_SYRUP_GENESIS_AMOUNT / 100 * 5 );
        move_to(account, GovTreasuryV2<PoolTypeSyrup> {
            linear_total: syrup_linear_total,
            linear_treasury: coin::withdraw<STAR::STAR>(account, (syrup_linear_total as u64)),
            genesis_treasury: coin::zero<STAR::STAR>(),
            locked_start_timestamp: GENESIS_TIMESTAMP,
            locked_total_timestamp: GOV_PERCENT_SYRUP_LOCK_TIME,
        });

        move_to(account, GovTreasuryEvent {
            withdraw_linearGovTreasury_event_handler: account::new_event_handle<LinearGovTreasuryWithdrawEvent<PoolTypeSyrup>>(
                account
            ),
            withdraw_genesisGovTreasury_event_handler: account::new_event_handle<GenesisGovTreasuryWithdrawEvent<PoolTypeSyrup>>(
                account
            ),
        });

        // APTOS_COMMUNITY_GENESIS_AMOUNT  for community linear treasury.
        // 40% APTOS_COMMUNITY_GENESIS_AMOUNT  for community genesis treasury
        let commuity_linear_total = APTOS_COMMUNITY_GENESIS_AMOUNT * (scaling_factor as u128);
        let commuity_genesis = APTOS_COMMUNITY_GENESIS_AMOUNT / 100 * 40 * (scaling_factor as u128);
        move_to(account, GovTreasuryV2<PoolTypeCommunity> {
            linear_total: commuity_linear_total - commuity_genesis,
            linear_treasury: coin::withdraw<STAR::STAR>(account, ((commuity_linear_total - commuity_genesis) as u64)),
            genesis_treasury: coin::withdraw<STAR::STAR>(account, (commuity_genesis as u64)),
            locked_start_timestamp: GENESIS_TIMESTAMP,
            locked_total_timestamp: GOV_PERCENT_SYRUP_LOCK_TIME,
        });

        move_to(account, GovTreasuryEvent {
            withdraw_linearGovTreasury_event_handler: account::new_event_handle<LinearGovTreasuryWithdrawEvent<PoolTypeCommunity>>(
                account
            ),
            withdraw_genesisGovTreasury_event_handler: account::new_event_handle<GenesisGovTreasuryWithdrawEvent<PoolTypeCommunity>>(
                account
            ),
        });
    }

    /// Linear extraction function
    /// (because the models of Farm and syrup are different, the function is set to private)
    fun linear_withdraw<PoolType>(
        account: &signer,
        to: address,
        amount: u128
    ) acquires GovTreasuryV2, GovTreasuryEvent {
        TokenSwapConfig::assert_global_freeze();

        let can_withdraw_amount = get_can_withdraw_of_linear_treasury<PoolType>();
        assert!(amount != 0, error::invalid_argument(ERR_WITHDRAW_AMOUNT_IS_ZERO));
        assert!(can_withdraw_amount >= amount, error::invalid_argument(ERR_WITHDRAW_AMOUNT_TOO_MANY));

        let treasury = borrow_global_mut<GovTreasuryV2<PoolType>>(signer::address_of(account));

        let disp_token = coin::extract<STAR::STAR>(&mut treasury.linear_treasury, (amount as u64));
        coin::deposit<STAR::STAR>(to, disp_token);

        let treasury_event =
            borrow_global_mut<GovTreasuryEvent<PoolType>>(signer::address_of(account));
        event::emit_event(
            &mut treasury_event.withdraw_linearGovTreasury_event_handler,
            LinearGovTreasuryWithdrawEvent<PoolType> {
                amount,
                remainder: WrapperUtil::coin_value<STAR::STAR>(&treasury.linear_treasury),
                signer: signer::address_of(account),
                receiver: to,
            }
        );
    }

    //Community Linear Treasury Extraction Function
    public fun linear_withdraw_community(
        account: &signer,
        to: address,
        amount: u128
    ) acquires GovTreasuryV2, GovTreasuryEvent {
        linear_withdraw<PoolTypeCommunity>(account, to, amount);
    }

    /// Farm and syrup linear treasury extraction functions need to pass in generic parameters
    /// PoolTypeFarmPool ,PoolTypeSyrup
    fun linear_withdraw_farm_syrup<PoolType>(
        account: &signer
    ): Coin<STAR::STAR> acquires GovTreasuryV2, GovTreasuryEvent {
        TokenSwapConfig::assert_global_freeze();

        let can_withdraw_amount = get_can_withdraw_of_linear_treasury<PoolType>();

        if (can_withdraw_amount == 0) {
            return coin::zero<STAR::STAR>()
        };

        let treasury = borrow_global_mut<GovTreasuryV2<PoolType>>(STAR::token_address());

        let disp_token = coin::extract<STAR::STAR>(&mut treasury.linear_treasury, (can_withdraw_amount as u64));
        let treasury_event = borrow_global_mut<GovTreasuryEvent<PoolType>>(STAR::token_address());

        event::emit_event(
            &mut treasury_event.withdraw_linearGovTreasury_event_handler,
            LinearGovTreasuryWithdrawEvent<PoolType> {
                amount: can_withdraw_amount,
                remainder: WrapperUtil::coin_value<STAR::STAR>(&treasury.linear_treasury),
                signer: signer::address_of(account),
                receiver: STAR::token_address(),
            }
        );

        disp_token
    }

    //Farm Linear Treasury Extraction Function
    public fun linear_withdraw_farm(account: &signer, _amount: u128) acquires GovTreasuryV2, GovTreasuryEvent {
        let disp_token = linear_withdraw_farm_syrup<PoolTypeFarmPool>(account);
        TokenSwapFarm::deposit<PoolTypeFarmPool, STAR::STAR>(account, disp_token);
    }

    //Syrup Linear Treasury Extraction Function
    public fun linear_withdraw_syrup(account: &signer, _amount: u128) acquires GovTreasuryV2, GovTreasuryEvent {
        let disp_token = linear_withdraw_farm_syrup<PoolTypeSyrup>(account);
        TokenSwapSyrup::deposit<PoolTypeSyrup, STAR::STAR>(account, disp_token);
    }

    //Amount to get linear treasury
    public fun get_balance_of_linear_treasury<PoolType>(): u128 acquires GovTreasuryV2 {
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());
        WrapperUtil::coin_value<STAR::STAR>(&treasury.linear_treasury)
    }

    //Get the total number of locks in the linear treasury
    public fun get_total_of_linear_treasury<PoolType>(): u128 acquires GovTreasuryV2 {
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());
        treasury.linear_total
    }

    //Get the lockup start time of the linear treasury
    public fun get_start_of_linear_treasury<PoolType>(): u64 acquires GovTreasuryV2 {
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());
        treasury.locked_start_timestamp
    }

    //Get the total duration of the linear treasury lock
    public fun get_hodl_of_linear_treasury<PoolType>(): u64 acquires GovTreasuryV2 {
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());
        treasury.locked_total_timestamp
    }

    //Get the amount you can withdraw from the linear treasury
    public fun get_can_withdraw_of_linear_treasury<PoolType>(): u128 acquires GovTreasuryV2 {
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());
        let now_timestamp = timestamp::now_seconds();

        if (now_timestamp >= (treasury.locked_start_timestamp + treasury.locked_total_timestamp)) {
            return WrapperUtil::coin_value<STAR::STAR>(&treasury.linear_treasury)
        };
        let second_release = treasury.linear_total / (treasury.locked_total_timestamp as u128);

        let amount = ((now_timestamp - treasury.locked_start_timestamp) as u128) * second_release;

        WrapperUtil::coin_value<STAR::STAR>(&treasury.linear_treasury) - (treasury.linear_total - amount)
    }

    /// Get balance of treasury
    public fun get_balance_of_treasury<PoolType>(): u128 acquires GovTreasuryV2 {
        let treasury = borrow_global_mut<GovTreasuryV2<PoolType>>(STAR::token_address());
        WrapperUtil::coin_value<STAR::STAR>(&treasury.genesis_treasury)
    }


    fun calculate_amount_from_percent(percent: u64): u128 {
        let per: u128 = 100;
        ((GOV_TOTAL / per)) * (percent as u128)
    }

    public fun get_circulating_supply(): u128 acquires GovTreasuryV2 {
        let total = option::get_with_default(&coin::supply<STAR::STAR>(), 0u128);

        total
            - get_balance_of_linear_treasury<PoolTypeCommunity>()
            - get_balance_of_treasury<PoolTypeCommunity>()
            - get_balance_of_linear_treasury<PoolTypeFarmPool>()
            - get_balance_of_linear_treasury<PoolTypeSyrup>()
            - TokenSwapFarm::get_treasury_balance<PoolTypeFarmPool, STAR::STAR>()
            - TokenSwapSyrup::get_treasury_balance<PoolTypeSyrup, STAR::STAR>()
            - get_balance_of_treasury<PoolTypeIDO>()
            - get_balance_of_linear_treasury<PoolTypeProtocolTreasury>()
            - get_balance_of_treasury<PoolTypeProtocolTreasury>()
            - get_balance_of_linear_treasury<PoolTypeDeveloperFund>()
            - get_balance_of_treasury<PoolTypeDeveloperFund>()
    }
}