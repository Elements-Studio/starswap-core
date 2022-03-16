//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 10000000

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapGov;

    fun genesis_initialized(signer: signer) {
        TokenSwapGov::genesis_initialize(&signer);
    }
}
// check: EXECUTED


////# run --signers admin
//script {
//    use SwapAdmin::TokenSwapGov;
//    use SwapAdmin::CommonHelper;
//    use SwapAdmin::STAR;
//
//    fun upgrade_v2_to_v3_for_syrup_on_testnet(signer: signer) {
//        let total_amount = CommonHelper::pow_amount<STAR::STAR>(1000000);
//        TokenSwapGov::upgrade_v2_to_v3_for_syrup_on_testnet(signer, total_amount);
//    }
//}
//// check: Keep(ABORTED { code: 25857


//# block --author 0x1 --timestamp 10001000

//# run --signers alice
script {
    use SwapAdmin::STAR;
    use StarcoinFramework::Account;

    fun swap_admin_accept_STAR(signer: signer) {
        Account::do_accept_token<STAR::STAR>(&signer);
    }
}

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeIDO,
        PoolTypeCommunity,
    };

    fun dispatch_to_other_account(signer: signer) {
        TokenSwapGov::dispatch<PoolTypeIDO>(&signer, @alice, 10000000);
        TokenSwapGov::dispatch<PoolTypeCommunity>(&signer, @alice, 20000000);

        let balance = Account::balance<STAR::STAR>(@alice);
        assert!(balance == 30000000, 1003);
    }
}
// check: EXECUTED
