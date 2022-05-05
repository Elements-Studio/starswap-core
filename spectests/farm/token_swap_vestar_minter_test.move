//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# publish
module alice::VestarHoster {
    use StarcoinFramework::Signer;
    //use StarcoinFramework::Debug;

    use SwapAdmin::VToken;
    use SwapAdmin::VESTAR;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapVestarMinter;

    struct CapabilityWrapper has key, store {
        mint_cap: TokenSwapVestarMinter::MintCapability,
        treasury_cap: TokenSwapVestarMinter::TreasuryCapability,
        id: u64,
    }

    public fun init(signer: &signer) {
        let (
            mint_cap,
            treasury_cap
        ) = TokenSwapVestarMinter::init(signer);
        move_to(signer, CapabilityWrapper{
            mint_cap,
            treasury_cap,
            id: 0
        });
    }

    public fun mint<TokenT: store>(signer: &signer, pledge_time_sec: u64, staked_amount: u128) acquires CapabilityWrapper {
        let cap = borrow_global_mut<CapabilityWrapper>(@SwapAdmin);
        cap.id = cap.id + 1;
        TokenSwapVestarMinter::mint_with_cap<STAR::STAR>(signer, cap.id, pledge_time_sec, staked_amount, &cap.mint_cap);
    }

    public fun burn<TokenT: store>(signer: &signer) acquires CapabilityWrapper {
        let cap = borrow_global_mut<CapabilityWrapper>(@SwapAdmin);
        TokenSwapVestarMinter::burn_with_cap<TokenT>(signer, cap.id, &cap.mint_cap);
    }

    public fun get_amount_of_treasury(signer: &signer): u128 {
        TokenSwapVestarMinter::value(Signer::address_of(signer))
    }

    public fun deposit(signer: &signer, t: VToken::VToken<VESTAR::VESTAR>) acquires CapabilityWrapper {
        let cap = borrow_global_mut<CapabilityWrapper>(@SwapAdmin);
        TokenSwapVestarMinter::deposit_with_cap(signer, t, &cap.treasury_cap);
    }

    public fun withdraw(signer: &signer, amount: u128): VToken::VToken<VESTAR::VESTAR> acquires CapabilityWrapper {
        let cap = borrow_global_mut<CapabilityWrapper>(@SwapAdmin);
        TokenSwapVestarMinter::withdraw_with_cap(signer, amount, &cap.treasury_cap)
    }
}

//# run --signers SwapAdmin
script {
    use alice::VestarHoster;

    fun vestar_initialize(signer: signer) {
        VestarHoster::init(&signer);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use alice::VestarHoster;
    use SwapAdmin::STAR;

    use StarcoinFramework::Debug;

    fun vestar_mint(signer: signer) {
        let perday = 60 * 60 * 24;
        VestarHoster::mint<STAR::STAR>(&signer, 7 * perday, 1000000);
        Debug::print(&VestarHoster::get_amount_of_treasury(&signer));
        assert!(VestarHoster::get_amount_of_treasury(&signer) > 0, 10001);
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use alice::VestarHoster;

    use SwapAdmin::VToken;
    use SwapAdmin::VESTAR;

    fun vestar_withdraw_test(signer: signer) {
        let vestar = VestarHoster::withdraw(&signer, 100);
        assert!(VToken::value<VESTAR::VESTAR>(&vestar) == 100, 10002);

        VestarHoster::deposit(&signer, vestar);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use alice::VestarHoster;
    use SwapAdmin::STAR;

    fun vestar_burn(signer: signer) {
        // let perday = 60 * 60 * 24;
        VestarHoster::burn<STAR::STAR>(&signer);
        assert!(VestarHoster::get_amount_of_treasury(&signer) <= 0, 10003);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use StarcoinFramework::Debug;

    use SwapAdmin::Boost;
    use SwapAdmin::STAR;

    use alice::VestarHoster;

    fun vestar_mint_and_burn_2(signer: signer) {
        VestarHoster::mint<STAR::STAR>(&signer, 3600, 100000000000);
        VestarHoster::mint<STAR::STAR>(&signer, 3600, 100000000000);
        let treasury_amount = VestarHoster::get_amount_of_treasury(&signer);
        Debug::print(&treasury_amount);

        let compute_amount = Boost::compute_mint_amount(3600, 100000000000);
        assert!(compute_amount * 2 == treasury_amount, 10004);

        VestarHoster::burn<STAR::STAR>(&signer);
        assert!(VestarHoster::get_amount_of_treasury(&signer) == compute_amount, 10005);
    }
}
// check: EXECUTED