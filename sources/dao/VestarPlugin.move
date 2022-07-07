address SwapAdmin {

module VestarPlugin {

    use StarcoinFramework::GenesisDao;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Errors;

    use SwapAdmin::VESTAR::VESTAR;
    use SwapAdmin::VToken;
    use SwapAdmin::StarswapDao::StarswapDao;

    struct VestarPlugin has store, drop {}

    const ERR_PLUGIN_USER_IS_MEMBER: u64 = 1001;

    public fun required_caps(): vector<GenesisDao::CapType> {
        let caps = Vector::singleton(GenesisDao::proposal_cap_type());
        Vector::push_back(&mut caps, GenesisDao::member_cap_type());
        caps
    }

    public fun register(member: address) {
        assert!(!GenesisDao::is_member<StarswapDao>(member), Errors::invalid_state(ERR_PLUGIN_USER_IS_MEMBER));

        let witness = VestarPlugin {};
        let cap =
            GenesisDao::acquire_member_cap<StarswapDao, VestarPlugin>(&witness);
        GenesisDao::join_member<StarswapDao, VestarPlugin>(&cap, member, 0);
    }

    public fun increase_sbt(member: address, token: &VToken::VToken<VESTAR>) {
        let witness = VestarPlugin {};
        let cap =
            GenesisDao::acquire_member_cap<StarswapDao, VestarPlugin>(&witness);
        GenesisDao::increase_member_sbt<StarswapDao, VestarPlugin>(&cap, member, VToken::value(token));
    }

    public fun decrease_sbt(member: address, token: &VToken::VToken<VESTAR>) {
        let witness = VestarPlugin {};
        let cap =
            GenesisDao::acquire_member_cap<StarswapDao, VestarPlugin>(&witness);
        GenesisDao::decrease_member_sbt<StarswapDao, VestarPlugin>(&cap, member, VToken::value(token));
    }
}
}

