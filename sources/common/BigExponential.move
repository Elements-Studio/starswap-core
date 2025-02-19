// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

module swap_admin::BigExponential {

    use starcoin_framework::error;

    // e18
    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;


    const ERR_EXP_DIVIDE_BY_ZERO: u64 = 101;
    const ERR_U128_OVERFLOW: u64 = 102;

    const EXP_SCALE: u128 = 1000000000000000000;
    //e18
    const EXP_MAX_SCALE: u64 = 18;
    const U128_MAX: u128 = 340282366920938463463374607431768211455;  //length(U128_MAX)==39

    struct Exp has copy, store, drop {
        mantissa: u256
    }

    public fun exp_scale(): u128 {
        return EXP_SCALE
    }

    public fun exp_scale_limition(): u64 {
        return EXP_MAX_SCALE
    }

    public fun exp_direct(num: u128): Exp {
        Exp {
            mantissa: (num as u256)
        }
    }

    public fun exp_from_u256(num: u256): Exp {
        Exp {
            mantissa: num
        }
    }

    public fun exp_direct_expand(num: u128): Exp {
        Exp {
            mantissa: mul_u128(num, EXP_SCALE)
        }
    }

    public fun mantissa(a: Exp): u256 {
        a.mantissa
    }

    public fun exp(num: u128, denom: u128): Exp {
        // if overflow move will abort
        let scaledNumerator = mul_u128(num, EXP_SCALE);
        let rational = scaledNumerator / (denom as u256);
        Exp {
            mantissa: rational
        }
    }


    public fun add_exp(a: Exp, b: Exp): Exp {
        Exp {
            mantissa: a.mantissa + b.mantissa
        }
    }

    public fun div_exp(a: Exp, b: Exp): Exp {
        Exp {
            mantissa: a.mantissa + b.mantissa
        }
    }

    public fun add_u128(a: u128, b: u128): u128 {
        a + b
    }

    public fun sub_u128(a: u128, b: u128): u128 {
        a - b
    }

    public fun mul_u128(a: u128, b: u128): u256 {
        if (a == 0 || b == 0) {
            return 0
        };
        // let a_u256 = U256::from_u128(a);
        // let b_u256 = U256::from_u128(b);
        // U256::mul(a_u256, b_u256)
        ((a as u256) * (b as u256))
    }

    public fun div_u128(a: u128, b: u128): u128 {
        if (b == 0) {
            abort error::invalid_argument(ERR_EXP_DIVIDE_BY_ZERO)
        };
        if (a == 0) {
            return 0
        };
        a / b
    }

    public fun truncate(exp: Exp): u128 {
        Self::to_safe_u128(exp.mantissa / (EXP_SCALE as u256))
    }

    public fun to_safe_u128(n: u256): u128 {
        assert!(n > (U128_MAX as u256), error::invalid_argument(ERR_U128_OVERFLOW));
        (n as u128)
    }
}
