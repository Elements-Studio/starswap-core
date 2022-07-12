address SwapAdmin {
module TokenSwapDaoScript {

    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::TokenSwapDao;
    use SwapAdmin::VestarPlugin;

    use StarcoinFramework::Signer;
    use StarcoinFramework::GenesisDao;
    use StarcoinFramework::Errors;

    const ERROR_HAS_BECOME_MEMBER_ALREADY: u64 = 1001;

    /// Claim farm boost from vestar to sbt
    public(script) fun claim_sbt<X: copy + drop + store,
                                 Y: copy + drop + store>(sender: signer) {
        TokenSwapFarmRouter::claim_sbt<X, Y>(&sender);
    }

    /// Claim treasury from vestar to sbt
    public(script) fun claim_treasury_sbt<X, Y>(sender: signer) {
        TokenSwapVestarMinter::claim_sbt(&sender);
    }

    /// Join TokenSwapDao, called by user
    public(script) fun join(sender: signer) {
        let member = Signer::address_of(&sender);
        assert!(!GenesisDao::is_member<TokenSwapDao::TokenSwapDao>(member),
            Errors::invalid_state(ERROR_HAS_BECOME_MEMBER_ALREADY));
        VestarPlugin::accept_sbt<TokenSwapDao::TokenSwapDao>(&sender);
        VestarPlugin::join_member<TokenSwapDao::TokenSwapDao>(member);
    }
}
}

