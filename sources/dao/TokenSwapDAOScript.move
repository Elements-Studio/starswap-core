address SwapAdmin {
module TokenSwapDAOScript {

    use SwapAdmin::TokenSwapFarmRouter;
    use SwapAdmin::TokenSwapVestarMinter;
    use SwapAdmin::TokenSwapDAO;
    use SwapAdmin::VestarPlugin;

    use StarcoinFramework::Signer;
    use StarcoinFramework::DAOSpace;
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
        assert!(!DAOSpace::is_member<TokenSwapDAO::TokenSwapDao>(member),
            Errors::invalid_state(ERROR_HAS_BECOME_MEMBER_ALREADY));
        VestarPlugin::accept_sbt<TokenSwapDAO::TokenSwapDao>(&sender);
        VestarPlugin::join_member<TokenSwapDAO::TokenSwapDao>(member);
    }
}
}

