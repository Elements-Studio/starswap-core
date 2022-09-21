// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module SwapAdmin::TokenSwapGovScript {

    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFee;

    /// Initial as genesis that will create pool list by Starswap Ecnomic Model list
    public entry fun genesis_initialize(account: signer) {
        TokenSwapGov::genesis_initialize(&account);
        TokenSwapFee::initialize_token_swap_fee(&account);
    }

    /// Harverst STAR by given pool type, call ed by user
    public entry fun dispatch<PoolType: store>(account: signer, acceptor: address, amount: u128) {
        TokenSwapGov::dispatch<PoolType>(&account, acceptor, amount);
    }

    ///Initialize the linear treasury by Starswap Ecnomic Model list
    public entry fun linear_initialize(account: signer) {
        TokenSwapGov::linear_initialize(&account);
    }

//    /// Linear extraction of Farm treasury
//    public entry fun linear_withdraw_farm(account: signer , amount:u128 ) {
//        TokenSwapGov::linear_withdraw_farm(&account , amount);
//    }
//
//    /// Linear extraction of Syrup treasury
//    public entry fun linear_withdraw_syrup(account: signer , amount:u128 ) {
//        TokenSwapGov::linear_withdraw_syrup(&account , amount);
//    }

    /// Linear extraction of Community treasury
    public entry fun linear_withdraw_community(account: signer ,to:address,amount :u128) {
        TokenSwapGov::linear_withdraw_community(&account, to, amount);
    }
    
    /// Linear extraction of developerfund treasury
    public entry fun linear_withdraw_developerfund(account: signer ,to:address,amount :u128) {
        TokenSwapGov::linear_withdraw_developerfund(&account, to, amount);
    }
}