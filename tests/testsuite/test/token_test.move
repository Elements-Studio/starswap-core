//! account: alice, 50000 0x1::STC::STC
//! account: admin


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Debug;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenMock::WUSDT;
    use 0x1::STC::STC;
    use 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwap;

    fun main(_signer: signer) {
        let ret = TokenSwap::compare_token<STC, WUSDT>();
        Debug::print<u8>(&ret);
        assert(ret == 1, 10000);
    }
}
// check: EXECUTED
