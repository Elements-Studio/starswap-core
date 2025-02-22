module swap_admin::SafeMath {

    use std::error;

    use starcoin_std::math128;

    #[test_only]
    use starcoin_std::math64;

    // e10
    const EXP_SCALE_18: u128 = 1000000000000000000;
    // e18
    const U64_MAX: u64 = 18446744073709551615;
    //length(U64_MAX)==20
    const U128_MAX: u128 = 340282366920938463463374607431768211455;  //length(U128_MAX)==39

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const ERR_U128_OVERFLOW: u64 = 1001;
    const ERR_DIVIDE_BY_ZERO: u64 = 1002;
    //    const MUL_DIV_OVERFLOW_U128: u64 = 1003;

    /// support 18-bit or larger precision token
    public fun safe_mul_div_u128(x: u128, y: u128, z: u128): u128 {
        let r_u256 = mul_div_u128(x, y, z);
        assert!((r_u256 <= (U128_MAX as u256)), error::invalid_argument(ERR_U128_OVERFLOW));
        (r_u256 as u128)
    }

    public fun mul_div_u128(x: u128, y: u128, z: u128): u256 {
        assert!(z > 0, error::invalid_argument(ERR_DIVIDE_BY_ZERO));
        if (x <= EXP_SCALE_18 && y <= EXP_SCALE_18) {
            return ((x * y / z) as u256)
        };

        let rx = (x as u256);
        let ry = (y as u256);
        let rz = (z as u256);
        rx * ry / rz
    }

    #[test]
    public fun test_safe_mul_div_u128() {
        let x: u128 = 9446744073709551615;
        let y: u128 = 1009855555;
        let z: u128 = 3979;
        //        getcontext().prec = 64
        //        Decimal(9446744073709551615)*Decimal(1009855555)/Decimal(3979)
        //        Decimal('2397548876476230247541334.839')
        let _r_expected: u128 = 2397548876476230247541334;
        let r = Self::safe_mul_div_u128(x, y, z);
        assert!(r == _r_expected, 3001);
    }

    #[test]
    #[expected_failure]
    public fun test_safe_mul_div_u128_overflow() {
        let x: u128 = 240282366920938463463374607431768211455;
        let y: u128 = 1009855555;
        let z: u128 = 3979;

        let _r_expected: u128 = 9539846979498919717765120;
        let r = Self::safe_mul_div_u128(x, y, z);
        assert!(r == _r_expected, 3002);
    }


    /// support 18-bit or larger precision token
    public fun safe_compare_mul_u128(x1: u128, y1: u128, x2: u128, y2: u128): u8 {
        let r1 = (x1 as u256) * (y1 as u256);
        let r2 = (x2 as u256) * (y2 as u256);
        if (r1 == r2) {
            EQUAL
        } else if (r1 < r2) {
            LESS_THAN
        } else {
            GREATER_THAN
        }
    }

    public fun mul_u128(x: u128, y: u128): u256 {
        (x as u256) * (y as u256)
    }

    /// support 18-bit or larger precision token
    /// base on native U256
    /// babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    public fun sqrt_u256(y: u256): u128 {
        let u128_max = (U128_MAX as u256);
        if (y <= u128_max) {
            math128::sqrt((y as u128))
        } else {
            let z = y;
            let one_u256 = 1u256;
            let two_u256 = 2u256;
            let x = y / two_u256 + one_u256;
            while (x < z) {
                z = x;
                x = (y / x + x) / two_u256; // U256::div(U256::add(U256::div(copy y, copy x), copy x), copy two_u256);
            };
            // U256::to_u128(&z)
            (z as u128)
        }
    }

    #[test]
    fun test_loss_precision() {
        let precision_18: u8 = 18;
        let scaling_factor_18 = (math64::pow(10, (precision_18 as u64)) as u128);
        let amount_x: u128 = 1999;
        let reserve_y: u128 = 37;
        let reserve_x: u128 = 1000;

        let amount_y_1 = Self::safe_mul_div_u128(amount_x, reserve_y, reserve_x);
        let amount_y_2 = Self::safe_mul_div_u128(
            amount_x * scaling_factor_18,
            reserve_y,
            reserve_x * scaling_factor_18
        );
        let amount_y_2_loss_precesion =
            (amount_x * scaling_factor_18) / (reserve_x * scaling_factor_18) * reserve_y;
        assert!(amount_y_1 == 73, 3008);
        assert!(amount_y_2 == 73, 3009);
        assert!(amount_y_2_loss_precesion < amount_y_2, 3010);
    }

    #[test]
    public fun test_sqrt_u256() {
        let x: u128 = 90282366920938463463374607431768211455;
        let y: u128 = 1009855555;
        //        getcontext().prec = 64
        //        (Decimal(90282366920938463463374607431768211455)*Decimal(1009855555)).sqrt()
        //        Decimal('301947263199483152960157.5789842310747215103252658913180283305935')
        let _r_expected: u128 = 301947263199483152960157;
        let r = Self::sqrt_u256(Self::mul_u128(x, y));
        assert!(r == _r_expected, 3003);
    }

    #[test]
    public fun test_sqrt_u256_by_max_u128() {
        let _r_expected: u128 = 18446744073709551615;
        let r = Self::sqrt_u256((U128_MAX as u256));
        assert!(r == _r_expected, 3004);
    }

    public fun to_safe_u128(x: u256): u128 {
        assert!(x < (U128_MAX as u256), error::invalid_argument(ERR_U128_OVERFLOW));
        (x as u128)
    }
}