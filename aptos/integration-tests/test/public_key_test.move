//# init -n test --public-keys A1=0xcb511db2ed694d8c25fbe797fbcc6f961a634c9b44464cf34e2f73973cbc6cca --public-keys A2=0x10360620c85c3252df0a765d88173051eb61981094ee78c9e07df87e340791b7 --public-keys  A3=0x16e53fe78fcdbad85607a3eb3abd33c4f6f6fe7cdbc4bd1e43ec0fdac73f30dd

////# init -n test --public-keys A1=0xcb511db2ed694d8c25fbe797fbcc6f961a634c9b44464cf34e2f73973cbc6cca A2=0x10360620c85c3252df0a765d88173051eb61981094ee78c9e07df87e340791b7  --addresses A3=0xc9c2ddf0c7501352ff135c6d99a21169SwapFee A3=0x16e53fe78fcdbad85607a3eb3abd33c4f6f6fe7cdbc4bd1e43ec0fdac73f30dd
////# init -n test --addresses A1=0x8a25c80bfa4a16a9bf294b9817857030 A2=0x616bf31c8a27c0ffd6b2cd6ff094077e  A3=0xc9c2ddf0c7501352ff135c6d99a21169


//# faucet --addr A1 --amount 10000000000000000

//# faucet --addr A2 --amount 10000000000000000

//# faucet --addr A3 --amount 10000000000000000

//# run --signers A1
script {
//    use StarcoinFramework::Debug;

    fun test(_signer: signer) {
        let a1_address = @0x8a25c80bfa4a16a9bf294b9817857030;
        let a3_address = @0xc9c2ddf0c7501352ff135c6d99a21169;
        assert!(a1_address != @A1, 1001);
        assert!(a3_address != @A3, 1002);
//        Debug::print(&@A3);
    }
}
// check: EXECUTED
