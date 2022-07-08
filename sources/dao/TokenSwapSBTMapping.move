address SwapAdmin {
module TokenSwapSBTMapping {

    use SwapAdmin::VToken;
    use SwapAdmin::VESTAR;
    use StarcoinFramework::Signer;
    use SwapAdmin::VestarPlugin;
    use SwapAdmin::TokenSwapDao;

    friend SwapAdmin::TokenSwapVestarMinter;
    friend SwapAdmin::TokenSwapFarmBoost;

    struct TreasuryMapFlag has key {
        amount: u128,
    }

    struct FarmMapFlag<phantom X, phantom Y> has key {
        amount: u128
    }

    public(friend) fun maybe_map_in_farming<X: store, Y: store>(sender: &signer,
                                                                token: &VToken::VToken<VESTAR::VESTAR>) {
        let user_addr = Signer::address_of(sender);
        if (exists<FarmMapFlag<X, Y>>(user_addr)) {
            return
        };
        let amount = VToken::value(token);
        move_to(sender, FarmMapFlag<X, Y> {
            amount
        });
        VestarPlugin::increase_sbt<TokenSwapDao::TokenSwapDao>(user_addr, token);
    }

    public(friend) fun maybe_map_in_treasury(sender: &signer,
                                             token: &VToken::VToken<VESTAR::VESTAR>) : bool {
        let user_addr = Signer::address_of(sender);
        if (exists<TreasuryMapFlag>(user_addr)) {
            return false
        };
        let amount = VToken::value(token);
        move_to(sender, TreasuryMapFlag {
            amount
        });
        VestarPlugin::increase_sbt<TokenSwapDao::TokenSwapDao>(user_addr, token);
        true
    }

    public(friend) fun increase(user_addr: address, amount: u128) {
        VestarPlugin::increase_sbt_value<TokenSwapDao::TokenSwapDao>(user_addr, amount);
    }

    public(friend) fun decrease(user_addr: address, amount: u128) {
        VestarPlugin::decrease_sbt_value<TokenSwapDao::TokenSwapDao>(user_addr, amount);
    }

    public fun has_treasury_flag(user_addr: address): bool {
        exists<TreasuryMapFlag>(user_addr)
    }

    public fun has_farm_flag<X, Y>(user_addr: address): bool {
        exists<FarmMapFlag<X, Y>>(user_addr)
    }
}
}
