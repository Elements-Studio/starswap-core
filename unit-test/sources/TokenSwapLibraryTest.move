address SwapAdmin {
module TokenSwapLibraryTest {
    #[test_only] use SwapAdmin::TokenSwapLibrary;
    #[test_only] use StarcoinFramework::Debug;
    #[test_only] use StarcoinFramework::Math;

    #[test]
    public fun test_get_amount_out_without_fee() {
        let precision_9: u8 = 9;
        let scaling_factor_9 = Math::pow(10, (precision_9 as u64));
        let amount_x: u128 = 1 * scaling_factor_9;
        let reserve_x: u128 = 10000000 * scaling_factor_9;
        let reserve_y: u128 = 100000000 * scaling_factor_9;

        let amount_y = TokenSwapLibrary::get_amount_out_without_fee(amount_x, reserve_x, reserve_y);
        let amount_y_k3_fee = TokenSwapLibrary::get_amount_out(amount_x, reserve_x, reserve_y, 3, 1000);
        Debug::print(&amount_y);
        Debug::print(&amount_y_k3_fee);
        assert!(amount_y == 9999999000, 10001);
        assert!(amount_y_k3_fee == 9969999005, 10002);
    }

}
}