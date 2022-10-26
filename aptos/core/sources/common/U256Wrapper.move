module SwapAdmin::U256Wrapper {
    use std::vector;
    use std::error;
    use aptos_std::from_bcs;
    #[test_only]
    use aptos_std::bcs;
    #[test_only]
    use aptos_std::debug;

    const WORD: u8 = 4;
    const ERR_INVALID_LENGTH: u64 = 2000;
    const ERR_OVERFLOW: u64 = 2001;
    const ERR_DIVIDE_BY_ZERO: u64 = 2002;

    const U128_MAX: u128 = 340282366920938463463374607431768211455u128;
    const U64_MAX: u128 = 18446744073709551615u128;

    struct U256 has copy, drop, store {
       v: u128,
    }

    public fun zero(): U256 {
        from_u128(0u128)
    }

    public fun one(): U256 {
        from_u128(1u128)
    }

    public fun from_big_endian(data: vector<u8>): U256 {
        // TODO: define error code.
        assert!(vector::length(&data) <= 32, error::invalid_argument(ERR_INVALID_LENGTH));
        from_bytes(&data, true)
    }

    public fun from_little_endian(data: vector<u8>): U256 {
        // TODO: define error code.
        assert!(vector::length(&data) <= 32, error::invalid_argument(ERR_INVALID_LENGTH));
        from_bytes(&data, false)
    }

    //TODO just for test code
    fun from_bytes(data: &vector<u8>, _be: bool): U256 {
        //TODO handler little endian and big endian
        //clip a u128 bytes from U256 bcs bytes
        let v = from_bcs::to_u128(*data);
        from_u128(v)
    }

    #[test]
    fun test_from_bytes() {
        let v = Self::from_u128(102);
        debug::print(&v);
        let data = bcs::to_bytes(&v);
        debug::print(&data);

        let vv = from_bcs::to_u128(data);
        debug::print(&vv);

        let nv = from_bytes(&data, true);
        debug::print(&nv);
        assert!(compare(&v, &nv) == EQUAL, 1);
    }


    public fun from_u64(v: u64): U256 {
        from_u128((v as u128))
    }

    public fun from_u128(v: u128): U256 {
        U256 {
            v
        }
    }

    public fun as_u128(v: U256): u128 {
        v.v
    }

    public fun add(a: U256, b: U256): U256 {
        // assert!(a.v <= U64_MAX, error::invalid_argument(ERR_OVERFLOW));
        // assert!(b.v <= U64_MAX, error::invalid_argument(ERR_OVERFLOW));
        let au = as_u128(a);
        let bu = as_u128(b);
        let v = au + bu;

        from_u128(v)
    }

    #[test]
    fun test_add() {
        let a = Self::one();
        let b = Self::from_u128(10);
        let ret = Self::add(a, b);
        assert!(compare(&ret, &from_u64(11)) == EQUAL, 0);
    }

    public fun sub(a: U256, b: U256): U256 {
        // assert!(a.v <= U64_MAX, error::invalid_argument(ERR_OVERFLOW));
        // assert!(b.v <= U64_MAX, error::invalid_argument(ERR_OVERFLOW));
        let au = as_u128(a);
        let bu = as_u128(b);
        let v = au - bu;

        from_u128(v)
    }

    #[test]
    #[expected_failure]
    fun test_sub_overflow() {
        let a = Self::one();
        let b = Self::from_u128(10);
        let _ = Self::sub(a, b);
    }

    #[test]
    fun test_sub_ok() {
        let a = Self::from_u128(10);
        let b = Self::one();
        let ret = Self::sub(a, b);
        assert!(compare(&ret, &from_u64(9)) == EQUAL, 0);
    }

    public fun mul(a: U256, b: U256): U256 {
        // assert!(a.v <= U64_MAX, error::invalid_argument(ERR_OVERFLOW));
        // assert!(b.v <= U64_MAX, error::invalid_argument(ERR_OVERFLOW));
        let au = as_u128(a);
        let bu = as_u128(b);
        let v = au * bu;

        from_u128(v)
    }

    #[test]
    fun test_mul() {
        let a = Self::from_u128(10);
        let b = Self::from_u64(10);
        let ret = Self::mul(a, b);
        assert!(compare(&ret, &from_u64(100)) == EQUAL, 0);
    }

    public fun div(a: U256, b: U256): U256 {
        assert!(b.v != 0, error::invalid_argument(ERR_DIVIDE_BY_ZERO));

        let au = as_u128(a);
        let bu = as_u128(b);
        let v = au / bu;

        from_u128(v)
    }

    #[test]
    fun test_div() {
        let a = Self::from_u128(10);
        let b = Self::from_u64(2);
        let c = Self::from_u64(3);
        // as U256 cannot be implicitly copied, we need to add copy keyword.
        assert!(compare(&Self::div(copy a, b), &from_u64(5)) == EQUAL, 0);
        assert!(compare(&Self::div(copy a, c), &from_u64(3)) == EQUAL, 0);
    }

    const EQUAL: u8 = 0;
    const LESS_THAN: u8 = 1;
    const GREATER_THAN: u8 = 2;

    public fun compare(a: &U256, b: &U256): u8 {
        let au = as_u128(*a);
        let bu = as_u128(*b);

        if (au < bu) {
            LESS_THAN
        } else if (au > bu) {
            GREATER_THAN
        } else {
            EQUAL
        }
    }
}