//! account: alice, 10000000000000 0x1::STC::STC
//! account: bob, 10000000000000 0x1::STC::STC
//! account: admin, 0x4783d08fb16990bd35d83f3e23bf93b8, 10000000000000 0x1::STC::STC
//! account: liquidier, 10000000000000 0x1::STC::STC
//! account: exchanger


//! new-transaction
//! sender: admin
address admin = {{admin}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGov;

    fun main(signer: signer) {
        TokenSwapGov::genesis_initialize(&signer);
    }
}
// check: EXECUTED


////! new-transaction
////! sender: admin
//address admin = {{admin}};
//script {
//    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGov;
//    use 0x4783d08fb16990bd35d83f3e23bf93b8::CommonHelper;
//    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;
//
//    fun upgrade_v2_to_v3_for_syrup_on_testnet(signer: signer) {
//        let total_amount = CommonHelper::pow_amount<STAR::STAR>(1000000);
//        TokenSwapGov::upgrade_v2_to_v3_for_syrup_on_testnet(signer, total_amount);
//    }
//}
//// check: Keep(ABORTED { code: 25857


//! block-prologue
//! author: genesis
//! block-number: 1
//! block-time: 86410000

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;
    use 0x1::Account;

    fun main(signer: signer) {
        Account::do_accept_token<STAR::STAR>(&signer);
    }
}

//! new-transaction
//! sender: admin
address admin = {{admin}};
address alice = {{alice}};
script {
    use 0x1::Account;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::STAR;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGov;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovPoolType::{
        PoolTypeInitialLiquidity,
        PoolTypeCommunity,
    };

    fun main(signer: signer) {
        TokenSwapGov::dispatch<PoolTypeInitialLiquidity>(&signer, @alice, 10000000);
        TokenSwapGov::dispatch<PoolTypeCommunity>(&signer, @alice, 20000000);

        let balance = Account::balance<STAR::STAR>(@alice);
        assert(balance == 30000000, 1003);
    }
}
// check: EXECUTED
