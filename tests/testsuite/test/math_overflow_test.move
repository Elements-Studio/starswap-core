//! account: alice, 10000000000000 0x1::STC::STC

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Math;
    use 0x1::Debug;
    use 0x8c109349c6bd91411d6bc962e080c4a3::SafeMath;

    // case : x*y/z overflow
    fun math_overflow(_: signer) {
        let precision: u8 = 18;
        let scaling_factor = Math::pow(10, (precision as u64));
        let amount_x: u128 = 1000000000;
        let reserve_y: u128 = 50000;
        let reserve_x: u128 = 20000000 * scaling_factor;

        let amount_y_1 = SafeMath::safe_mul_div_u128(amount_x, reserve_y, reserve_x);
        let amount_y_2 = SafeMath::safe_mul_div_u128(amount_x, reserve_x, reserve_y);
        Debug::print<u128>(&amount_y_1);
        Debug::print<u128>(&amount_y_2);
        assert(amount_y_1 <= 0, 3003);
        assert(amount_y_2 > 0, 3004);
//        assert(amount_y_1 == 440000 * scaling_factor, 3003);
//        assert(amount_y_2 == 27500 * scaling_factor, 3004);
    }
}

// check: EXECUTED