//! account: alice, 10000000000000 0x1::STC::STC
//! account: joe
//! account: admin, 0x2b3d5bd6d0f8a957e6a4abe986056ba7, 10000000000000 0x1::STC::STC
//! account: liquidier, 10000000000000 0x1::STC::STC
//! account: exchanger


//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapConfig;

    fun init_token_config(_: signer) {
        let (num, denum) = TokenSwapConfig::get_swap_fee_operation_rate();
        assert(num == 10, 1001);
        assert(denum == 60, 1002);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapConfig;

    fun set_token_config(signer: signer) {
        TokenSwapConfig::set_swap_fee_operation_rate(&signer, 20, 100);
        let (num, denum) = TokenSwapConfig::get_swap_fee_operation_rate();
        assert(num == 20, 1003);
        assert(denum == 100, 1003);
    }
}
// check: EXECUTED