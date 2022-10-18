// token holder address, not admin address
module SwapAdmin::TokenMock {
    use aptos_framework::coin::{Self, Coin};
    use aptos_std::type_info;
    use std::string;

    use SwapAdmin::WrapperUtil;

    struct TokenSharedCapability<phantom CoinType> has key, store {
        mint: coin::MintCapability<CoinType>,
        burn: coin::BurnCapability<CoinType>,
        freeze: coin::FreezeCapability<CoinType>,
    }

    // mock ETH token
    struct WETH has copy, drop, store {}

    // mock USDT token
    struct WUSDT has copy, drop, store {}

    // mock DAI token
    struct WDAI has copy, drop, store {}

    // mock BTC token
    struct WBTC has copy, drop, store {}

    // mock DOT token
    struct WDOT has copy, drop, store {}


    public fun register_token<CoinType: store>(account: &signer, precision: u8){
        let token_type_info = type_info::type_of<CoinType>();
        let token_symbol = type_info::struct_name(&token_type_info);
        let token_name = string::utf8(copy token_symbol);
        string::append_utf8(&mut token_name, b" Coin");

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<CoinType>(
            account,
            token_name,
            string::utf8(token_symbol),
            precision,
            true,
        );
        coin::register<CoinType>(account);

        move_to(account, TokenSharedCapability { mint: mint_cap, burn: burn_cap, freeze: freeze_cap });
    }

    public fun mint_token<CoinType: store>(amount: u128): Coin<CoinType> acquires TokenSharedCapability{
        //token holder address
        let cap = borrow_global<TokenSharedCapability<CoinType>>(WrapperUtil::coin_address<CoinType>());
        coin::mint<CoinType>((amount as u64), &cap.mint)
    }

    public fun burn_token<CoinType: store>(tokens: Coin<CoinType>) acquires TokenSharedCapability{
        //token holder address
        let cap = borrow_global<TokenSharedCapability<CoinType>>(WrapperUtil::coin_address<CoinType>());
        coin::burn<CoinType>(tokens, &cap.burn, );
    }
}
