module SwapAdmin::U256Wrapper {
    use std::vector;
    use std::error;
    use aptos_std::from_bcs;

    const WORD: u8 = 4;
    const ERR_INVALID_LENGTH: u64 = 100;
    const ERR_OVERFLOW: u64 = 200;

    struct U256 has copy, drop, store {
//        v: u128,
        /// little endian representation
        bits: vector<u64>,
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

    fun from_bytes(data: &vector<u8>, _be: bool): U256 {
        //TODO handler little endian and big endian
        //TODO need trim ?
        let v = from_bcs::to_u128(*data);
        from_u128(v)
    }

    public fun from_u64(v: u64): U256 {
        from_u128((v as u128))
    }

    public fun from_u128(v: u128): U256 {
        let low = ((v & 0xffffffffffffffff) as u64);
        let high = ((v >> 64) as u64);
        let bits = vector::singleton(low);
        vector::push_back(&mut bits, high);
        vector::push_back(&mut bits, 0u64);
        vector::push_back(&mut bits, 0u64);
        U256 {
            bits
        }
    }

    public fun to_u128(v: &U256): u128 {
        assert!(*vector::borrow(&v.bits, 3) == 0, error::invalid_state(ERR_OVERFLOW));
        assert!(*vector::borrow(&v.bits, 2) == 0, error::invalid_state(ERR_OVERFLOW));
        ((*vector::borrow(&v.bits, 1) as u128) << 64) | (*vector::borrow(&v.bits, 0) as u128)
    }

    public fun add(a: U256, b: U256): U256 {
//        native_add(&mut a, &b);
        let au = to_u128(&a);
        let bu = to_u128(&b);
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
//        native_sub(&mut a, &b);
//        a

        let au = to_u128(&a);
        let bu = to_u128(&b);
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
//        native_mul(&mut a, &b);
//        a

        let au = to_u128(&a);
        let bu = to_u128(&b);
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
//        native_div(&mut a, &b);
//        a

        let au = to_u128(&a);
        let bu = to_u128(&b);
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
        let i = (WORD as u64);
        while (i > 0) {
            i = i - 1;
            let a_bits = *vector::borrow(&a.bits, i);
            let b_bits = *vector::borrow(&b.bits, i);
            if (a_bits != b_bits) {
                if (a_bits < b_bits) {
                    return LESS_THAN
                } else {
                    return GREATER_THAN
                }
            }
        };
        EQUAL
    }
}