script {
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;

    use SwapAdmin::STAR;
    use SwapAdmin::TokenSwapGovPoolType::{PoolTypeFarmPool, PoolTypeSyrup};
    use SwapAdmin::TokenSwapSyrup;
    use SwapAdmin::TokenSwapFarm;
    use SwapAdmin::TokenSwapGov;

    fun incremental_bounds(swap_admin: signer, withdraw_amount: u128, farm_amount: u128, syrup_amount: u128) {
        let swap_admin_addr = Signer::address_of(&swap_admin);
        assert!(swap_admin_addr == @SwapAdmin, 1);
        assert!(withdraw_amount == (farm_amount + syrup_amount), 2);

        TokenSwapGov::linear_withdraw_developerfund(
            &swap_admin,
            swap_admin_addr,
            withdraw_amount
        );

        TokenSwapFarm::deposit<PoolTypeFarmPool, STAR::STAR>(
            &swap_admin,
            Account::withdraw<STAR::STAR>(&swap_admin, farm_amount)
        );
        TokenSwapSyrup::deposit<PoolTypeSyrup, STAR::STAR>(
            &swap_admin,
            Account::withdraw<STAR::STAR>(&swap_admin, syrup_amount)
        );
    }
}