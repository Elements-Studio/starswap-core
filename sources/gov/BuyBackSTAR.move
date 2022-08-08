address SwapAdmin {
module BuyBackSTAR {

    use StarcoinFramework::STC;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;

    use SwapAdmin::BuyBack;
    use SwapAdmin::STAR;

    struct BuyBackSTAR has store {}

    const ERROR_NO_PERMISSION: u64 = 1001;

    public(script) fun init(sender: signer,
                            total_amount: u128,
                            begin_time: u64,
                            interval: u64,
                            release_per_time: u128, ) {
        BuyBack::accept<BuyBackSTAR, STAR::STAR, STC::STC>(
            &sender, total_amount, begin_time, interval, release_per_time);
    }

    public(script) fun buy_back(sender: signer, slipper: u128) {
        let token =
            BuyBack::buy_back<BuyBackSTAR, STAR::STAR, STC::STC>(&sender, @BuyBackAccount, slipper);
        Account::deposit<STC::STC>(Signer::address_of(&sender), token);
    }

    public(script) fun set_release_per_time(sender: signer, release_per_time: u128) {
        BuyBack::set_release_per_time<BuyBackSTAR, STC::STC>(&sender, release_per_time);
    }

    public(script) fun set_interval(sender: signer, interval: u64) {
        BuyBack::set_interval<BuyBackSTAR, STC::STC>(&sender, interval);
    }
}
}
