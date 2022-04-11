address SwapAdmin {

module Boost {
    use StarcoinFramework::Math;
    use StarcoinFramework::Token;
    use SwapAdmin::VESTAR;
    /// The release amount follow the formular
    /// @param locked_time per seconds
    ///
    /// `veSTAR reward = UserLockedSTARAmount * UserLockedSTARDay / 365`
    public fun compute_mint_amount(pledge_time_sec: u64, staked_amount: u128): u128 {
        let locked_day = pledge_time_sec / 60 * 60 * 24;
        staked_amount * (locked_day as u128) / 365u128
    }

    /// Boost multiplier calculation follows the formula
    /// @param The amount of Vestar staked by users
    /// @param The user's pledge amount on the current farm
    /// @param Total stake on the current farm
    /// return Boost factor Max:250000 
    /// `When: UserLockedFarmAmount / TotalLockedFarmAmount < 0.001`
    /// `boost factor = (( UserLockedVeSTARAmount / TotalVeSTARAmount ) / (UserLockedFarmAmount / TotalLockedFarmAmount) )* 1500000  + 1  `
    /// `When: UserLockedFarmAmount / TotalLockedFarmAmount >= 0.001`
    /// `boost factor = ( UserLockedVeSTARAmount / TotalVeSTARAmount ) / ( ( 2 / 3) * UserLockedFarmAmount / TotalLockedFarmAmount ) + 1  `
    public fun compute_boost_factor(user_locked_vestar_amount:u128,user_locked_farm_amount:u128,total_farm_amount:u128) : u64 {
        let factor = Math::pow(10,6);

        let total_vestar_amount = Token::market_cap<VESTAR::VESTAR>();
        let small_LP = 1000;   
        let lp = user_locked_farm_amount * factor / total_farm_amount;
        let boost_factor =  if( lp  <  small_LP){
                Math::mul_div(user_locked_farm_amount , factor ,  total_farm_amount ) * Math::mul_div(user_locked_vestar_amount , factor ,  total_vestar_amount )  * 1500000 / factor  + ( 1 * factor)
            }else{
                Math::mul_div(user_locked_vestar_amount , factor * 3 , total_vestar_amount ) * factor / Math::mul_div( user_locked_farm_amount , factor * 2 , total_farm_amount ) + ( 1 * factor)
            };
        if(boost_factor > 25 * factor / 10 ){
            boost_factor = 25 * factor / 10;
        };
        let boost_factor = boost_factor  / ( factor / Math::pow(10,2));
        return (boost_factor as u64)
    }

    #[test_only]
    fun compute_boost_factor_test(user_locked_vestar_amount:u128,total_vestar_amount:u128,user_locked_farm_amount:u128,total_farm_amount:u128):u64{
        let factor = Math::pow(10,6);
        let small_LP = 1000;   
        let lp = user_locked_farm_amount * factor / total_farm_amount;
        let boost_factor =  if( lp  <  small_LP){
                Math::mul_div(user_locked_farm_amount , factor ,  total_farm_amount ) * Math::mul_div(user_locked_vestar_amount , factor ,  total_vestar_amount )  * 1500000 / factor  + ( 1 * factor)
            }else{
                Math::mul_div(user_locked_vestar_amount , factor * 3 , total_vestar_amount ) * factor / Math::mul_div( user_locked_farm_amount , factor * 2 , total_farm_amount ) + ( 1 * factor)
            };
        if(boost_factor > 25 * factor / 10 ){
            boost_factor = 25 * factor / 10;
        };

        let boost_factor = boost_factor  / ( factor / Math::pow(10,2));
        return (boost_factor as u64)
    }
    #[test]
    public fun test_compute_boost_factor(){
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
        assert!(a == 100 ,1001);
        assert!(b == 197 ,1002);
        assert!(c == 191 ,1003);
        assert!(d == 145 ,1004);
        assert!(e == 250 ,1005);
        assert!(f == 109 ,1006);


    }
}
}
