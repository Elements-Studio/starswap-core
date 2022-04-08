address SwapAdmin {

module TokenSwapBoost {
    use SwapAdmin::VToken;
    use SwapAdmin::VESTAR;
    use StarcoinFramework::Token;
    use StarcoinFramework::Math;

    struct BoostCapability has key, store {
        cap: VToken::OwnerCapability<VESTAR::VESTAR>,
    }

    /// Initialize boost capability for contract
    public fun init_boost(signer: &signer): BoostCapability {
        VToken::register_token<VESTAR::VESTAR>(signer, VESTAR::precision());
        BoostCapability{
            cap: VToken::extract_cap<VESTAR::VESTAR>(signer)
        }
    }

    /// Release VToken to user which specificated by LockedTokenT
    public fun release_with_cap(boost_cap: &BoostCapability,
                                locked_amount: u128,
                                locked_time_sec: u128): VToken::VToken<VESTAR::VESTAR> {
        let amount = compute_reward_amount(locked_amount, locked_time_sec);
        VToken::mint_with_cap<VESTAR::VESTAR>(&boost_cap.cap, amount)
    }

    public fun redeem_with_cap<TokenT: store>(boost_cap: &BoostCapability, token: VToken::VToken<VESTAR::VESTAR>) {
        VToken::burn_with_cap<VESTAR::VESTAR>(&boost_cap.cap, token);
    }

    /// The release amount follow the formular
    /// @param locked_time per seconds
    ///
    /// `veSTAR reward = UserLockedSTARAmount * UserLockedSTARDay / 365`
    fun compute_reward_amount(locked_amount: u128, locked_time_sec: u128): u128 {
        let locked_day = locked_time_sec / 60 * 60 * 24;
        locked_amount * locked_day / 365
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
        // let _user_farm_amount :u128 =  1000000000000;
        // let _tatol_farm_amount:u128 =  3064578000000000;
        // let _user_locked_vestar_amount: u128 = 1000000000000;
        // let _total_vestar_amount:u128 =  500000000000000;
        let total_vestar_amount = Token::market_cap<VESTAR::VESTAR>();
        let small_LP = 1000;   
        let lp = user_locked_farm_amount * factor / total_farm_amount;
        let boost_factor =  if( lp  <  small_LP){
                Math::mul_div(user_locked_farm_amount , factor ,  total_farm_amount ) * Math::mul_div(user_locked_vestar_amount , factor ,  total_vestar_amount )  * 1500000 / factor  + 1 * factor
            }else{
                Math::mul_div(user_locked_vestar_amount , factor * 3 , total_vestar_amount ) / Math::mul_div( user_locked_farm_amount , factor * 2 , total_farm_amount ) + 1 * factor
            };
        if(boost_factor > 25 * factor / 10 ){
            boost_factor = 25 * factor / 10;
        };
        
        return (boost_factor as u64)
    }
}
}
