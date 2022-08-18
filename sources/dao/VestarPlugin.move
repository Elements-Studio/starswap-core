address SwapAdmin {

module VestarPlugin {

    use StarcoinFramework::DAOSpace;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Errors;
    use StarcoinFramework::IdentifierNFT;

    use SwapAdmin::VESTAR::VESTAR;
    use SwapAdmin::VToken;

    friend SwapAdmin::TokenSwapSBTMapping;


    struct VestarPlugin has store, drop {}

    const ERR_PLUGIN_USER_IS_MEMBER: u64 = 1001;

    public fun required_caps(): vector<DAOSpace::CapType> {
        let caps = Vector::singleton(DAOSpace::proposal_cap_type());
        Vector::push_back(&mut caps, DAOSpace::member_cap_type());
        caps
    }

    public fun accept_sbt<DaoT: store>(signer: &signer) {
        IdentifierNFT::accept<DAOSpace::DAOMember<DaoT>, DAOSpace::DAOMemberBody<DaoT>>(signer);
    }

    public fun join_member<DaoT: store>(member: address) {
        assert!(!DAOSpace::is_member<DaoT>(member), Errors::invalid_state(ERR_PLUGIN_USER_IS_MEMBER));

        let witness = VestarPlugin {};
        let cap =
            DAOSpace::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        DAOSpace::join_member<DaoT, VestarPlugin>(&cap, member, 0);
    }

    public fun increase_sbt<DaoT: store>(member: address, token: &VToken::VToken<VESTAR>) {
        let witness = VestarPlugin {};
        let cap =
            DAOSpace::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        DAOSpace::increase_member_sbt<DaoT, VestarPlugin>(&cap, member, VToken::value(token));
    }

    public fun decrease_sbt<DaoT: store>(member: address, token: &VToken::VToken<VESTAR>) {
        let witness = VestarPlugin {};
        let cap =
            DAOSpace::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        DAOSpace::decrease_member_sbt<DaoT, VestarPlugin>(&cap, member, VToken::value(token));
    }

    public(friend) fun increase_sbt_value<DaoT: store>(member: address, amount: u128) {
        let witness = VestarPlugin {};
        let cap =
            DAOSpace::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        DAOSpace::increase_member_sbt<DaoT, VestarPlugin>(&cap, member, amount);
    }

    public(friend) fun decrease_sbt_value<DaoT: store>(member: address, amount: u128) {
        let witness = VestarPlugin {};
        let cap =
            DAOSpace::acquire_member_cap<DaoT, VestarPlugin>(&witness);
        DAOSpace::decrease_member_sbt<DaoT, VestarPlugin>(&cap, member, amount);
    }
}
}

