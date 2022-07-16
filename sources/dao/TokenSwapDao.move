address SwapAdmin {
module TokenSwapDao {

    use StarcoinFramework::GenesisDao;
    use StarcoinFramework::DaoAccount;
    use StarcoinFramework::InstallPluginProposalPlugin::{Self, InstallPluginProposalPlugin};

    use SwapAdmin::VestarPlugin;

    struct TokenSwapDao has store, drop {}

    const NAME: vector<u8> = b"StarswapDao";

    /// sender should create a DaoAccount before call this entry function.
    public(script) fun create_dao(sender: signer,
                                  voting_delay: u64,
                                  voting_period: u64,
                                  voting_quorum_rate: u8,
                                  min_action_delay: u64,
                                  min_proposal_deposit: u128) {
        let dao_account_cap = DaoAccount::upgrade_to_dao(sender);
        //let dao_signer = DaoAccount::dao_signer(&dao_account_cap);
        let config = GenesisDao::new_dao_config(
            voting_delay,
            voting_period,
            voting_quorum_rate,
            min_action_delay,
            min_proposal_deposit,
        );
        let dao_root_cap = GenesisDao::create_dao<TokenSwapDao>(dao_account_cap, *&NAME, TokenSwapDao {}, config);

        GenesisDao::install_plugin_with_root_cap<TokenSwapDao, InstallPluginProposalPlugin>(&dao_root_cap, InstallPluginProposalPlugin::required_caps());
        GenesisDao::install_plugin_with_root_cap<TokenSwapDao, VestarPlugin::VestarPlugin>(&dao_root_cap, VestarPlugin::required_caps());

        GenesisDao::burn_root_cap(dao_root_cap);
    }
}
}

