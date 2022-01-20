address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module TokenSwapLibraryTest {
    #[test_only] use 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapLibrary;
    #[test_only] use 0x1::Debug;
    #[test_only] use 0x1::Math;

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
        assert(amount_y == 9999999000, 10001);
        assert(amount_y_k3_fee == 9969999005, 10002);
    }

}
}