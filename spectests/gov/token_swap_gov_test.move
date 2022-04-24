//# init -n test --public-keys SwapAdmin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000

//# faucet --addr farm_test --amount 10000000000000000

//# faucet --addr syrup_test --amount 10000000000000000

//# faucet --addr community_test --amount 10000000000000000

//# faucet --addr developerfund_test --amount 10000000000000000

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

//# run --signers SwapAdmin

script {
    use SwapAdmin::TokenSwapGov;

    fun upgrade_dao_treasury_genesis(signer: signer) {
        TokenSwapGov::upgrade_dao_treasury_genesis(signer);
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

    use SwapAdmin::TokenSwapGov;

    fun linear_initialize(signer: signer) {
        TokenSwapGov::linear_initialize(&signer);
    }
}
// check: EXECUTED

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





//# block --author 0x1 --timestamp 1646449200000 

//# run --signers alice
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeFarmPool
    };
    //Attempt to extract at first hour
    fun linear_withdraw_farm(signer: signer) {

        let can_withdraw = TokenSwapGov::get_can_withdraw_of_linear_treasury<PoolTypeFarmPool>();
        assert!( can_withdraw == 3139269404400, 1001);
        let second_release = TokenSwapGov::get_total_of_linear_treasury<PoolTypeFarmPool>() / 
                                ( TokenSwapGov::get_hodl_of_linear_treasury<PoolTypeFarmPool>() as u128);
        
        let hour_release = (1646449200 - 1646445600) * second_release;
        TokenSwapGov::linear_withdraw_farm(&signer);
        
        let balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeFarmPool>();

        assert!( second_release  == 872019279                        ,1002);
        assert!( hour_release    == 3139269404400                    ,1003);
        assert!( balance         == 55000000000000000 - hour_release ,1004); 
    }
}
// check: EXECUTED

//# run --signers alice
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeSyrup
    };
    //Attempt to extract at first hour
    fun linear_withdraw_syrup(signer: signer) {

        let can_withdraw = TokenSwapGov::get_can_withdraw_of_linear_treasury<PoolTypeSyrup>();
        assert!( can_withdraw == 570776252400, 1001);
        let second_release = TokenSwapGov::get_total_of_linear_treasury<PoolTypeSyrup>() / 
                                ( TokenSwapGov::get_hodl_of_linear_treasury<PoolTypeSyrup>() as u128);
        
        let hour_release = (1646449200 - 1646445600) * second_release;
        TokenSwapGov::linear_withdraw_syrup(&signer);
        
        let balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeSyrup>();

        assert!( second_release  == 158548959                        ,1002);
        assert!( hour_release    == 570776252400                     ,1003);
        assert!( balance         == 5000000000000000 - hour_release  ,1004); 
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeCommunity
    };
    use StarcoinFramework::Account;
    use SwapAdmin::STAR;
    //Attempt to extract at first hour
    fun linear_withdraw_community(signer: signer) {

        let can_withdraw = TokenSwapGov::get_can_withdraw_of_linear_treasury<PoolTypeCommunity>();
        assert!( can_withdraw == 171232873200, 1008);
        let second_release = TokenSwapGov::get_total_of_linear_treasury<PoolTypeCommunity>() / 
                                ( TokenSwapGov::get_hodl_of_linear_treasury<PoolTypeCommunity>() as u128);
        
        let hour_release = (1646449200 - 1646445600) * second_release;
        TokenSwapGov::linear_withdraw_community(&signer,@community_test,hour_release);
        let amount = Account::balance<STAR::STAR>(@community_test);
        let balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeCommunity>();
        assert!( second_release  == 47564687                        ,1004);
        assert!( hour_release    == 171232873200                    ,1005);
        assert!( amount          == hour_release                    ,1006);
        assert!( balance         == 3000000000000000 - hour_release   ,1007); 

    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeDeveloperFund
    };
    use StarcoinFramework::Account;
    use SwapAdmin::STAR;
    //Attempt to extract at first hour
    fun linear_withdraw_developerfund(signer: signer) {

        let can_withdraw = TokenSwapGov::get_can_withdraw_of_linear_treasury<PoolTypeDeveloperFund>();
        assert!( can_withdraw == 570776252400, 1008);
        let second_release = TokenSwapGov::get_total_of_linear_treasury<PoolTypeDeveloperFund>() / 
                                ( TokenSwapGov::get_hodl_of_linear_treasury<PoolTypeDeveloperFund>() as u128);
        
        let hour_release = (1646449200 - 1646445600) * second_release;
        TokenSwapGov::linear_withdraw_developerfund(&signer,@developerfund_test,hour_release);
        let amount = Account::balance<STAR::STAR>(@developerfund_test);
        let balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeDeveloperFund>();

        assert!( second_release  == 158548959                          ,1004);
        assert!( hour_release    == 570776252400                       ,1005);
        assert!( amount          == hour_release                       ,1006);
        assert!( balance         == 10000000000000000 - hour_release   ,1007); 
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;

    //Try extracting again
    fun linear_withdraw_farm(signer: signer) {
        TokenSwapGov::linear_withdraw_farm(&signer);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeCommunity
    };
    //Try extracting again
    fun linear_withdraw_community(signer: signer) {
        let second_release = TokenSwapGov::get_total_of_linear_treasury<PoolTypeCommunity>() / 
                                ( TokenSwapGov::get_hodl_of_linear_treasury<PoolTypeCommunity>() as u128);
        
        let hour_release = (1646449200 - 1646445600) * second_release;
        TokenSwapGov::linear_withdraw_community(&signer,@community_test,hour_release);
    }
}
// check: MoveAbort 51719
 
//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    //try to extract 0
    fun linear_withdraw_farm(signer: signer) {
        TokenSwapGov::linear_withdraw_farm(&signer);
    }
}
// check: MoveAbort 51719

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    //try to extract 0
    fun linear_withdraw_community(signer: signer) {
        TokenSwapGov::linear_withdraw_community(&signer,@community_test,0);
    }
}
// check: MoveAbort 51719

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeFarmPool
    };
    //Determine whether the amount that can be extracted is 0
    fun linear_withdraw_farm(_signer: signer) {
        let can_withdraw = TokenSwapGov::get_can_withdraw_of_linear_treasury<PoolTypeFarmPool>();
        assert!( can_withdraw == 0, 1009);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeCommunity
    };
    //Determine whether the amount that can be extracted is 0
    fun linear_withdraw_community(_signer: signer) {
        let can_withdraw = TokenSwapGov::get_can_withdraw_of_linear_treasury<PoolTypeCommunity>();
        assert!( can_withdraw == 0, 1009);
    }
}
// check: EXECUTED

//# block --author 0x1 --timestamp 1709517600000

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeFarmPool
    };
    //When the time happens to be the end of the lock
    //See how much you can withdraw
    fun linear_withdraw_farm(_signer: signer) {
        let can_withdraw = TokenSwapGov::get_can_withdraw_of_linear_treasury<PoolTypeFarmPool>();
        assert!( can_withdraw == 55000000000000000 -  3139269404400 , 1010);
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeCommunity
    };
    //When the time happens to be the end of the lock
    //See how much you can withdraw
    fun linear_withdraw_community(_signer: signer) {
        let can_withdraw = TokenSwapGov::get_can_withdraw_of_linear_treasury<PoolTypeCommunity>();
        assert!( can_withdraw == 3000000000000000 -  171232873200 , 1010);
    }
}
// check: EXECUTED


//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeFarmPool
    };
    //when the maximum time is exceeded
    fun linear_withdraw_farm(signer: signer) {
        let balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeFarmPool>();
        assert!(balance == 54996860730595600 ,1011 );
        TokenSwapGov::linear_withdraw_farm(&signer);

        let balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeFarmPool>();
        assert!(balance == 0 ,1011 );
    }
}
// check: EXECUTED

//# run --signers SwapAdmin
script {
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeCommunity
    };
    //When the maximum time is exceeded, all are taken out
    fun linear_withdraw_community(signer: signer) {
        TokenSwapGov::linear_withdraw_community(&signer,@community_test,171232873200 * 2);
        let balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeCommunity>();
        assert!(balance == 3000000000000000 -  171232873200 * 3 ,1011 );
    }
}
// check: EXECUTED




//# block --author 0x1 --timestamp 1709521200000 

//# run --signers SwapAdmin
script {
    use StarcoinFramework::Account;
    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapGovPoolType::{
        PoolTypeCommunity
    };
    //When the maximum time is exceeded, all are taken out
    fun linear_withdraw_farm(signer: signer) {
        let balance = TokenSwapGov::get_balance_of_linear_treasury<PoolTypeCommunity>();
        let can_withdraw = TokenSwapGov::get_can_withdraw_of_linear_treasury<PoolTypeCommunity>();
        assert!(can_withdraw == balance, 1012);
        assert!(can_withdraw == (3000000000000000 -  171232873200 * 3), 1012);
        TokenSwapGov::linear_withdraw_community(&signer,@community_test,can_withdraw);
        let amount = Account::balance<STAR::STAR>(@community_test);
        assert!(amount == 3000000000000000, 1013);
    }
}
// check: EXECUTED
