address SwapAdmin {
module RepurchaseSTAR {

    use StarcoinFramework::STC;
    use StarcoinFramework::Account;
    use StarcoinFramework::Signer;

    use SwapAdmin::Repurchease;
    use SwapAdmin::STAR;

    struct RepurcheseSTAR has store {}

    const ERROR_NO_PERMISSION: u64 = 1001;

    public(script) fun init(sender: signer,
                            total_amount: u128,
                            begin_time: u64,
                            interval: u64,
                            release_per_time: u128, ) {
        Repurchease::accept<RepurcheseSTAR, STAR::STAR, STC::STC>(
            &sender, total_amount, begin_time, interval, release_per_time);
    }

    public(script) fun purchase(sender: signer, slipper: u128) {
        let token =
            Repurchease::repurchase<RepurcheseSTAR, STAR::STAR, STC::STC>(&sender, @RepurchaseAccount, slipper);
        Account::deposit<STC::STC>(Signer::address_of(&sender), token);
    }

    public(script) fun set_release_per_time(sender: signer, release_per_time: u128) {
        Repurchease::set_release_per_time<RepurcheseSTAR, STC::STC>(&sender, release_per_time);
    }

    public(script) fun set_interval(sender: signer, interval: u64) {
        Repurchease::set_interval<RepurcheseSTAR, STC::STC>(&sender, interval);
    }
}
}
