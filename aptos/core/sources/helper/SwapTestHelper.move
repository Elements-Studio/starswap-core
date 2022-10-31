module SwapAdmin::SwapTestHelper {
    use std::signer;

    use aptos_framework::aptos_coin::AptosCoin as APT;
    use aptos_framework::coin;

    use UsdtIssuer::XUSDT::XUSDT;

    use SwapAdmin::TokenMock::{Self, WETH, WUSDT, WDAI, WBTC};
    use SwapAdmin::TokenSwapRouter;

    const PRECISION_9: u8 = 9;
    const PRECISION_18: u8 = 18;
    const TOKEN_HOLDER_ADDRESS: address = @SwapAdmin;
    const ADMIN_ADDRESS: address = @SwapAdmin;
    const XUSDT_ADDRESS: address = @UsdtIssuer;
    const FEE_ADDRESS: address = @SwapFeeAdmin;

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

    public fun init_token_pairs_register(account: &signer) {
        TokenSwapRouter::register_swap_pair<WETH, WUSDT>(account);
        assert!(TokenSwapRouter::swap_pair_exists<WETH, WUSDT>(), 111);

        TokenSwapRouter::register_swap_pair<WUSDT, WDAI>(account);
        assert!(TokenSwapRouter::swap_pair_exists<WUSDT, WDAI>(), 112);

        TokenSwapRouter::register_swap_pair<WDAI, WBTC>(account);
        assert!(TokenSwapRouter::swap_pair_exists<WDAI, WBTC>(), 113);

        TokenSwapRouter::register_swap_pair<APT, WETH>(account);
        assert!(TokenSwapRouter::swap_pair_exists<APT, WETH>(), 114);

        TokenSwapRouter::register_swap_pair<WBTC, WETH>(account);
        assert!(TokenSwapRouter::swap_pair_exists<WBTC, WETH>(), 115);

        TokenSwapRouter::register_swap_pair<APT, XUSDT>(account);
        assert!(TokenSwapRouter::swap_pair_exists<APT, XUSDT>(), 116);

        TokenSwapRouter::register_swap_pair<WETH, XUSDT>(account);
        assert!(TokenSwapRouter::swap_pair_exists<WETH, XUSDT>(), 117);
    }

    public fun init_token_pairs_liquidity(account: &signer) {
        TokenSwapRouter::add_liquidity<WETH, WUSDT>(account, 5000, 100000, 100, 100);
        TokenSwapRouter::add_liquidity<WUSDT, WDAI>(account, 20000, 30000, 100, 100);
        TokenSwapRouter::add_liquidity<WDAI, WBTC>(account, 100000, 4000, 100, 100);
        TokenSwapRouter::add_liquidity<APT, WETH>(account, 200000, 10000, 100, 100);
        TokenSwapRouter::add_liquidity<WETH, WBTC>(account, 60000, 5000, 100, 100);
        TokenSwapRouter::add_liquidity<APT, XUSDT>(account, 160000, 5000, 100, 100);
        TokenSwapRouter::add_liquidity<WETH, XUSDT>(account, 6000, 20000, 100, 100);
    }

    public fun init_fee_token(account: &signer) {
        TokenMock::register_token<XUSDT>(account, PRECISION_9);
        let token = TokenMock::mint_token<XUSDT>(5000000u128);
        coin::deposit(signer::address_of(account), token);
    }
}