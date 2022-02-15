address 0x2b3d5bd6d0f8a957e6a4abe986056ba7 {
module SwapRouterTest {
    #[test_only]
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapRouter3;
    //    #[test_only]
    //    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapRouter;
    #[test_only]
    use 0x1::STC::STC;
    #[test_only]
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::{WETH, WUSDT, WDAI};
    #[test_only]
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TestHelper;
    #[test_only]
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::CommonHelper;
    #[test_only]
    use 0x1::Signer;
    #[test_only] use 0x1::Debug;

    #[test(sender = @0x5f1288f6687eb8ba746081641bc4342e)]
    public fun test_swap_exact_token_for_token_router3(sender: signer) {
        TestHelper::before_test();
        TestHelper::init_account_with_stc(&sender, 20000000);

        let amount_x_in = 50000;
        let amount_y_out_min = 10;
        let token_balance_before = CommonHelper::get_safe_balance<WDAI>(Signer::address_of(&sender));
        assert(token_balance_before == 0, 201);

        let (r_out, t_out, expected_token_balance) = TokenSwapRouter3::get_amount_out<STC, WETH, WUSDT, WDAI>(amount_x_in);
        TokenSwapRouter3::swap_exact_token_for_token<STC, WETH, WUSDT, WDAI>(&sender, amount_x_in, amount_y_out_min);

        //         TokenSwapRouter::swap_exact_token_for_token<STC, WETH>(&sender, amount_x_in, r_out);
        //         TokenSwapRouter::swap_exact_token_for_token<WETH, WUSDT>(&sender, r_out, t_out);
        //         TokenSwapRouter::swap_exact_token_for_token<WUSDT, WDAI>(&sender, t_out, amount_y_out_min);

        let token_balance_end = CommonHelper::get_safe_balance<WDAI>(Signer::address_of(&sender));
        Debug::print<u128>(&r_out);
        Debug::print<u128>(&t_out);
        Debug::print<u128>(&token_balance_before);
        Debug::print<u128>(&token_balance_end);

        Debug::print<u128>(&amount_y_out_min);
        Debug::print<u128>(&expected_token_balance);
        //        assert(token_balance == expected_token_balance, (token_balance as u64));
        //        assert(token_balance >= amount_y_out_min, (token_balance as u64));
    }


}
}