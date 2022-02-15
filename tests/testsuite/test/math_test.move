//! account: alice, 10000000000000 0x1::STC::STC

//! sender: alice
address alice = {{alice}};
module alice::TestHelper {
    const EXP_SCALE: u128 = 10000000000;// e10

    const U64_MAX:u64 = 18446744073709551615;  //length(U64_MAX)==20
    const U128_MAX:u128 = 340282366920938463463374607431768211455;  //length(U128_MAX)==39
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Math;
    use 0x1::Debug;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::SafeMath;

    // case : x*y/z overflow
    fun math_overflow(_: signer) {
        let precision: u8 = 18;
        let scaling_factor = Math::pow(10, (precision as u64));
        let amount_x: u128 = 110000 * scaling_factor;
        let reserve_y: u128 = 8000000 * scaling_factor;
        let reserve_x: u128 = 2000000 * scaling_factor;

        let amount_y_1 = SafeMath::safe_mul_div_u128(amount_x, reserve_y, reserve_x);
        let amount_y_2 = SafeMath::safe_mul_div_u128(amount_x, reserve_x, reserve_y);
        Debug::print<u128>(&amount_y_1);
        Debug::print<u128>(&amount_y_2);
        assert(amount_y_1 == 440000 * scaling_factor, 3003);
        assert(amount_y_2 == 27500 * scaling_factor, 3004);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Math;
    use 0x1::Debug;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::SafeMath;

    // case : x*y/z overflow
    fun math_overflow2(_: signer) {
        let precision_9: u8 = 9;
        let precision_18: u8 = 18;
        let scaling_factor_9 = Math::pow(10, (precision_9 as u64));
        let scaling_factor_18 = Math::pow(10, (precision_18 as u64));
        let amount_x: u128 = 1100;
        let reserve_y: u128 = 8 * scaling_factor_9;
        let reserve_x: u128 = 2000000 * scaling_factor_18;

        let amount_y_1 = SafeMath::safe_mul_div_u128(amount_x, reserve_y, reserve_x);
        let amount_y_2 = SafeMath::safe_mul_div_u128(amount_x, reserve_x, reserve_y);
        Debug::print<u128>(&amount_y_1);
        Debug::print<u128>(&amount_y_2);
        assert(amount_y_1 == 0 * scaling_factor_9, 3006);
        assert(amount_y_2 == 275000000 * scaling_factor_9, 3007);
    }
}
// check: EXECUTED


//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Math;
    use 0x1::Debug;
    //    use alice::TestHelper;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::SafeMath;

    // case : x*y/z overflow
    //1999 * 37 / 1000
    fun math_precision_loss(_: signer) {
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
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Math;
    use 0x1::Debug;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::SafeMath;

    // case : x*y/z overflow
    fun math_safe_compair(_: signer) {
        let precision_9: u8 = 9;
        let precision_18: u8 = 18;
        let scaling_factor_9 = Math::pow(10, (precision_9 as u64));
        let scaling_factor_18 = Math::pow(10, (precision_18 as u64));
        let x1: u128 = 1100;
        let y1: u128 = 8 * scaling_factor_9;
        let x2: u128 = 2000000 * scaling_factor_18;
        let y2: u128 = 4000000 * scaling_factor_18;

        let r1 = SafeMath::safe_compare_mul_u128(x1, y1, x2, y2);
        let r2 = SafeMath::safe_compare_mul_u128(x1 * scaling_factor_18, y1 * scaling_factor_18, x2, y2);
        let r3 = SafeMath::safe_compare_mul_u128(x1, y1, x2 / scaling_factor_9, y2 / scaling_factor_9);
        Debug::print<u8>(&r1);
        Debug::print<u8>(&r2);
        Debug::print<u8>(&r3);
    }
}
// check: EXECUTED

//! new-transaction
//! sender: alice
address alice = {{alice}};
script {
    use 0x1::Math;
    use 0x1::Debug;
    use 0x2b3d5bd6d0f8a957e6a4abe986056ba7::SafeMath;
//    use 0x1::U256::{Self, U256};

    // case : x*y/z overflow
    fun math_safe_sqrt(_: signer) {
        let precision_9: u8 = 9;
        let precision_18: u8 = 18;
        let scaling_factor_9 = Math::pow(10, (precision_9 as u64));
        let scaling_factor_18 = Math::pow(10, (precision_18 as u64));

        let x: u128 = 2000000 * scaling_factor_18;
        let y: u128 = 4000000 * scaling_factor_18;
        let x1: u128 = 1100;
        let y1: u128 = 8 * scaling_factor_9;

        let r1 = SafeMath::sqrt_u256(SafeMath::mul_u128(x, y));
        let r2 = SafeMath::sqrt_u256(SafeMath::mul_u128(x1, y1));
        let r3 = SafeMath::sqrt_u256(SafeMath::mul_u128(x1, y1 / scaling_factor_9));

        Debug::print<u128>(&r1);
        Debug::print<u128>(&r2);
        Debug::print<u128>(&r3);
    }
}
// check: EXECUTED