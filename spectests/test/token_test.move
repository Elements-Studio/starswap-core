//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice



//# run --signers alice

script {
    use StarcoinFramework::Debug;
    use SwapAdmin::TokenMock::WUSDT;
    use StarcoinFramework::STC::STC;
    use SwapAdmin::TokenSwap;

    fun main(_signer: signer) {
        let ret = TokenSwap::compare_token<STC, WUSDT>();
        Debug::print<u8>(&ret);
        assert(ret == 1, 10000);
    }
}
// check: EXECUTED
