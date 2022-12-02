module SwapAdmin::MultiChain {
    use StarcoinFramework::Event::{Self, new_event_handle};
    use StarcoinFramework::Signer::address_of;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::Token;
    use SwapAdmin::STAR::{Self, STAR};
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeFarmPool, PoolTypeSyrup, PoolTypeCommunity};
    use SwapAdmin::TokenSwapSyrup;

    #[test_only]
    use StarcoinFramework::Debug;
    use StarcoinFramework::Math;

    const START_TIME: u64 = 1646445600;

    const MILLION: u128 = 100 * 10000 ;

    const ERR_APTOS_GENESISED: u64 = 1;

    struct MultiChainEvent has key, store {
        event: Event::EventHandle<GenesisEvent>
    }

    struct GenesisEvent has drop, store {
        chain: vector<u8>,
        token_code: Token::TokenCode,
        amount: u128
    }

    public fun genesis_aptos_burn(sender: &signer)acquires MultiChainEvent {
        STAR::assert_genesis_address(sender);
        assert!(TokenSwapGov::get_total_of_linear_treasury<PoolTypeFarmPool>() == 55000000000000000, ERR_APTOS_GENESISED);

        if (!exists<MultiChainEvent>(address_of(sender))) {
            move_to(sender, MultiChainEvent {
                event: new_event_handle<GenesisEvent>(sender)
            })
        };

        let (farm_treasury_burn_amount, farm_linear_burn_amount, syrup_treasury_burn_amount, syrup_linear_burn_amount) = calculate_genesis_aptos_burn_amount();

        let farm_burn_token = TokenSwapFarm::withdraw<PoolTypeFarmPool, STAR>(sender, farm_treasury_burn_amount);

        let syrup_burn_token = TokenSwapSyrup::withdraw<PoolTypeSyrup, STAR>(sender, syrup_treasury_burn_amount);

        Token::burn(sender, farm_burn_token);

        Token::burn(sender, syrup_burn_token);

        TokenSwapGov::aptos_genesis_burn(sender, farm_linear_burn_amount, syrup_linear_burn_amount);

        let event = &mut borrow_global_mut<MultiChainEvent>(address_of(sender)).event;

        Event::emit_event(event, GenesisEvent {
            chain: b"Aptos_Multi_genesis",
            token_code: Token::token_code<STAR>(),
            amount: farm_treasury_burn_amount + farm_linear_burn_amount + syrup_treasury_burn_amount + syrup_linear_burn_amount
        });
    }

    public fun genesis_aptos_burn_community(sender: &signer)acquires MultiChainEvent{
        STAR::assert_genesis_address(sender);
        assert!(TokenSwapGov::get_total_of_linear_treasury<PoolTypeCommunity>() == 3000000000000000, ERR_APTOS_GENESISED);
        if (!exists<MultiChainEvent>(address_of(sender))) {
            move_to(sender, MultiChainEvent {
                event: new_event_handle<GenesisEvent>(sender)
            })
        };

        let scaling_factor = Math::pow(10, (STAR::precision() as u64));

        let burn_amount = MILLION * scaling_factor;
        TokenSwapGov::aptos_genesis_burn_community(sender, burn_amount);
        let event = &mut borrow_global_mut<MultiChainEvent>(address_of(sender)).event;

        Event::emit_event(event, GenesisEvent {
            chain: b"Aptos_Multi_genesis_Community",
            token_code: Token::token_code<STAR>(),
            amount: burn_amount
        });
    }

    public fun calculate_genesis_aptos_burn_amount(): (u128, u128, u128, u128) {
        let now = Timestamp::now_seconds();
        let farm_total = 100000000 * 60 / 100 * 1000 * 1000 * 1000 ;
        let farm_treasury_balance = TokenSwapFarm::get_treasury_balance<PoolTypeFarmPool, STAR>();
        let farm_linear_balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeFarmPool>();

        let (farm_treasury_burn_amount, farm_linear_burn_amount) = aptos_genesis_farm_treasury_burn_amount(farm_total, farm_treasury_balance, farm_linear_balance, now);


        let syrup_total = 100000000 * 10 / 100 * 1000 * 1000 * 1000 ;
        let syrup_treasury_balance = TokenSwapSyrup::get_treasury_balance<PoolTypeSyrup, STAR>();
        let syrup_linear_balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeSyrup>();
        let (syrup_treasury_burn_amount, syrup_linear_burn_amount) = aptos_genesis_sryup_treasury_burn_amount(syrup_total, syrup_treasury_balance, syrup_linear_balance, now);


        (farm_treasury_burn_amount, farm_linear_burn_amount, syrup_treasury_burn_amount, syrup_linear_burn_amount)
    }


    public fun aptos_genesis_farm_treasury_burn_amount(total: u128, treasury: u128, linear_treasury: u128, now: u64): (u128, u128) {
        let supply_star = total - treasury - linear_treasury ;
        let should_supply_star = 800000000 * ((now - START_TIME) as u128);

        assert!(should_supply_star >= supply_star, 100);

        let not_withdraw_star = should_supply_star - supply_star;
        let not_release_amount = treasury - not_withdraw_star ;
        StarcoinFramework::Debug::print(&treasury);
        return (not_release_amount / 3, linear_treasury / 3)
    }

    public fun aptos_genesis_sryup_treasury_burn_amount(total: u128, treasury: u128, linear_treasury: u128, now: u64): (u128, u128) {
        let supply_star = total - treasury - linear_treasury ;
        let should_supply_star = 2000000 * ((1665557289 - START_TIME) as u128);
        should_supply_star = should_supply_star + (23000000 * ((now - 1665557289) as u128));

        assert!(should_supply_star >= supply_star, 100);
        //38,223,378,000,000
        let not_withdraw_star = should_supply_star - supply_star;

        let not_release_amount = treasury - not_withdraw_star ;

        return (not_release_amount / 3, linear_treasury / 3)
    }

    #[test]
    fun test_genesis_aptos_burn() {
        let now = 1666084255;

        let farm_total = 100000000 * 60 / 100 * 1000 * 1000 * 1000 ;
        let farm_treasury_balance = 9712257480616680;
        let farm_linear_balance = 37878058420305220;

        let (farm_treasury_burn_amount, farm_linear_burn_amount) = aptos_genesis_farm_treasury_burn_amount(farm_total, farm_treasury_balance, farm_linear_balance, now);
        Debug::print(&farm_treasury_burn_amount);
        Debug::print(&farm_linear_burn_amount);
        Debug::print(&(farm_treasury_burn_amount + farm_linear_burn_amount));


        let syrup_total = 100000000 * 10 / 100 * 1000 * 1000 * 1000 ;
        let syrup_treasury_balance = 8098050572405495;
        let syrup_linear_balance = 1887712949289497;
        let (syrup_treasury_burn_amount, syrup_linear_burn_amount) = aptos_genesis_sryup_treasury_burn_amount(syrup_total, syrup_treasury_balance, syrup_linear_balance, now);
        Debug::print(&syrup_treasury_burn_amount);
        Debug::print(&syrup_linear_burn_amount);
        Debug::print(&(syrup_treasury_burn_amount + syrup_linear_burn_amount));
    }
}
