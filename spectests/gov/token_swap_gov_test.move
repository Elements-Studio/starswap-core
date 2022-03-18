//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr farm_test --amount 10000000000000000

//# faucet --addr SwapAdmin --amount 10000000000000000

//# block --author 0x1 --timestamp 1646445600

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


//# block --author 0x1 --timestamp 1646446600000 

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



//# run --signers SwapAdmin
script {

    use SwapAdmin::TokenSwapGov;

    fun linear_initialize(signer: signer) {
        TokenSwapGov::linear_initialize(&signer);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 1646449200000 

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeFarmPool
    };

    fun linear_withdraw_farm(signer: signer) {
        TokenSwapGov::linear_withdraw_farm(&signer,@farm_test,3139269404400);
        let balance = Account::balance<STAR::STAR>(@farm_test);
        assert!(balance == 3139269404400,1004);
        assert!(TokenSwapGov::get_balance_of_treasury<PoolTypeFarmPool>() == 54996860730595600,1005);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 1646460000000 


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;

    fun linear_withdraw_farm(signer: signer) {
        TokenSwapGov::linear_withdraw_farm(&signer,@farm_test,3139269404400 * 4);
        }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeFarmPool
    };

    fun linear_withdraw_farm(signer: signer) {
        TokenSwapGov::linear_withdraw_farm(&signer,@farm_test,3139269404400 * 3);
        let balance = Account::balance<STAR::STAR>(@farm_test);
        assert!(balance == 3139269404400 * 4,1006);
        assert!(TokenSwapGov::get_balance_of_treasury<PoolTypeFarmPool>() == (54996860730595600 - (3139269404400 * 3)),1007);
    }
}
// check: EXECUTED


//# block --author 0x1 --timestamp 1709521200000 

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::STAR;

    fun linear_withdraw_farm(signer: signer) {
        TokenSwapGov::linear_withdraw_farm(&signer,@farm_test,54987442922382400);
        let balance = Account::balance<STAR::STAR>(@farm_test);
        assert!(balance == 55000000000000000,1008);
    }
}
// check: EXECUTED