module SwapAdmin::FixedPoint64 {
    use std::error;

    use SwapAdmin::U256Wrapper::{Self, U256};

    const RESOLUTION: u8 = 128;
    const Q128: u128 = 340282366920938463463374607431768211455u128;
    // 2**128
    const Q256_HEX: vector<u8> = x"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
    // 2**256
    // const RESOLUTION: u8 = 128;
    const Q64: u128 = 18446744073709551615u128;
    // 2**64
    const Q128_HEX: vector<u8> = x"ffffffffffffffffffffffffffffffff"; // 2**128

    const LOWER_MASK: u128 = 340282366920938463463374607431768211455u128;
    // decimal of UQ64x64 (lower 128 bits), equal to 0xffffffffffffffffffffffffffffffff
    const U128_MAX: u128 = 340282366920938463463374607431768211455u128;
    const U64_MAX: u128 = 18446744073709551615u128;

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    const ERR_OVERFLOW: u64 = 1001;
    const ERR_DIVIDE_BY_ZERO: u64 = 1002;

    // range: [0, 2**128 - 1]
    // resolution: 1 / 2**128
    struct UQ64x64 has copy, store, drop {
        v: U256
    }


    //    public fun Q256(): U256 {
    //        U256Wrapper::from_big_endian(Q256_HEX)
    //    }

    // encode a u128 as a UQ64x64
    // U256 type has no bitwise shift operators yet, instead of realize by mul Q64
    public fun encode(x: u128): UQ64x64 {
        // assert!(x <= U64_MAX, error::invalid_argument(ERR_OVERFLOW));
        // never overflow
        let v: U256 = U256Wrapper::mul(U256Wrapper::from_u128(x), U256Wrapper::from_u128(Q64));
        UQ64x64 {
            v
        }
    }

    // encode a u256 as a UQ64x64
    public fun encode_u256(v: U256, is_scale: bool): UQ64x64 {
        // assert!(U256Wrapper::as_u128(v) <= U64_MAX, error::invalid_argument(ERR_OVERFLOW));
        if (is_scale) {
            v = U256Wrapper::mul(v, U256Wrapper::from_u128(Q64));
        };
        UQ64x64 {
            v
        }
    }

    // decode a UQ64x64 into a u128 by truncating after the radix point
    public fun decode(uq: UQ64x64): u128 {
        U256Wrapper::as_u128(U256Wrapper::div(*&uq.v, U256Wrapper::from_u128(Q64)))
    }


    // multiply a UQ64x64 by a u128, returning a UQ64x64
    // abort on overflow
    public fun mul(uq: UQ64x64, y: u128): UQ64x64 {
        // vm would direct abort when overflow occured
        let v: U256 = U256Wrapper::mul(*&uq.v, U256Wrapper::from_u128(y));
        UQ64x64 {
            v
        }
    }

    //    #[test]
    //    /// U128_MAX * U128_MAX < U256_MAX
    //    public fun test_u256_mul_not_overflow() {
    //        let u256_max:U256 = Q256();
    //        let u128_max = U256Wrapper::from_u128(U128_MAX);
    //        let u128_mul_u128_max = U256Wrapper::mul(copy u128_max, copy u128_max);
    //        let order = U256Wrapper::compare(&u256_max, &u128_mul_u128_max);
    //        assert!(order == GREATER_THAN, 1100);
    //
    //    }

    // divide a UQ64x64 by a u128, returning a UQ64x64
    public fun div(uq: UQ64x64, y: u128): UQ64x64 {
        if (y == 0) {
            abort error::invalid_argument(ERR_DIVIDE_BY_ZERO)
        };
        let v: U256 = U256Wrapper::div(*&uq.v, U256Wrapper::from_u128(y));
        UQ64x64 {
            v
        }
    }

    public fun to_u256(uq: UQ64x64): U256 {
        *&uq.v
    }


    // returns a UQ64x64 which represents the ratio of the numerator to the denominator
    public fun fraction(numerator: u128, denominator: u128): UQ64x64 {
        let r: U256 = U256Wrapper::mul(U256Wrapper::from_u128(numerator), U256Wrapper::from_u128(Q64));
        let v: U256 = U256Wrapper::div(r, U256Wrapper::from_u128(denominator));
        UQ64x64 {
            v
        }
    }

    public fun to_safe_u128(x: U256): u128 {
        let u128_max = U256Wrapper::from_u128(U128_MAX);
        let cmp_order = U256Wrapper::compare(&x, &u128_max);
        if (cmp_order == GREATER_THAN) {
            abort error::invalid_argument(ERR_OVERFLOW)
        };
        U256Wrapper::as_u128(x)
    }

    public fun compare(left: UQ64x64, right: UQ64x64): u8 {
        U256Wrapper::compare(&left.v, &right.v)
    }

    public fun is_zero(uq: UQ64x64): bool {
        let r = U256Wrapper::compare(&uq.v, &U256Wrapper::zero());
        if (r == 0) {
            true
        } else {
            false
        }
    }
}

