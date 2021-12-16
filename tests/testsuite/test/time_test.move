//! account: alice, 500000 0x1::STC::STC

//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 1639010000000

//! new-transaction
//! sender: alice
script {
    use 0x1::Debug;
    use 0x1::Timestamp;

    fun oralce_info(_: signer) {
        let timestamp = Timestamp::now_seconds();
        let block_time = Timestamp::now_seconds() % (1u64 << 32);
        Debug::print<u128>(&110101);
        Debug::print(&timestamp);
        Debug::print(&block_time);
        Debug::print(&(1u64 << 32));
    }
}
// check: EXECUTED


//! block-prologue
//! author: genesis
//! block-number: 2
//! block-time: 1639020000000

//! new-transaction
//! sender: alice
script {
    use 0x1::Debug;
    use 0x1::Timestamp;

    fun oralce_info(_: signer) {
        let timestamp = Timestamp::now_seconds();
        Debug::print<u128>(&110102);
        Debug::print(&timestamp);
    }
}
// check: EXECUTED

