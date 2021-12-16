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
        PoolTypeTeam,
        PoolTypeInvestor,
        PoolTypeTechMaintenance,
        PoolTypeMarket,
        PoolTypeStockManagement,
        PoolTypeDaoCrosshain,
    };

    fun main(signer: signer) {
        TokenSwapGov::dispatch<PoolTypeTeam>(&signer, @alice, 100000000);
        TokenSwapGov::dispatch<PoolTypeInvestor>(&signer, @alice, 100000000);
        TokenSwapGov::dispatch<PoolTypeTechMaintenance>(&signer, @alice, 100000000);
        TokenSwapGov::dispatch<PoolTypeMarket>(&signer, @alice, 100000000);
        TokenSwapGov::dispatch<PoolTypeStockManagement>(&signer, @alice, 100000000);
        TokenSwapGov::dispatch<PoolTypeDaoCrosshain>(&signer, @alice, 100000000);

        let balance = Account::balance<STAR::STAR>(@alice);
        assert(balance == 600000000, 1003);
    }
}
// check: EXECUTED
