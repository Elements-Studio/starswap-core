// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module TokenSwapGovScript {

    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGov;
    use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFee;

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