// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapGov {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Math;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Event;
    use StarcoinFramework::Errors;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapConfig;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeCommunity,
        PoolTypeIDO,
        PoolTypeProtocolTreasury,
        PoolTypeFarmPool ,
        PoolTypeSyrup ,
        PoolTypeDeveloperFund,
    };
    #[test_only]
    use StarcoinFramework::Debug;
    use StarcoinFramework::Signer::address_of;

    //2022-03-05 10:00:00 UTC+8
    const GENESIS_TIMESTAMP:u64 = 1646445600;


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

    // 1 year =  1 * 365 * 86400

    // farm 2 year
    const GOV_PERCENT_FARM_LOCK_TIME : u64= 2 * 365 * 86400;

    // syrup 1 year
    const GOV_PERCENT_SYRUP_LOCK_TIME : u64 = 1 * 365 * 86400;

    // community 2 year
    const GOV_PERCENT_COMMUNITY_LOCK_TIME : u64 = 2 * 365 * 86400;

    //developerfund 2 year
    const GOV_PERCENT_DEVELOPER_FUND_LOCK_TIME : u64 = 2 * 365 * 86400;


    const ERR_DEPRECATED: u64 = 1;
    const ERR_DEPRECATED_UPGRADE_ERROR: u64 = 201;
    const ERR_WITHDRAW_AMOUNT_TOO_MANY: u64 = 202;
    const ERR_WITHDRAW_AMOUNT_IS_ZERO: u64 = 203;

    #[test] public fun test_all_issued_amount() {
        let total = GOV_PERCENT_DEVELOPER_FUND +
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
        let scaling_factor = Math::pow(10, (precision as u64));

        let total = (   GOV_PERCENT_DEVELOPER_FUND     - 0                                 ) +
                    (   GOV_PERCENT_COMMUNITY          - GOV_PERCENT_COMMUNITY_GENESIS     ) +
                    (   GOV_PERCENT_FARM               - GOV_PERCENT_FARM_GENESIS          ) +
                    (   GOV_PERCENT_SYRUP              - GOV_PERCENT_SYRUP_GENESIS         ) +
                    (   GOV_PERCENT_PROTOCOL_TREASURY  - GOV_PERCENT_PROTOCOL_TREASURY_GENESIS) + 
                        GOV_PERCENT_IDO -
                        GOV_PERCENT_IDO;


        assert!(total == 85, 1011);
        assert!(calculate_amount_from_percent(  GOV_PERCENT_FARM      - GOV_PERCENT_FARM_GENESIS      ) * (scaling_factor as u128)    == 55000000000000000, 1012);
        assert!(calculate_amount_from_percent(  GOV_PERCENT_COMMUNITY - GOV_PERCENT_COMMUNITY_GENESIS ) * (scaling_factor as u128)    == 3000000000000000 , 1013);
        assert!(calculate_amount_from_percent(  GOV_PERCENT_DEVELOPER_FUND                            ) * (scaling_factor as u128)    == 10000000000000000, 1014);
        assert!(calculate_amount_from_percent(  GOV_PERCENT_SYRUP     - GOV_PERCENT_SYRUP_GENESIS     ) * (scaling_factor as u128)    == 5000000000000000 , 1015);
    }

    #[test] public fun test_time_linear_withdraw() {
        let precision = STAR::precision();
        let scaling_factor = Math::pow(10, (precision as u64));

        // Calculate the amount that can be withdrawn in an hour
        let start_timestamp = 3600  ;
        let now_timestamp   = 7200  ;


        let elapsed_time = now_timestamp - start_timestamp;

        let farm_total_timestamp        = GOV_PERCENT_FARM_LOCK_TIME;
        let syrup_total_timestamp       = GOV_PERCENT_SYRUP_LOCK_TIME;
        let community_total_timestamp   = GOV_PERCENT_COMMUNITY_LOCK_TIME;
        let developer_fund_total_timestamp = GOV_PERCENT_DEVELOPER_FUND_LOCK_TIME;

        let farm_can_withdraw_amount = if (elapsed_time >= farm_total_timestamp) {
            calculate_amount_from_percent(  GOV_PERCENT_FARM      -  GOV_PERCENT_FARM_GENESIS      )
        }else {
            let second_release = Math::mul_div( calculate_amount_from_percent(GOV_PERCENT_FARM - GOV_PERCENT_FARM_GENESIS ) , (scaling_factor as u128) , (farm_total_timestamp as u128));
            (( now_timestamp - start_timestamp  ) as u128) * second_release
        };

        let syrup_can_withdraw_amount = if (elapsed_time >= syrup_total_timestamp) {
            calculate_amount_from_percent(  GOV_PERCENT_SYRUP      -  GOV_PERCENT_SYRUP_GENESIS     ) 
        }else {
            let second_release = Math::mul_div( calculate_amount_from_percent(GOV_PERCENT_SYRUP - GOV_PERCENT_SYRUP_GENESIS ) , (scaling_factor as u128) , (syrup_total_timestamp as u128));
            (( now_timestamp - start_timestamp  ) as u128) * second_release
        };

        let community_can_withdraw_amount = if (elapsed_time >= community_total_timestamp) {
            calculate_amount_from_percent(  GOV_PERCENT_COMMUNITY      -  GOV_PERCENT_COMMUNITY_GENESIS     ) 
        }else {
            let second_release = Math::mul_div( calculate_amount_from_percent(GOV_PERCENT_COMMUNITY - GOV_PERCENT_COMMUNITY_GENESIS ) , (scaling_factor as u128) , (community_total_timestamp as u128));
            (( now_timestamp - start_timestamp  ) as u128) * second_release
        };

        let developer_fund_can_withdraw_amount = if (elapsed_time >= developer_fund_total_timestamp) {
            calculate_amount_from_percent(GOV_PERCENT_DEVELOPER_FUND    ) 
        }else {
            let second_release = Math::mul_div( calculate_amount_from_percent(GOV_PERCENT_DEVELOPER_FUND ) , (scaling_factor as u128) , (developer_fund_total_timestamp as u128));
            (( now_timestamp - start_timestamp  ) as u128) * second_release
        };

        assert!( farm_can_withdraw_amount           ==  3139269404400   , 1021);
        assert!( syrup_can_withdraw_amount          ==  570776252400    , 1022);
        assert!( community_can_withdraw_amount      ==  171232873200    , 1023);
        assert!( developer_fund_can_withdraw_amount ==  570776252400    , 1024);
    }
    struct GovCapability has key, store {
        mint_cap: Token::MintCapability<STAR::STAR>,
        burn_cap: Token::BurnCapability<STAR::STAR>,
    }

    struct GovTreasury<phantom PoolType> has key, store {
        treasury: Token::Token<STAR::STAR>,
        locked_start_timestamp: u64,    // locked start time
        locked_total_timestamp: u64,    // locked total time
    }

    struct GovTreasuryV2<phantom PoolType> has key,store{
        linear_total:u128,                         //LinearGovTreasury total amount 
        linear_treasury:Token::Token<STAR::STAR>,
        genesis_treasury:Token::Token<STAR::STAR>,
        locked_start_timestamp:u64,         // locked start time
        locked_total_timestamp:u64,         // locked total time
    }

    struct LinearGovTreasuryWithdrawEvent <phantom PoolType> has drop, store{
        amount:u128,
        remainder:u128,
        signer:address,
        receiver:address,
    }

    struct GenesisGovTreasuryWithdrawEvent <phantom PoolType> has drop, store{
        amount:u128,
        remainder:u128,
        signer:address,
        receiver:address,
    }
    struct GovTreasuryEvent<phantom PoolType> has key, store{ 
        withdraw_linearGovTreasury_event_handler:Event::EventHandle<LinearGovTreasuryWithdrawEvent<PoolType>>,
        withdraw_genesisGovTreasury_event_handler:Event::EventHandle<GenesisGovTreasuryWithdrawEvent<PoolType>>,
    }

    struct GovTreasuryMultiChainEvent has key, store{
        burn_linearGovTreasury_event_handler:Event::EventHandle<LinearGovTreasuryMultiBurnEvent>,
    }

    struct LinearGovTreasuryMultiBurnEvent has drop, store{
        amount: u128,
        chain: vector<u8>,
        treasury_type:Token::TokenCode
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
    public fun dispatch<PoolType: store>(account: &signer, acceptor: address, amount: u128) acquires GovTreasuryV2 ,GovTreasuryEvent{
        TokenSwapConfig::assert_global_freeze();
        
        assert!(amount != 0, Errors::invalid_argument(ERR_WITHDRAW_AMOUNT_IS_ZERO));
        
        let can_withdraw_amount = get_balance_of_treasury<PoolType>();
        assert!(can_withdraw_amount >= amount, Errors::invalid_argument(ERR_WITHDRAW_AMOUNT_TOO_MANY));

        let treasury = borrow_global_mut<GovTreasuryV2<PoolType>>(Signer::address_of(account));
        let disp_token = Token::withdraw<STAR::STAR>(&mut treasury.genesis_treasury, amount);

        Account::deposit<STAR::STAR>(acceptor, disp_token);
        
        let treasury_event = borrow_global_mut<GovTreasuryEvent<PoolType>>(Signer::address_of(account));
        Event::emit_event(&mut treasury_event.withdraw_genesisGovTreasury_event_handler, GenesisGovTreasuryWithdrawEvent<PoolType> {
            amount:amount,
            remainder:Token::value<STAR::STAR>(&treasury.genesis_treasury),
            signer:Signer::address_of(account),
            receiver:acceptor,
        });
        
    }

    //Initialize the economic model of linear release
     public fun linear_initialize(account: &signer) acquires GovTreasury {
        STAR::assert_genesis_address(account);

        let precision = STAR::precision();
        let scaling_factor = Math::pow(10, (precision as u64));


        // linear 60% - 5 % for farm. 
        let farm_linear = calculate_amount_from_percent(GOV_PERCENT_FARM - GOV_PERCENT_FARM_GENESIS ) * (scaling_factor as u128);
        STAR::mint(account, farm_linear);
        move_to(account, GovTreasuryV2<PoolTypeFarmPool>{
            linear_total: farm_linear,
            linear_treasury: Account::withdraw<STAR::STAR>(account, farm_linear),
            genesis_treasury:Token::zero<STAR::STAR>(),
            locked_start_timestamp : GENESIS_TIMESTAMP,
            locked_total_timestamp : GOV_PERCENT_FARM_LOCK_TIME,
        });

        move_to(account, GovTreasuryEvent{
            withdraw_linearGovTreasury_event_handler:Event::new_event_handle<LinearGovTreasuryWithdrawEvent<PoolTypeFarmPool>>(account),
            withdraw_genesisGovTreasury_event_handler:Event::new_event_handle<GenesisGovTreasuryWithdrawEvent<PoolTypeFarmPool>>(account),
        });

        // linear 10% - 5 % for syrup. 
        let syrup_linear = calculate_amount_from_percent(GOV_PERCENT_SYRUP - GOV_PERCENT_SYRUP_GENESIS ) * (scaling_factor as u128);
        STAR::mint(account, syrup_linear);
        move_to(account, GovTreasuryV2<PoolTypeSyrup>{
            linear_total:syrup_linear,
            linear_treasury: Account::withdraw<STAR::STAR>(account, syrup_linear),
            genesis_treasury:Token::zero<STAR::STAR>(),
            locked_start_timestamp : GENESIS_TIMESTAMP,
            locked_total_timestamp : GOV_PERCENT_SYRUP_LOCK_TIME,
        });

        move_to(account, GovTreasuryEvent{
            withdraw_linearGovTreasury_event_handler:Event::new_event_handle<LinearGovTreasuryWithdrawEvent<PoolTypeSyrup>>(account),
            withdraw_genesisGovTreasury_event_handler:Event::new_event_handle<GenesisGovTreasuryWithdrawEvent<PoolTypeSyrup>>(account),
        });

        // linear 5% - 2 % for community. 
        let community_linear = calculate_amount_from_percent(GOV_PERCENT_COMMUNITY - GOV_PERCENT_COMMUNITY_GENESIS ) * (scaling_factor as u128);
        let GovTreasury{ 
            treasury:communtiy_genesis_token,
            locked_start_timestamp:_,
            locked_total_timestamp:_ 
            } =  move_from<GovTreasury<PoolTypeCommunity>>(Signer::address_of(account));
        STAR::mint(account, community_linear);
        move_to(account, GovTreasuryV2<PoolTypeCommunity>{
            linear_total:community_linear,
            linear_treasury: Account::withdraw<STAR::STAR>(account, community_linear),
            genesis_treasury:communtiy_genesis_token,
            locked_start_timestamp : GENESIS_TIMESTAMP,
            locked_total_timestamp : GOV_PERCENT_COMMUNITY_LOCK_TIME,
        });
        
        move_to(account, GovTreasuryEvent{
            withdraw_linearGovTreasury_event_handler:Event::new_event_handle<LinearGovTreasuryWithdrawEvent<PoolTypeCommunity>>(account),
            withdraw_genesisGovTreasury_event_handler:Event::new_event_handle<GenesisGovTreasuryWithdrawEvent<PoolTypeCommunity>>(account),
        });

        // linear 10%  for developerfund. 
        let developerfund_linear = calculate_amount_from_percent(GOV_PERCENT_DEVELOPER_FUND) * (scaling_factor as u128);
        STAR::mint(account, developerfund_linear);
        move_to(account, GovTreasuryV2<PoolTypeDeveloperFund>{
            linear_total:developerfund_linear,
            linear_treasury: Account::withdraw<STAR::STAR>(account, developerfund_linear),
            genesis_treasury:Token::zero<STAR::STAR>(),
            locked_start_timestamp : GENESIS_TIMESTAMP,
            locked_total_timestamp : GOV_PERCENT_DEVELOPER_FUND_LOCK_TIME,
        });

        move_to(account, GovTreasuryEvent{
            withdraw_linearGovTreasury_event_handler:Event::new_event_handle<LinearGovTreasuryWithdrawEvent<PoolTypeDeveloperFund>>(account),
            withdraw_genesisGovTreasury_event_handler:Event::new_event_handle<GenesisGovTreasuryWithdrawEvent<PoolTypeDeveloperFund>>(account),
        });


        
        //  ido.
        let GovTreasury{ 
            treasury:ido_genesis_token,
            locked_start_timestamp:_,
            locked_total_timestamp:_ 
            } =  move_from<GovTreasury<PoolTypeIDO>>(Signer::address_of(account));

        move_to(account, GovTreasuryV2<PoolTypeIDO>{
            linear_total:0,
            linear_treasury: Token::zero<STAR::STAR>(),
            genesis_treasury:ido_genesis_token,
            locked_start_timestamp : GENESIS_TIMESTAMP,
            locked_total_timestamp : 0,
        });
        
        move_to(account, GovTreasuryEvent{
            withdraw_linearGovTreasury_event_handler:Event::new_event_handle<LinearGovTreasuryWithdrawEvent<PoolTypeIDO>>(account),
            withdraw_genesisGovTreasury_event_handler:Event::new_event_handle<GenesisGovTreasuryWithdrawEvent<PoolTypeIDO>>(account),
        });

        let GovTreasury{ 
            treasury:protocol_genesis_token,
            locked_start_timestamp:_,
            locked_total_timestamp:_ 
            } =  move_from<GovTreasury<PoolTypeProtocolTreasury>>(Signer::address_of(account));

        move_to(account, GovTreasuryV2<PoolTypeProtocolTreasury>{
            linear_total:0,
            linear_treasury: Token::zero<STAR::STAR>(),
            genesis_treasury:protocol_genesis_token,
            locked_start_timestamp : GENESIS_TIMESTAMP,
            locked_total_timestamp : 0,
        });
        
        move_to(account, GovTreasuryEvent{
            withdraw_linearGovTreasury_event_handler:Event::new_event_handle<LinearGovTreasuryWithdrawEvent<PoolTypeProtocolTreasury>>(account),
            withdraw_genesisGovTreasury_event_handler:Event::new_event_handle<GenesisGovTreasuryWithdrawEvent<PoolTypeProtocolTreasury>>(account),
        });


    }
    //Linear extraction function (because the models of Farm and syrup are different, the function is set to private)
    fun linear_withdraw<PoolType: store>(account:&signer,to:address,amount:u128) acquires GovTreasuryV2,GovTreasuryEvent{
        TokenSwapConfig::assert_global_freeze();
        let can_withdraw_amount = get_can_withdraw_of_linear_treasury<PoolType>();
        assert!(amount != 0, Errors::invalid_argument(ERR_WITHDRAW_AMOUNT_IS_ZERO));
        assert!(can_withdraw_amount >= amount, Errors::invalid_argument(ERR_WITHDRAW_AMOUNT_TOO_MANY));

        let treasury = borrow_global_mut<GovTreasuryV2<PoolType>>(Signer::address_of(account));        
        
        let disp_token = Token::withdraw<STAR::STAR>(&mut treasury.linear_treasury, amount);
        Account::deposit<STAR::STAR>(to, disp_token); 

        let treasury_event = borrow_global_mut<GovTreasuryEvent<PoolType>>(Signer::address_of(account));
        Event::emit_event(&mut treasury_event.withdraw_linearGovTreasury_event_handler, LinearGovTreasuryWithdrawEvent<PoolType> {
            amount:amount,
            remainder:Token::value<STAR::STAR>(&treasury.linear_treasury),
            signer:Signer::address_of(account),
            receiver:to,
        });
    }
    //Community Linear Treasury Extraction Function
    public fun linear_withdraw_community(account:&signer,to:address,amount:u128) acquires GovTreasuryV2,GovTreasuryEvent{
        linear_withdraw<PoolTypeCommunity>(account,to,amount);
    }
    //Developer Fund Linear Treasury Extraction Function
    public fun linear_withdraw_developerfund(account:&signer,to:address,amount:u128) acquires GovTreasuryV2,GovTreasuryEvent{
        linear_withdraw<PoolTypeDeveloperFund>(account,to,amount);
    }
    //Farm and syrup linear treasury extraction functions need to pass in generic parameters        PoolTypeFarmPool ,PoolTypeSyrup 
    fun linear_withdraw_farm_syrup<PoolType: store>(account:&signer):Token::Token<STAR::STAR> acquires GovTreasuryV2,GovTreasuryEvent{
            TokenSwapConfig::assert_global_freeze();
            
            let can_withdraw_amount = get_can_withdraw_of_linear_treasury<PoolType>();

            if( can_withdraw_amount == 0 ){
                return Token::zero<STAR::STAR>() 
            };

            let treasury = borrow_global_mut<GovTreasuryV2<PoolType>>(STAR::token_address());        
            
            let disp_token = Token::withdraw<STAR::STAR>(&mut treasury.linear_treasury, can_withdraw_amount);
            let treasury_event = borrow_global_mut<GovTreasuryEvent<PoolType>>(STAR::token_address());

            Event::emit_event(&mut treasury_event.withdraw_linearGovTreasury_event_handler, LinearGovTreasuryWithdrawEvent<PoolType> {
                amount:can_withdraw_amount,
                remainder:Token::value<STAR::STAR>(&treasury.linear_treasury),
                signer:Signer::address_of(account),
                receiver:STAR::token_address(),
            });

            disp_token
    }
    //Farm Linear Treasury Extraction Function
    public fun linear_withdraw_farm(account:&signer,_amount :u128) acquires GovTreasuryV2,GovTreasuryEvent{
        let disp_token = linear_withdraw_farm_syrup<PoolTypeFarmPool>(account);
        TokenSwapFarm::deposit<PoolTypeFarmPool,STAR::STAR>(account,disp_token);
    }
    //Syrup Linear Treasury Extraction Function
    public fun linear_withdraw_syrup(account:&signer,_amount :u128) acquires GovTreasuryV2,GovTreasuryEvent{
        let disp_token = linear_withdraw_farm_syrup<PoolTypeSyrup>(account);
        TokenSwapSyrup::deposit<PoolTypeSyrup,STAR::STAR>(account,disp_token);
    }

    //Amount to get linear treasury
    public fun get_balance_of_linear_treasury<PoolType: store>():u128 acquires GovTreasuryV2{
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());    
        Token::value<STAR::STAR>(&treasury.linear_treasury)
    }
    //Get the total number of locks in the linear treasury
    public fun get_total_of_linear_treasury<PoolType: store>():u128 acquires GovTreasuryV2{
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());    
        treasury.linear_total
    }
    //Get the lockup start time of the linear treasury
    public fun get_start_of_linear_treasury<PoolType: store>():u64 acquires GovTreasuryV2{
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());    
        treasury.locked_start_timestamp
    }
    //Get the total duration of the linear treasury lock
    public fun get_hodl_of_linear_treasury<PoolType: store>():u64 acquires GovTreasuryV2{
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());    
        treasury.locked_total_timestamp
    }
    //Get the amount you can withdraw from the linear treasury
    public fun get_can_withdraw_of_linear_treasury<PoolType: store>():u128 acquires GovTreasuryV2{
        let treasury = borrow_global<GovTreasuryV2<PoolType>>(STAR::token_address());
        let now_timestamp = Timestamp::now_seconds();

        if (now_timestamp >= (treasury.locked_start_timestamp + treasury.locked_total_timestamp)){
            return Token::value<STAR::STAR>(&treasury.linear_treasury)
        };
        let second_release =  treasury.linear_total / (treasury.locked_total_timestamp as u128);

        let amount = (( now_timestamp - treasury.locked_start_timestamp  ) as u128) * second_release;
        if(Token::value<STAR::STAR>(&treasury.linear_treasury) < (treasury.linear_total - amount)){
            0
        }else {
            Token::value<STAR::STAR>(&treasury.linear_treasury) - (treasury.linear_total - amount)
        }
    }

    #[test]
    public fun test_get_can_withdraw_of_linear_treasury(){
        let precision = STAR::precision();
        let scaling_factor = Math::pow(10, (precision as u64));
        let total = calculate_amount_from_percent(GOV_PERCENT_FARM - GOV_PERCENT_FARM_GENESIS ) * (scaling_factor as u128) - 1263196461020203;

        let second_release =  total / (GOV_PERCENT_FARM_LOCK_TIME as u128);

        Debug::print(&second_release);
    }

    #[test]
    public fun test_aptos_genesis(){
        let scaling_factor = Math::pow(10, 9);

        let farm_gensis = 5 * 1000 * 1000 * scaling_factor;
        let now_farm_treasury = 9722241185776728;
        let now_treasury_farm = 37895893830618610;
        let farm_total = 60 * 1000 * 1000 * scaling_factor;


        let farm_supply_star = farm_total - now_farm_treasury - now_treasury_farm ;
        let (burn_farm_treasury_amount, burn_treasury_farm_amount) = if(farm_supply_star > farm_gensis){
                            let burn_farm_treasury_amount = now_farm_treasury / 3;
                            let burn_treasury_farm_amount = now_treasury_farm / 3;
                            (burn_farm_treasury_amount, burn_treasury_farm_amount)
                        }else {
                            let supply_farm_treasury_gensis = farm_gensis - farm_supply_star ;
                            let farm_treasury = now_farm_treasury - supply_farm_treasury_gensis;
                            let burn_farm_treasury_amount = farm_treasury / 3;
                            let burn_treasury_farm_amount = now_treasury_farm / 3;
                            (burn_farm_treasury_amount, burn_treasury_farm_amount)
                        };
        Debug::print(&(farm_supply_star > farm_gensis));
        Debug::print(&burn_farm_treasury_amount);
        Debug::print(&burn_treasury_farm_amount);
        Debug::print(&(burn_farm_treasury_amount + burn_treasury_farm_amount));



        let stake_gensis = 5 * 1000 * 1000 * scaling_factor;
        let now_stake_treasury = 8088860717238387;
        let now_treasury_stake = 1897181968767854;
        let stake_total = 10 * 1000 * 1000 * scaling_factor;

        let stake_supply_star = stake_total - now_stake_treasury - now_treasury_stake ;
        let (burn_stake_treasury_amount, burn_treasury_stake_amount) = if(stake_supply_star > stake_gensis){
            let burn_stake_treasury_amount = now_stake_treasury / 3;
            let burn_treasury_stake_amount = now_treasury_stake / 3;
            (burn_stake_treasury_amount, burn_treasury_stake_amount)
        }else {
            let stake_treasury_gensis = stake_gensis - stake_supply_star ;
            let stake_treasury = now_stake_treasury - stake_treasury_gensis;
            let burn_stake_treasury_amount = stake_treasury / 3;
            let burn_treasury_stake_amount = now_treasury_stake / 3;
            (burn_stake_treasury_amount, burn_treasury_stake_amount)
        };

        Debug::print(&(stake_supply_star > stake_gensis));
        Debug::print(&burn_stake_treasury_amount);
        Debug::print(&burn_treasury_stake_amount);
        Debug::print(&(burn_stake_treasury_amount + burn_treasury_stake_amount));
    }

    /// Get balance of treasury
    public fun get_balance_of_treasury<PoolType: store>(): u128 acquires GovTreasuryV2 {
        let treasury = borrow_global_mut<GovTreasuryV2<PoolType>>(STAR::token_address());
        Token::value<STAR::STAR>(&treasury.genesis_treasury)
    }


    fun calculate_amount_from_percent(percent: u64): u128 {
        let per: u128 = 100;
        ((GOV_TOTAL / per)) * (percent as u128)
    }

    public fun get_circulating_supply():u128 acquires GovTreasuryV2{
        let total = Token::market_cap<STAR::STAR>();

        total - get_balance_of_linear_treasury<PoolTypeCommunity>()
              - get_balance_of_treasury<PoolTypeCommunity>()
              - get_balance_of_linear_treasury<PoolTypeFarmPool>()
              - get_balance_of_linear_treasury<PoolTypeSyrup>()
              - TokenSwapFarm::get_treasury_balance<PoolTypeFarmPool,STAR::STAR>()
              - TokenSwapSyrup::get_treasury_balance<PoolTypeSyrup,STAR::STAR>()
              - get_balance_of_treasury<PoolTypeIDO>()
              - get_balance_of_linear_treasury<PoolTypeProtocolTreasury>()
              - get_balance_of_treasury<PoolTypeProtocolTreasury>()
              - get_balance_of_linear_treasury<PoolTypeDeveloperFund>()
              - get_balance_of_treasury<PoolTypeDeveloperFund>()
    }


    public fun upgrade_dao_treasury_genesis_func(signer: &signer) {
        STAR::assert_genesis_address(signer);
        //upgrade dao treasury genesis can only be execute once
        if (!exists<GovTreasury<PoolTypeProtocolTreasury>>(Signer::address_of(signer))) {
            let precision = STAR::precision();
            let scaling_factor = Math::pow(10, (precision as u64));
            let now_timestamp = Timestamp::now_seconds();

            //  Release 24% for dao treasury. genesis release 2%.
            let dao_treasury_genesis =
                calculate_amount_from_percent(GOV_PERCENT_PROTOCOL_TREASURY_GENESIS) * (scaling_factor as u128);
            STAR::mint(signer, dao_treasury_genesis);
            move_to(signer, GovTreasury<PoolTypeProtocolTreasury> {
                treasury: Account::withdraw<STAR::STAR>(signer, dao_treasury_genesis),
                locked_start_timestamp: now_timestamp,
                locked_total_timestamp: 0,
            });
        };
    }


    /// DEPRECATED
    public entry fun upgrade_dao_treasury_genesis(_signer: signer) {
        abort Errors::invalid_state(ERR_DEPRECATED)
    }

    // fun upgrade_pool_type<PoolTypeOld: store, PoolTypeNew: store>(signer: &signer) acquires GovTreasury {
    //     STAR::assert_genesis_address(signer);
    //     let account = Signer::address_of(signer);
    //
    //     let GovTreasury<PoolTypeOld> {
    //         treasury,
    //         locked_start_timestamp,
    //         locked_total_timestamp,
    //     } = move_from<GovTreasury<PoolTypeOld>>(account);
    //     move_to(signer, GovTreasury<PoolTypeNew> {
    //         treasury,
    //         locked_start_timestamp,
    //         locked_total_timestamp,
    //     });
    // }

    public entry fun upgrade_pool_type_genesis(signer: signer) {
        STAR::assert_genesis_address(&signer);
    }

    public fun aptos_genesis_burn(signer: &signer, farm_burn_amount:u128, sryup_burn_amount:u128) acquires  GovTreasuryV2,GovTreasuryMultiChainEvent{
        STAR::assert_genesis_address(signer);
        let precision = STAR::precision();
        let scaling_factor = Math::pow(10, (precision as u64));

        if(!exists<GovTreasuryMultiChainEvent>(address_of(signer))){
            move_to(signer, GovTreasuryMultiChainEvent{
                burn_linearGovTreasury_event_handler:Event::new_event_handle<LinearGovTreasuryMultiBurnEvent>(signer)
            });
        };

        let event = &mut borrow_global_mut<GovTreasuryMultiChainEvent>(address_of(signer)).burn_linearGovTreasury_event_handler;
        let farm_treasury = borrow_global_mut<GovTreasuryV2<PoolTypeFarmPool>>(STAR::token_address());
        assert!(farm_treasury.linear_total == calculate_amount_from_percent(GOV_PERCENT_FARM - GOV_PERCENT_FARM_GENESIS ) * (scaling_factor as u128) , 100);
        let farm_treasury_amount = Token::value(&farm_treasury.linear_treasury);
        let farm_treasury_burn = Token::withdraw(&mut farm_treasury.linear_treasury, farm_burn_amount);
        Event::emit_event(event, LinearGovTreasuryMultiBurnEvent{
            amount: farm_burn_amount,
            chain: b"Aptos_Multi_Genesis_Farm",
            treasury_type:Token::token_code<PoolTypeFarmPool>()
        });

        Token::burn(signer, farm_treasury_burn);
        farm_treasury.linear_total = farm_treasury.linear_total - ( farm_treasury_amount / 3 );

        let syrup_treasury = borrow_global_mut<GovTreasuryV2<PoolTypeSyrup>>(STAR::token_address());
        assert!(syrup_treasury.linear_total == calculate_amount_from_percent(GOV_PERCENT_SYRUP - GOV_PERCENT_SYRUP_GENESIS ) * (scaling_factor as u128) , 100);
        let syrup_treasury_amount = Token::value(&syrup_treasury.linear_treasury);
        let syrup_treasury_burn = Token::withdraw(&mut syrup_treasury.linear_treasury, sryup_burn_amount);
        Event::emit_event(event, LinearGovTreasuryMultiBurnEvent{
            amount: sryup_burn_amount,
            chain: b"Aptos_Multi_Genesis_Syrup",
            treasury_type:Token::token_code<PoolTypeSyrup>()
        });
        Token::burn(signer, syrup_treasury_burn);
        syrup_treasury.linear_total = syrup_treasury.linear_total - ( syrup_treasury_amount / 3) ;
    }
    public fun aptos_genesis_burn_community(signer: &signer, community_burn_amount:u128) acquires GovTreasuryV2, GovTreasuryMultiChainEvent {
        STAR::assert_genesis_address(signer);
        let scaling_factor = Math::pow(10, (STAR::precision() as u64));

        if(!exists<GovTreasuryMultiChainEvent>(address_of(signer))){
            move_to(signer, GovTreasuryMultiChainEvent{
                burn_linearGovTreasury_event_handler:Event::new_event_handle<LinearGovTreasuryMultiBurnEvent>(signer)
            });
        };

        let event = &mut borrow_global_mut<GovTreasuryMultiChainEvent>(address_of(signer)).burn_linearGovTreasury_event_handler;
        let community_treasury = borrow_global_mut<GovTreasuryV2<PoolTypeCommunity>>(STAR::token_address());
        assert!(community_treasury.linear_total == calculate_amount_from_percent(GOV_PERCENT_COMMUNITY - GOV_PERCENT_COMMUNITY_GENESIS ) * (scaling_factor as u128) , 100);
        let community_treasury_amount = Token::value(&community_treasury.linear_treasury);
        let community_treasury_burn = Token::withdraw(&mut community_treasury.linear_treasury, community_burn_amount);
        Event::emit_event(event, LinearGovTreasuryMultiBurnEvent{
            amount: community_treasury_amount,
            chain: b"Aptos_Multi_Genesis_Communtiy",
            treasury_type:Token::token_code<PoolTypeFarmPool>()
        });
        Token::burn(signer, community_treasury_burn);
        community_treasury.linear_total = community_treasury.linear_total - community_burn_amount ;
    }
}
}