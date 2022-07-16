address SwapAdmin {

module VestarPlugin {

    use StarcoinFramework::GenesisDao;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Errors;
    use StarcoinFramework::IdentifierNFT;

    use SwapAdmin::VESTAR::VESTAR;
    use SwapAdmin::VToken;

    friend SwapAdmin::TokenSwapSBTMapping;


    struct VestarPlugin has store, drop {}

    const ERR_PLUGIN_USER_IS_MEMBER: u64 = 1001;

    public fun required_caps(): vector<GenesisDao::CapType> {
        let caps = Vector::singleton(GenesisDao::proposal_cap_type());
        Vector::push_back(&mut caps, GenesisDao::member_cap_type());
        caps
    }

    public fun accept_sbt<DaoT: store>(signer: &signer) {
        IdentifierNFT::accept<GenesisDao::DaoMember<DaoT>, GenesisDao::DaoMemberBody<DaoT>>(signer);
    }

    public fun join_member<DaoT: store>(member: address) {
        assert!(!GenesisDao::is_member<DaoT>(member), Errors::invalid_state(ERR_PLUGIN_USER_IS_MEMBER));

        let witness = VestarPlugin {};
        let cap =
            GenesisDao::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        GenesisDao::join_member<DaoT, VestarPlugin>(&cap, member, 0);
    }

    public fun increase_sbt<DaoT: store>(member: address, token: &VToken::VToken<VESTAR>) {
        let witness = VestarPlugin {};
        let cap =
            GenesisDao::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        GenesisDao::increase_member_sbt<DaoT, VestarPlugin>(&cap, member, VToken::value(token));
    }

    public fun decrease_sbt<DaoT: store>(member: address, token: &VToken::VToken<VESTAR>) {
        let witness = VestarPlugin {};
        let cap =
            GenesisDao::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        GenesisDao::decrease_member_sbt<DaoT, VestarPlugin>(&cap, member, VToken::value(token));
    }

    public(friend) fun increase_sbt_value<DaoT: store>(member: address, amount: u128) {
        let witness = VestarPlugin {};
        let cap =
            GenesisDao::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        GenesisDao::increase_member_sbt<DaoT, VestarPlugin>(&cap, member, amount);
    }

    public(friend) fun decrease_sbt_value<DaoT: store>(member: address, amount: u128) {
        let witness = VestarPlugin {};
        let cap =
            GenesisDao::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        GenesisDao::decrease_member_sbt<DaoT, VestarPlugin>(&cap, member, amount);
    }
}
}

