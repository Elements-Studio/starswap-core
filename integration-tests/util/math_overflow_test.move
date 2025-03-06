//# init -n test --public-keys swap_admin=0x5510ddb2f172834db92842b0b640db08c2bc3cd986def00229045d78cc528ac5

//# faucet --addr alice --amount 10000000000000000


//# run --signers alice

script {
    use starcoin_std::math128;
    use starcoin_std::debug;

    use swap_admin::SafeMath;

    // case : x*y/z overflow
    fun math_overflow(_: signer) {
        let precision: u8 = 18;
        let scaling_factor = math128::pow(10, (precision as u128));

        let amount_x: u128 = 1_000_000_000;
        let reserve_y: u128 = 50_000;
        let reserve_x: u128 = 20_000_000 * scaling_factor;

        let amount_y_1 = SafeMath::safe_mul_div_u128(amount_x, reserve_y, reserve_x);
        let amount_y_2 = SafeMath::safe_mul_div_u128(amount_x, reserve_x, reserve_y);
        debug::print<u128>(&amount_y_1);
        debug::print<u128>(&amount_y_2);
        assert!(amount_y_1 <= 0, 3003);
        assert!(amount_y_2 > 0, 3004);
        //        assert!(amount_y_1 == 440000 * scaling_factor, 3003);
        //        assert!(amount_y_2 == 27500 * scaling_factor, 3004);
    }
}

// check: EXECUTED