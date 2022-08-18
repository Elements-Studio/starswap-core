address SwapAdmin {

module Boost {
    use StarcoinFramework::Math;
    use StarcoinFramework::Token;
    use SwapAdmin::VESTAR;

    /// The release amount follow the formular
    /// @param locked_time per seconds
    ///
    /// `veSTAR reward = UserLockedSTARAmount * UserLockedSTARDay / (365 * 2)`
    public fun compute_mint_amount(pledge_time_sec: u64, staked_amount: u128): u128 {
        staked_amount * (pledge_time_sec as u128) / (31536000 * 2)
    }

    /// Boost multiplier calculation follows the formula
    /// @param The amount of Vestar staked by users
    /// @param The user's pledge amount on the current farm
    /// @param Total stake on the current farm
    /// return Boost factor Max:250 
    /// `boost factor = ( UserLockedVeSTARAmount / TotalVeSTARAmount ) / ( ( 2 / 3) * UserLockedFarmAmount / TotalLockedFarmAmount ) + 1  `
    public fun compute_boost_factor(user_locked_vestar_amount: u128,
                                    user_locked_farm_amount: u128,
                                    total_farm_amount: u128): u64 {
        let factor = Math::pow(10, 8);

        let total_vestar_amount = Token::market_cap<VESTAR::VESTAR>();
        
        let boost_factor = 1 * factor;   
        let dividend = Math::mul_div(user_locked_vestar_amount, factor * 3, total_vestar_amount) * factor;
        let divisor  = Math::mul_div(user_locked_farm_amount, factor * 2, total_farm_amount);
        
        if(divisor != 0){
            boost_factor = ( dividend / divisor ) + boost_factor; 
        };
        if (boost_factor > (25 * factor / 10)) {
            boost_factor = 25 * factor / 10;
        }else if( ( 1 * factor ) < boost_factor && boost_factor <  ( 1 * factor + 1 * ( factor / 100 ) ) ){
            boost_factor =  1 * factor + 1 * ( factor / 100 ) ;
        };
        let boost_factor = boost_factor / ( factor / 100 );
        return (boost_factor as u64)
    }

    #[test_only]
    fun compute_boost_factor_test(user_locked_vestar_amount: u128, total_vestar_amount: u128, user_locked_farm_amount: u128, total_farm_amount: u128): u64 {
        let factor = Math::pow(10, 8);

        let boost_factor = 1 * factor;   
        let dividend = Math::mul_div(user_locked_vestar_amount, factor * 3, total_vestar_amount) * factor;
        let divisor  = Math::mul_div(user_locked_farm_amount, factor * 2, total_farm_amount);
        
        if(divisor != 0){
            boost_factor = ( dividend / divisor ) + boost_factor; 
        };
        if (boost_factor > (25 * factor / 10)) {  
            boost_factor = 25 * factor / 10;
        }else if( ( 1 * factor ) < boost_factor && boost_factor <  ( 1 * factor + 1 * ( factor / 100 ) ) ){
            boost_factor =  1 * factor + 1 * ( factor / 100 ) ;
        };
        let boost_factor = boost_factor / ( factor / 100 );
        return (boost_factor as u64)
    }

    #[test]
    public fun test_compute_boost_factor() {
        // let user_locked_farm_amount :u128 =  1000000000000;
        // let total_farm_amount:u128 =  3064578000000000;
        // let user_locked_vestar_amount: u128 = 1000000000000;
        // let total_vestar_amount:u128 =  500000000000000;

        let a = compute_boost_factor_test(
            0,
            500000000000000,
            1000000000000,
            3064578000000000
        );
        let b = compute_boost_factor_test(
            1000000000000,
            500000000000000,
            1000000000000,
            3064578000000000
        );
        let c = compute_boost_factor_test(
            1000000000000,
            500000000000000,
            10000000000000,
            3064578000000000
        );
        let d = compute_boost_factor_test(
            5000000000000,
            500000000000000,
            100000000000000,
            3064578000000000
        );
        let e = compute_boost_factor_test(
            10000000000000,
            500000000000000,
            10000000000000,
            3064578000000000
        );
        let f = compute_boost_factor_test(
            5000000000000,
            500000000000000,
            500000000000000,
            3064578000000000
        );
        let g = compute_boost_factor_test(
            1000000000,
            500000000000000,
            1000000000000,
            3064578000000000
        );

        let h = compute_boost_factor_test(
            0,
            500000000000000,
            1,
            3064578000000000
        );

        assert!(a == 100, 1001);
        assert!(b == 250, 1002);
        assert!(c == 191, 1003);
        assert!(d == 145, 1004);
        assert!(e == 250, 1005);
        assert!(f == 109, 1006);
        assert!(g == 101, 1007);
        assert!(h == 100, 1008);
    }

    #[test]
    public fun test_compute_mint_amount() {
        assert!(compute_mint_amount(100, 50000000000) == 79274, 10001);
    }
}
}
