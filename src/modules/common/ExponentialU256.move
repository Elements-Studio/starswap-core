address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module ExponentialU256 {
    use 0x1::Errors;
    use 0x1::U256::{Self};

    const EXP_SCALE: u128 = 1000000000000000000;// e18
    const DOUBLE_SCALE: u128 = 1000000000000000000000000000000000000u128; //e36
    const HALF_EXP_SCALE: u128 = 1000000000000000000 / 2;
    const MANTISSA_ONE: u128 = 1000000000000000000;
    const U128_MAX: u128 = 340282366920938463463374607431768211455u128;
    const U64_MAX: u128 = 18446744073709551615u128;


    const OVER_FLOW: u64 = 1001;
    const DIVIDE_BY_ZERO: u64 = 1002;

    struct Exp has copy, store, drop {
        mantissa: U256::U256
    }

    struct Double has copy, store, drop {
        mantissa: U256::U256
    }

    public fun exp_scale(): u128 {
        return EXP_SCALE
    }

    public fun exp(num: u128, denom: u128): Exp {
        //        if overflow move will abort
        let scaledNumerator: U256::U256 = mul_u128(num, EXP_SCALE);
        let rational = U256::div(scaledNumerator, U256::from_u128(denom));
        Exp {
            mantissa: rational
        }
    }

    public fun exp_u256(num: U256::U256, denom: U256::U256): Exp {
        let scaledNumerator: U256::U256 = U256::mul(num, U256::from_u128(EXP_SCALE));
        let rational = U256::div(scaledNumerator, denom);
        Exp {
            mantissa: rational
        }
    }

    public fun exp_direct(num: u128): Exp {
        Exp {
            mantissa: U256::from_u128(num)
        }
    }

    public fun mantissa(a: Exp): U256::U256 {
        *&a.mantissa
    }

    public fun mantissa_to_u128(a: Exp): u128 {
        U256::to_u128(&a.mantissa)
    }

    public fun add_exp(a: Exp, b: Exp): Exp {
        Exp {
            mantissa: U256::add(*&a.mantissa, *&b.mantissa)
        }
    }

    public fun sub_exp(a: Exp, b: Exp): Exp {
        Exp {
            mantissa: U256::sub(*&a.mantissa, *&b.mantissa)
        }
    }


    public fun mul_scalar_exp(a: Exp, scalar: u128): Exp {
        Exp {
            mantissa: U256::mul(*&a.mantissa, U256::from_u128(scalar))
        }
    }

    public fun mul_scalar_exp_truncate(a: Exp, scalar: u128): Exp {
        Exp {
            mantissa: truncate(mul_scalar_exp(*&a, *&scalar))
        }
    }

    public fun mul_scalar_exp_truncate_add(a: Exp, scalar: u128, addend: u128): U256::U256 {
        let e = mul_scalar_exp(a, scalar);
        U256::add(truncate(e), U256::from_u128(addend))
    }


    public fun div_scalar_exp(a: Exp, scalar: u128): Exp {
        Exp {
            mantissa: U256::div(*&a.mantissa, U256::from_u128(scalar))
        }
    }

    public fun div_scalar_by_exp(scalar: u128, divisor: Exp): Exp {
        /*
         How it works:
         Exp = a / b;
         Scalar = s;
         `s / (a / b)` = `b * s / a` and since for an Exp `a = mantissa, b = expScale`
       */
        let numerator = mul_u128(EXP_SCALE, scalar);
        exp_u256(numerator, *&divisor.mantissa)
    }

    public fun div_scalar_by_exp_truncate(scalar: u128, divisor: Exp): U256::U256 {
        truncate(div_scalar_by_exp(scalar, divisor))
    }


    public fun mul_exp(a: Exp, b: Exp): Exp {
        let double_scaled_product = U256::mul(*&a.mantissa, *&b.mantissa);
        let double_scaled_product_with_half_scale = U256::add(U256::from_u128(HALF_EXP_SCALE), double_scaled_product);
        let product = U256::div(double_scaled_product_with_half_scale, U256::from_u128(EXP_SCALE));

        Exp {
            mantissa: product
        }
    }

    public fun mul_exp_u128(a: u128, b: u128): Exp {
        return mul_exp(Exp { mantissa: U256::from_u128(a) }, Exp { mantissa: U256::from_u128(b) })
    }

    public fun mul_exp_3(a: Exp, b: Exp, c: Exp): Exp {
        let m = mul_exp(a, b);
        mul_exp(m, c)
    }

    public fun div_exp(a: Exp, b: Exp): Exp {
        exp_u256(*&a.mantissa, *&b.mantissa)
    }

    public fun truncate(exp: Exp): U256::U256 {
        U256::div(*&exp.mantissa, U256::from_u128(EXP_SCALE))
    }

    fun mul_scalar_truncate_(exp: Exp, scalar: u128): U256::U256 {
        let v = U256::mul(*&exp.mantissa, U256::from_u128(scalar));
        truncate(Exp {
            mantissa: v
        })
    }

    fun mul_scalar_truncate_add_(exp: Exp, scalar: u128, addend: u128): U256::U256 {
        let v = U256::mul(*&exp.mantissa, U256::from_u128(scalar));
        let truncate = truncate(Exp { mantissa: v });
        U256::add(truncate, U256::from_u128(addend))
    }

    public fun less_than_exp(left: Exp, right: Exp): bool {
        let ret = U256::compare(&left.mantissa, &right.mantissa);
        if (ret == 1) {
            true
        } else {
            false
        }
    }

    public  fun less_than_or_equal_exp(left: Exp, right: Exp): bool {
        let ret = U256::compare(&left.mantissa, &right.mantissa);
        if (ret == 2) {
            false
        } else {
            true
        }
    }

    public fun equal_exp(left: Exp, right: Exp): bool {
        let ret = U256::compare(&left.mantissa, &right.mantissa);
        if (ret == 0) {
            true
        } else {
            false
        }
    }

    public fun greater_than_exp(left: Exp, right: Exp): bool {
        let ret = U256::compare(&left.mantissa, &right.mantissa);
        if (ret == 2) {
            true
        } else {
            false
        }
    }

    public fun is_zero(exp: Exp): bool {
        let ret = U256::compare(&exp.mantissa, &U256::zero());
        if (ret == 0) {
            true
        } else {
            false
        }
    }


    fun safe64(v: u128): u64 {
        if (v <=  U64_MAX) {
            return (v as u64)
        };
        abort Errors::invalid_argument(OVER_FLOW)
    }

    fun add_u128(a: u128, b: u128): u128 {
        a + b
    }

    fun sub_u128(a: u128, b: u128): u128 {
        a - b
    }

    fun mul_u128(a: u128, b: u128): U256::U256 {
        if (a == 0 || b == 0) {
            return U256::zero()
        };
        let a_u256 = U256::from_u128(a);
        let b_u256 = U256::from_u128(b);
        U256::mul(a_u256, b_u256)

    }

    fun div_u128(a: u128, b: u128): u128 {
        if ( b == 0) {
            abort Errors::invalid_argument(DIVIDE_BY_ZERO)
        };
        if (a == 0) {
            return 0
        };
        a / b
    }


    public fun fraction(a: u128, b: u128): Double {
        let v = U256::div(mul_u128(a, DOUBLE_SCALE), U256::from_u128(b));
        Double {
            mantissa: v
        }
    }
}
}

