// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapGovScript {

    use SwapAdmin::TokenSwapGov;
    use SwapAdmin::TokenSwapFee;

    /// Initial as genesis that will create pool list by Starswap Ecnomic Model list
    public(script) fun genesis_initialize(account: signer) {
        TokenSwapGov::genesis_initialize(&account);
        TokenSwapFee::initialize_token_swap_fee(&account);
    }

    /// Harverst STAR by given pool type, call ed by user
    public(script) fun dispatch<PoolType: store>(account: signer, acceptor: address, amount: u128) {
        TokenSwapGov::dispatch<PoolType>(&account, acceptor, amount);
    }

}
}