//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000


//# block --author 0x1 --timestamp 1639010000000

//# run --signers alice

script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Timestamp;

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


//# block --author 0x1 --timestamp 1639020000000

//# run --signers alice
script {
    use StarcoinFramework::Debug;
    use StarcoinFramework::Timestamp;

    fun oralce_info(_: signer) {
        let timestamp = Timestamp::now_seconds();
        Debug::print<u128>(&110102);
        Debug::print(&timestamp);
    }
}
// check: EXECUTED

