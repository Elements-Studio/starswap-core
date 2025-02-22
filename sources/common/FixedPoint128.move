module swap_admin::FixedPoint128 {

    use std::error;

    const RESOLUTION: u8 = 128;
    const Q128: u128 = 340282366920938463463374607431768211455u128;
    // 2**128
    // const Q256_HEX: vector<u8> = x"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    const Q256_DEC: u256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    // 2**256
    const LOWER_MASK: u128 = 340282366920938463463374607431768211455u128;
    // decimal of UQ128x128 (lower 128 bits), equal to 0xffffffffffffffffffffffffffffffff
    const U128_MAX: u128 = 340282366920938463463374607431768211455u128;
    const U64_MAX: u128 = 18446744073709551615u128;

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const ERR_U128_OVERFLOW: u64 = 1001;
    const ERR_DIVIDE_BY_ZERO: u64 = 1002;

    // range: [0, 2**128 - 1]
    // resolution: 1 / 2**128
    struct UQ128x128 has copy, store, drop {
        v: u256
    }

    public fun Q256(): u256 {
        Q256_DEC
    }

    // encode a u128 as a UQ128x128
    // U256 type has no bitwise shift operators yet, instead of realize by mul Q128
    public fun encode(x: u128): UQ128x128 {
        // never overflow
        // let v: U256 = U256::mul(U256::from_u128(x), U256::from_u128(Q128));
        let v = (x as u256) * (Q128 as u256);
        UQ128x128 {
            v
        }
    }

    // encode a u256 as a UQ128x128
    public fun encode_u256(v: u256, is_scale: bool): UQ128x128 {
        if (is_scale) {
            //v = U256::mul(v, U256::from_u128(Q128));
            v = v * (Q128 as u256);
        };

        UQ128x128 {
            v
        }
    }

    // decode a UQ128x128 into a u128 by truncating after the radix point
    public fun decode(uq: UQ128x128): u128 {
        // U256::to_u128(&U256::div(*&uq.v, U256::from_u128(Q128)))
        (uq.v / (Q128 as u256) as u128)
    }


    // multiply a UQ128x128 by a u128, returning a UQ128x128
    // abort on overflow
    public fun mul(uq: UQ128x128, y: u128): UQ128x128 {
        // vm would direct abort when overflow occured
        let v = uq.v * (y as u256);
        UQ128x128 {
            v
        }
    }

    #[test]
    /// U128_MAX * U128_MAX < U256_MAX
    public fun test_u256_mul_not_overflow() {
        let u256_max = Q256();
        let u128_max = (U128_MAX as u256);
        let u128_mul_u128_max = (u128_max * u128_max);
        assert!(u256_max > u128_mul_u128_max, 1100);
    }

    // divide a UQ128x128 by a u128, returning a UQ128x128
    public fun div(uq: UQ128x128, y: u128): UQ128x128 {
        assert!(y > 0, error::invalid_argument(ERR_DIVIDE_BY_ZERO));
        let v = uq.v / (y as u256);
        UQ128x128 {
            v
        }
    }

    public fun to_u256(uq: UQ128x128): u256 {
        uq.v
    }

    // returns a UQ128x128 which represents the ratio of the numerator to the denominator
    public fun fraction(numerator: u128, denominator: u128): UQ128x128 {
        // let r: U256 = U256::mul(U256::from_u128(numerator), U256::from_u128(Q128));
        // let v: U256 = U256::div(r, U256::from_u128(denominator));
        let r = (numerator as u256) * (Q128 as u256);
        let v = r / (denominator as u256);
        UQ128x128 {
            v
        }
    }

    public fun to_safe_u128(x: u256): u128 {
        assert!(x < (U128_MAX as u256), error::invalid_argument(ERR_U128_OVERFLOW));
        (x as u128)
    }

    public fun compare(left: UQ128x128, right: UQ128x128): u8 {
        let r1 = left.v;
        let r2 = right.v;
        if (r1 == r2) {
            EQUAL
        } else if (r1 < r2) {
            LESS_THAN
        } else {
            GREATER_THAN
        }
    }

    public fun is_zero(uq: UQ128x128): bool {
        uq.v == 0
    }
}

