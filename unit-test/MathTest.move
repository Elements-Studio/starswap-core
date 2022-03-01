address SwapAdmin {
module MathTest {
    #[test_only]
    use SwapAdmin::SafeMath::{Self};
    #[test_only]
    use StarcoinFramework::Debug::{Self};
    #[test_only]
    use StarcoinFramework::Math;

    #[test]
    public fun test_loss_precision() {
        //        let precision_9: u8 = 9;
        let precision_18: u8 = 18;
        //        let scaling_factor_9 = Math::pow(10, (precision_9 as u64));
        let scaling_factor_18 = Math::pow(10, (precision_18 as u64));
        let amount_x: u128 = 1999;
        let reserve_y: u128 = 37;
        let reserve_x: u128 = 1000;

        let amount_y_1 = SafeMath::safe_mul_div_u128(amount_x, reserve_y, reserve_x);
        let amount_y_2 = SafeMath::safe_mul_div_u128(amount_x * scaling_factor_18, reserve_y, reserve_x * scaling_factor_18);
        let amount_y_2_loss_precesion = (amount_x * scaling_factor_18) / (reserve_x * scaling_factor_18) * reserve_y;
        Debug::print<u128>(&amount_y_1);
        Debug::print<u128>(&amount_y_2);
        Debug::print<u128>(&amount_y_2_loss_precesion);
        assert(amount_y_1 == 73, 3008);
        assert(amount_y_2 == 73, 3009);
        assert(amount_y_2_loss_precesion < amount_y_2, 3010);
    }

}
}