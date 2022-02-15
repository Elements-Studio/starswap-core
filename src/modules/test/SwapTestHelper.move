address 0x8c109349c6bd91411d6bc962e080c4a3 {
module SwapTestHelper {
    use 0x1::Token;
    use 0x1::Account;
    use 0x1::STC::STC ;

    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapRouter;
    use 0xb6d69dd935edf7f2054acf12eb884df8::XUSDT::XUSDT;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenMock::{WETH, WUSDT, WDAI, WBTC};


    const PRECISION_9: u8 = 9;
    const PRECISION_18: u8 = 18;
    //    const GENESIS_ADDRESS : address = @0x4fe7BBbFcd97987b966415F01995a229;
    const TOKEN_HOLDER_ADDRESS : address = @0x8c109349c6bd91411d6bc962e080c4a3;
    const ADMIN_ADDRESS : address = @0x8c109349c6bd91411d6bc962e080c4a3;
    const XUSDT_ADDRESS : address = @0xb6d69dd935edf7f2054acf12eb884df8;
    const FEE_ADDRESS : address = @0x9572abb16f9d9e9b009cc1751727129e;

    public fun get_admin_address(): address {
        ADMIN_ADDRESS
    }

    public fun get_token_holder_address(): address {
        TOKEN_HOLDER_ADDRESS
    }

    public fun get_xusdt_address(): address {
        XUSDT_ADDRESS
    }

    public fun get_fee_address(): address {
        FEE_ADDRESS
    }

    public fun init_token_pairs_register(account: &signer){
        TokenSwapRouter::register_swap_pair<WETH, WUSDT>(account);
        assert(TokenSwapRouter::swap_pair_exists<WETH, WUSDT>(), 111);

        TokenSwapRouter::register_swap_pair<WUSDT, WDAI>(account);
        assert(TokenSwapRouter::swap_pair_exists<WUSDT, WDAI>(), 112);

        TokenSwapRouter::register_swap_pair<WDAI, WBTC>(account);
        assert(TokenSwapRouter::swap_pair_exists<WDAI, WBTC>(), 113);

        TokenSwapRouter::register_swap_pair<STC, WETH>(account);
        assert(TokenSwapRouter::swap_pair_exists<STC, WETH>(), 114);

        TokenSwapRouter::register_swap_pair<WBTC, WETH>(account);
        assert(TokenSwapRouter::swap_pair_exists<WBTC, WETH>(), 115);

        TokenSwapRouter::register_swap_pair<STC, XUSDT>(account);
        assert(TokenSwapRouter::swap_pair_exists<STC, XUSDT>(), 116);

        TokenSwapRouter::register_swap_pair<WETH, XUSDT>(account);
        assert(TokenSwapRouter::swap_pair_exists<WETH, XUSDT>(), 117);
    }

    public fun init_token_pairs_liquidity(account: &signer) {
        TokenSwapRouter::add_liquidity<WETH, WUSDT>(account, 5000, 100000, 100, 100);
        TokenSwapRouter::add_liquidity<WUSDT, WDAI>(account, 20000, 30000, 100, 100);
        TokenSwapRouter::add_liquidity<WDAI, WBTC>(account, 100000, 4000, 100, 100);
        TokenSwapRouter::add_liquidity<STC, WETH>(account, 200000, 10000, 100, 100);
        TokenSwapRouter::add_liquidity<WETH, WBTC>(account, 60000, 5000, 100, 100);
        TokenSwapRouter::add_liquidity<STC, XUSDT>(account, 160000, 5000, 100, 100);
        TokenSwapRouter::add_liquidity<WETH, XUSDT>(account, 6000, 20000, 100, 100);
    }

    public fun init_fee_token(account: &signer) {
        Token::register_token<XUSDT>(account, PRECISION_9);
        Account::do_accept_token<XUSDT>(account);
        let token = Token::mint<XUSDT>(account, 5000000u128);
        Account::deposit_to_self(account, token);
    }

}
}