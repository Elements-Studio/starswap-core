//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# block --author 0x1 --timestamp 1639010000000

//# run --signers alice

script {
    use std::debug;

    use starcoin_framework::timestamp;

    fun oralce_info(_: signer) {
        let timestamp = timestamp::now_seconds();
        let block_time = timestamp::now_seconds() % (1u64 << 32);
        debug::print<u128>(&110101);
        debug::print(&timestamp);
        debug::print(&block_time);
        debug::print(&(1u64 << 32));
    }
}
// check: EXECUTED


//# block --author 0x1 --timestamp 1639020000000

//# run --signers alice
script {
    use std::debug;

    use starcoin_framework::timestamp;

    fun oralce_info(_: signer) {
        let timestamp = timestamp::now_seconds();
        debug::print<u128>(&110102);
        debug::print(&timestamp);
    }
}
// check: EXECUTED

