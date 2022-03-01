address SwapAdmin {
module TestHelper {
    use StarcoinFramework::Token;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::STC::STC ;
    use StarcoinFramework::Timestamp;
    use StarcoinFramework::NFT;
    use StarcoinFramework::ChainId;
    use StarcoinFramework::Oracle;
    use StarcoinFramework::CoreAddresses;

    use SwapAdmin::SwapTestHelper;
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock::{Self, WETH, WUSDT, WDAI, WBTC};
    use Bridge::XUSDT::XUSDT;
    use SwapAdmin::TokenSwapFee;

    struct GenesisSignerCapability has key {
        cap: Account::SignerCapability,
    }

    const PRECISION_9: u8 = 9;
    const PRECISION_18: u8 = 18;

    public fun before_test() acquires GenesisSignerCapability {
        let stdlib = Account::create_genesis_account(CoreAddresses::GENESIS_ADDRESS());
        Timestamp::initialize(&stdlib, 1631244104193u64);
        Token::register_token<STC>(&stdlib, PRECISION_9);
        ChainId::initialize(&stdlib, 254);

        Oracle::initialize(&stdlib);
        NFT::initialize(&stdlib);

        let cap = Account::remove_signer_capability( &stdlib);
        let genesis_cap = GenesisSignerCapability { cap: cap };
        move_to( &stdlib, genesis_cap);

        let admin_signer = Account::create_genesis_account(SwapTestHelper::get_admin_address());
//        let token_holder_signer = Account::create_genesis_account(SwapTestHelper::get_token_holder_address());
        let xusdt_signer = Account::create_genesis_account(SwapTestHelper::get_xusdt_address());
        let fee_signer = Account::create_genesis_account(SwapTestHelper::get_fee_address());

        // init swap pool

        init_tokens(&admin_signer);
        SwapTestHelper::init_fee_token(&xusdt_signer);
        init_admin_account(&admin_signer, &xusdt_signer);
        SwapTestHelper::init_token_pairs_register(&admin_signer);
        SwapTestHelper::init_token_pairs_liquidity(&admin_signer);
        TokenSwapFee::initialize_token_swap_fee(&admin_signer);
        CommonHelper::safe_accept_token<XUSDT>(&fee_signer);
    }


    fun genesis_signer(): signer acquires GenesisSignerCapability {
        let genesis_cap = borrow_global<GenesisSignerCapability>(CoreAddresses::GENESIS_ADDRESS());
        Account::create_signer_with_cap(&genesis_cap.cap)
    }

    public fun init_tokens(account: &signer){
        TokenMock::register_token<WETH>(account, PRECISION_18);
        TokenMock::register_token<WUSDT>(account, PRECISION_18);
        TokenMock::register_token<WDAI>(account, PRECISION_18);
        TokenMock::register_token<WBTC>(account, PRECISION_18);

        CommonHelper::safe_mint<WETH>(account, 1000000);
        CommonHelper::safe_mint<WUSDT>(account, 1000000);
        CommonHelper::safe_mint<WDAI>(account, 1000000);
        CommonHelper::safe_mint<WBTC>(account, 1000000);
    }

    public fun init_admin_account(admin_account: &signer, xusdt_signer: &signer) acquires GenesisSignerCapability{
        init_account_with_stc(admin_account, 1000000u128);
        //3rd lib dependency by xusdt
        CommonHelper::safe_accept_token<XUSDT>(admin_account);
        CommonHelper::transfer<XUSDT>(xusdt_signer, Signer::address_of(admin_account), 1000000);
    }

    public fun init_account_with_stc(account: &signer, amount: u128) acquires GenesisSignerCapability {
        let account_address = Signer::address_of(account);
        if (account_address != SwapTestHelper::get_admin_address()) {
            Account::create_genesis_account(account_address);
        };

        if (amount > 0) {
            deposit_stc_to(account, amount);
            let stc_balance = Account::balance<STC>(account_address);
            assert(stc_balance == amount, 999);
        };
    }

    public fun deposit_stc_to(account: &signer, amount: u128) acquires GenesisSignerCapability {
        let is_accept_token = Account::is_accepts_token<STC>(Signer::address_of(account));
        if (!is_accept_token) {
            Account::do_accept_token<STC>(account);
        };
        let stc_token = Token::mint<STC>(&genesis_signer(), amount);
        Account::deposit<STC>(Signer::address_of(account), stc_token);
    }

    public fun mint_stc_to(amount: u128): Token::Token<STC> acquires GenesisSignerCapability {
        Token::mint<STC>(&genesis_signer(), amount)
    }

    public fun set_timestamp(time: u64) acquires GenesisSignerCapability {
        let genesis_cap = borrow_global<GenesisSignerCapability>(CoreAddresses::GENESIS_ADDRESS());
        let genesis_account = Account::create_signer_with_cap(&genesis_cap.cap);
        Timestamp::update_global_time(&genesis_account, time);
    }
}
}