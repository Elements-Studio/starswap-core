//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice

//# faucet --addr joe

//# faucet --addr liquidier

//# faucet --addr exchanger

//# faucet --addr SwapAdmin


//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapConfig;

    fun init_token_config(_: signer) {
        let (num, denum) = TokenSwapConfig::get_swap_fee_operation_rate();
        assert!(num == 10, 1001);
        assert!(denum == 60, 1002);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapConfig;

    fun set_token_config(signer: signer) {
        TokenSwapConfig::set_swap_fee_operation_rate(&signer, 20, 100);
        let (num, denum) = TokenSwapConfig::get_swap_fee_operation_rate();
        assert!(num == 20, 1003);
        assert!(denum == 100, 1003);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapConfig;

    fun init_swap_fee_switch_config(_: signer) {
        let auto_convert_switch = TokenSwapConfig::get_fee_auto_convert_switch();
        assert!(auto_convert_switch == false, 1006);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapConfig;

    fun set_swap_fee_switch_config(signer: signer) {
        TokenSwapConfig::set_fee_auto_convert_switch(&signer, true);
        let auto_convert_switch = TokenSwapConfig::get_fee_auto_convert_switch();
        assert!(auto_convert_switch == true, 1007);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapConfig;

    fun test_set_global_freeze_switch(signer: signer) {
        TokenSwapConfig::set_global_freeze_switch(&signer, true);
        assert!(TokenSwapConfig::get_global_freeze_switch() == true, 1008);
    }
}
// check: EXECUTED

