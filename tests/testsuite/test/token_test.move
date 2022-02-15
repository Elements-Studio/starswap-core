//! account: alice, 50000 0x1::STC::STC
//! account: admin


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Debug;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenMock::WUSDT;
    use 0x1::STC::STC;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwap;

    fun main(_signer: signer) {
        let ret = TokenSwap::compare_token<STC, WUSDT>();
        Debug::print<u8>(&ret);
        assert(ret == 1, 10000);
    }
}
// check: EXECUTED
