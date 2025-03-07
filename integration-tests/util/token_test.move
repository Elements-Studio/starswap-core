//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000


//# run --signers alice

script {
    use std::debug;

    use starcoin_framework::starcoin_coin::STC;
    use swap_admin::STAR::STAR;
    use swap_admin::TokenSwap;

    fun main(_signer: signer) {
        let ret = TokenSwap::compare_token<STC, STAR>();
        debug::print<u8>(&ret);
        assert!(ret == 2, 10000);
    }
}
// check: EXECUTED
