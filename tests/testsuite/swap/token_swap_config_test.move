//! account: alice, 10000000000000 0x1::STC::STC
//! account: joe
//! account: admin, 0x4783d08fb16990bd35d83f3e23bf93b8, 10000000000000 0x1::STC::STC
//! account: liquidier, 10000000000000 0x1::STC::STC
//! account: exchanger


//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapConfig;

    fun init_token_config(signer: signer) {
        TokenSwapConfig::set_swap_fee_operation_rate(&signer, 20, 100);
        let (num, denum) = TokenSwapConfig::get_swap_fee_operation_rate();
        assert(num == 20, 1001);
        assert(denum == 100, 1002);
    }
}
// check: EXECUTED