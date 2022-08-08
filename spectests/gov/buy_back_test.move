//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5 --public-keys BuyBackAccount=0x760670dd3a152f7130534758d366eea7540078832e0985cde498c40c9a2b6ae3 --addresses BuyBackAccount=0xa1869437e19a33eba1b7277218af539c

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# faucet --addr BuyBackAccount --amount 10000000000000000

//# block --author 0x1 --timestamp 86400000

//# publish
module BuyBackAccount::BuyBackPoolType {
    struct BuyBackPoolType has store {}
}

//# run --signers SwapAdmin
script {
    use StarcoinFramework::STC::STC;

    use SwapAdmin::TokenMock::{Self, WUSDT};
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenSwap;

    fun init_token(signer: signer) {
        let scale_index: u8 = 9;
        TokenMock::register_token<WUSDT>(&signer, scale_index);

        CommonHelper::safe_mint<WUSDT>(&signer, CommonHelper::pow_amount<WUSDT>(1000000));

        // Register swap pair
        TokenSwap::register_swap_pair<STC, WUSDT>(&signer);

        assert!(TokenSwap::swap_pair_exists<STC, WUSDT>(), 111);
    }
}
// check: EXECUTED


//# run --signers alice
script {
    use SwapAdmin::CommonHelper;
    use SwapAdmin::TokenMock::WUSDT;

    fun alice_accept_wusdt(signer: signer) {
        CommonHelper::safe_accept_token<WUSDT>(&signer);
    }
}

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::CommonHelper;

    fun transfer_to_alice(signer: signer) {
        CommonHelper::transfer<WUSDT>(
            &signer,
            @alice,
            CommonHelper::pow_amount<WUSDT>(5000)
        );
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Math;
    use StarcoinFramework::STC::STC;

    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::TokenSwapRouter;
    use StarcoinFramework::Debug;

    fun add_liquidity_and_swap(signer: signer) {
        let precision: u8 = 9; //STC precision is also 9.
        let scaling_factor = Math::pow(10, (precision as u64));
        // STC/WUSDT = 1:5
        //let stc_amount: u128 = 10000 * scaling_factor;

        ////////////////////////////////////////////////////////////////////////////////////////////
        // Add liquidity, STC/WUSDT = 1:5
        let amount_stc_desired: u128 = 10 * scaling_factor;
        let amount_usdt_desired: u128 = 50 * scaling_factor;
        let amount_stc_min: u128 = 1 * scaling_factor;
        let amount_usdt_min: u128 = 1 * scaling_factor;

        TokenSwapRouter::add_liquidity<STC, WUSDT>(
            &signer,
            amount_stc_desired,
            amount_usdt_desired,
            amount_stc_min,
            amount_usdt_min
        );

        let total_liquidity: u128 = TokenSwapRouter::total_liquidity<STC, WUSDT>();
        assert!(total_liquidity > amount_stc_min, 10000);

        let stc_balance = Account::balance<STC>(Signer::address_of(&signer));
        Debug::print(&stc_balance);
    }
}
// check: EXECUTED

//# run --signers BuyBackAccount
script {
    use StarcoinFramework::STC::STC;

    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::CommonHelper;
    use SwapAdmin::BuyBack;

    fun init_payback(signer: signer) {
        BuyBack::init_event(&signer);
        BuyBack::accept<BuyBackAccount::BuyBackPoolType::BuyBackPoolType, WUSDT, STC>(
            &signer,
            CommonHelper::pow_amount<STC>(100),
            86400,
            10,
            CommonHelper::pow_amount<STC>(1),
        );
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 86410000

//# run --signers alice
script {
    use StarcoinFramework::STC::STC;

    use SwapAdmin::TokenMock::{WUSDT};
    use SwapAdmin::BuyBack;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Debug;
    use StarcoinFramework::Token;

    fun do_payback(sender: signer) {
        let token = BuyBack::buy_back<
            BuyBackAccount::BuyBackPoolType::BuyBackPoolType,
            WUSDT,
            STC
        >(&sender, @BuyBackAccount, 100);

        let receiver = Signer::address_of(&sender);
        Debug::print(&Token::value<STC>(&token));
        Debug::print(&Account::balance<WUSDT>(@alice));
        Account::deposit<STC>(receiver, token);
    }
}
// check: EXECUTED