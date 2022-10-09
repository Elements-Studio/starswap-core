// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {

module TokenSwapConfig {
    use StarcoinFramework::Config;
    use StarcoinFramework::Signer;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Option;

    // Numerator and denumerator default fixed value
    const DEFAULT_OPERATION_NUMERATOR: u64 = 10;
    const DEFAULT_OPERATION_DENUMERATOR: u64 = 60;
    const DEFAULT_POUNDAGE_NUMERATOR: u64 = 3;
    const DEFAULT_POUNDAGE_DENUMERATOR: u64 = 1000;

    const DEFAULT_SWAP_FEE_AUTO_CONVERT_SWITCH: bool = false;
    const DEFAULT_SWAP_GLOBAL_FREEZE_SWITCH: bool = false;
    const DEFAULT_SWAP_ALLOC_MODE_UPGRADE_SWITCH: bool = false;
    const DEFAULT_WHITE_LIST_BOOST_SWITCH: bool = false;
    const DEFAULT_WHITE_LIST_BOOST_PUBKEY: vector<u8> = x"d6da1bea14990ad936a848c2a375a2c105d5038ce726ed03f8700998c4e840b5";
    const SWAP_FEE_SWITCH_ON: bool = true;
    const SWAP_FEE_SWITCH_OFF: bool = false;

    const ERROR_NOT_HAS_PRIVILEGE: u64 = 101;
    const ERROR_GLOBAL_FREEZE: u64 = 102;

    struct SwapFeePoundageConfig<phantom X, phantom Y> has copy, drop, store {
        numerator: u64,
        denumerator: u64,
    }

    struct SwapFeeOperationConfig has copy, drop, store {
        numerator: u64,
        denumerator: u64,
    }
    struct SwapFeeOperationConfigV2<phantom X, phantom Y> has copy, drop, store {
        numerator: u64,
        denumerator: u64,
    }

    struct StepwiseMutiplier has copy, drop, store {
        interval_sec: u64,
        multiplier: u64,
    }

    struct SwapStepwiseMultiplierConfig has copy, drop, store {
        list: vector<StepwiseMutiplier>,
    }
    
    struct SwapFeeSwitchConfig has copy, drop, store {
        auto_convert_switch: bool,
    }

    struct SwapGlobalFreezeSwitch has copy, drop, store {
        freeze_switch: bool,
    }

    struct AllocModeUpgradeSwitch has copy, drop, store {
        upgrade_switch: bool,
    }

    struct WhiteListBoostSwitch has copy, drop, store {
        white_list_switch: bool,
        white_list_pubkey: vector<u8>,
    }

    public fun get_swap_fee_operation_rate(): (u64, u64) {
        if (Config::config_exist_by_address<SwapFeeOperationConfig>(admin_address())) {
            let conf = Config::get_by_address<SwapFeeOperationConfig>(admin_address());
            let numerator: u64 = conf.numerator;
            let denumerator: u64 = conf.denumerator;
            (numerator, denumerator)
        } else {
            (DEFAULT_OPERATION_NUMERATOR, DEFAULT_OPERATION_DENUMERATOR)
        }
    }
    
    /// Swap fee allocation mode: LP Providor 5/6, Operation management 1/6
    public fun get_swap_fee_operation_rate_v2<X: copy + drop + store,
                                              Y: copy + drop + store>(): (u64, u64) {

        if (Config::config_exist_by_address<SwapFeeOperationConfigV2<X, Y>>(admin_address())) {
            let conf = Config::get_by_address<SwapFeeOperationConfigV2<X, Y>>(admin_address());
            let numerator: u64 = conf.numerator;
            let denumerator: u64 = conf.denumerator;
            (numerator, denumerator)
        } else {
            (DEFAULT_OPERATION_NUMERATOR, DEFAULT_OPERATION_DENUMERATOR)
        }
    }

    /// Swap fee allocation mode: LP Providor 5/6, Operation management 1/6
    /// Poundage number of liquidity token pair
    public fun get_poundage_rate<X: copy + drop + store,
                                 Y: copy + drop + store>(): (u64, u64) {

        if (Config::config_exist_by_address<SwapFeePoundageConfig<X, Y>>(admin_address())) {
            let conf = Config::get_by_address<SwapFeePoundageConfig<X, Y>>(admin_address());
            let numerator: u64 = conf.numerator;
            let denumerator: u64 = conf.denumerator;
            (numerator, denumerator)
        } else {
            (DEFAULT_POUNDAGE_NUMERATOR, DEFAULT_POUNDAGE_DENUMERATOR)
        }
    }

    /// Get fee auto convert switch config
    public fun get_fee_auto_convert_switch(): bool {
        if (Config::config_exist_by_address<SwapFeeSwitchConfig>(admin_address())) {
            let conf = Config::get_by_address<SwapFeeSwitchConfig>(admin_address());
            conf.auto_convert_switch
        } else {
            DEFAULT_SWAP_FEE_AUTO_CONVERT_SWITCH
        }
    }

    /// Set fee rate for operation rate, only admin can call
    public fun set_swap_fee_operation_rate(signer: &signer, num: u64, denum: u64) {
        assert_admin(signer);
        let config = SwapFeeOperationConfig{
            numerator: num,
            denumerator: denum,
        };
        if (Config::config_exist_by_address<SwapFeeOperationConfig>(admin_address())) {
            Config::set<SwapFeeOperationConfig>(signer, config);
        } else {
            Config::publish_new_config<SwapFeeOperationConfig>(signer, config);
        }
    }

    /// Set fee rate for operation_v2 rate, only admin can call
    public fun set_swap_fee_operation_rate_v2<X: copy + drop + store,
                                              Y: copy + drop + store>(signer: &signer,
                                                                      num: u64,
                                                                      denum: u64) {
        assert_admin(signer);

        let config = SwapFeeOperationConfigV2<X, Y>{
            numerator: num,
            denumerator: denum,
        };
        if (Config::config_exist_by_address<SwapFeeOperationConfigV2<X, Y>>(admin_address())) {
            Config::set<SwapFeeOperationConfigV2<X, Y>>(signer, config);
        } else {
            Config::publish_new_config<SwapFeeOperationConfigV2<X, Y>>(signer, config);
        }
    }

    /// Set fee rate for poundage rate, only admin can call
    public fun set_poundage_rate<X: copy + drop + store,
                                 Y: copy + drop + store>(signer: &signer,
                                                         num: u64,
                                                         denum: u64) {
        assert_admin(signer);

        let config = SwapFeePoundageConfig<X, Y>{
            numerator: num,
            denumerator: denum,
        };
        if (Config::config_exist_by_address<SwapFeePoundageConfig<X, Y>>(admin_address())) {
            Config::set<SwapFeePoundageConfig<X, Y>>(signer, config);
        } else {
            Config::publish_new_config<SwapFeePoundageConfig<X, Y>>(signer, config);
        }
    }

    public fun put_stepwise_multiplier(
        signer: &signer,
        interval_sec: u64,
        multiplier: u64
    ) {
        assert_admin(signer);
        
        if (Config::config_exist_by_address<SwapStepwiseMultiplierConfig>(admin_address())) {
            let conf = Config::get_by_address<SwapStepwiseMultiplierConfig>(admin_address());
            let idx = find_mulitplier_idx(&mut conf.list, interval_sec);

            if (Option::is_some(&idx)) {
                let step_mutiplier = Vector::borrow_mut<StepwiseMutiplier>(&mut conf.list, Option::destroy_some<u64>(idx));
                step_mutiplier.multiplier = multiplier;
            } else {
                Vector::push_back(&mut conf.list, StepwiseMutiplier {
                    interval_sec,
                    multiplier,
                });
            };
            // Reset to config
            Config::set<SwapStepwiseMultiplierConfig>(signer, SwapStepwiseMultiplierConfig {
                list: *&conf.list
            });

        } else {
            let step_mutiplier = Vector::empty<StepwiseMutiplier>();
            Vector::push_back(&mut step_mutiplier, StepwiseMutiplier {
                interval_sec,
                multiplier,
            });
            Config::publish_new_config<SwapStepwiseMultiplierConfig>(signer, SwapStepwiseMultiplierConfig {
                list: step_mutiplier,
            });
        }
    }

    public fun get_stepwise_multiplier(interval_sec: u64): u64 {
        if (Config::config_exist_by_address<SwapStepwiseMultiplierConfig>(admin_address())) {
            let conf = Config::get_by_address<SwapStepwiseMultiplierConfig>(admin_address());
            let idx = find_mulitplier_idx(&conf.list, interval_sec);
            if (Option::is_some(&idx)) {
                let item = Vector::borrow<StepwiseMutiplier>(&conf.list, Option::destroy_some<u64>(idx));
                return item.multiplier
            } else {
                1
            }
        } else {
            1
        }
    }

    public fun get_stepwise_multiplier_list() : (
        vector<u64>, // time
        vector<u64>  // multiplier
    ) {
        let time_list = Vector::empty<u64>();
        let multiplier_list = Vector::empty<u64>();
        if (!Config::config_exist_by_address<SwapStepwiseMultiplierConfig>(admin_address())) {
            return (time_list, multiplier_list)
        };

        let conf = Config::get_by_address<SwapStepwiseMultiplierConfig>(admin_address());
        loop {
            if (Vector::is_empty(&conf.list)) {
                break
            };
            let s = Vector::pop_back(&mut conf.list);
            Vector::push_back(&mut time_list, s.interval_sec);
            Vector::push_back(&mut multiplier_list, s.multiplier);
        };
        (time_list, multiplier_list)
    }

    /// Check is the time second has in stepwise multiplier list
    public fun has_in_stepwise(time_sec: u64) : bool {
        if (!Config::config_exist_by_address<SwapStepwiseMultiplierConfig>(admin_address())) {
            return false
        };

        let conf = Config::get_by_address<SwapStepwiseMultiplierConfig>(admin_address());
        let idx = find_mulitplier_idx(&conf.list, time_sec);
        Option::is_some<u64>(&idx)
    }

    fun find_mulitplier_idx(c: &vector<StepwiseMutiplier>, interval_sec: u64): Option::Option<u64> {
        let len = Vector::length(c);
        if (len == 0) {
            return Option::none()
        };
        let idx = len - 1;
        loop {
            let el = Vector::borrow(c, idx);
            if (el.interval_sec == interval_sec) {
                return Option::some<u64>(idx)
            };
            if (idx == 0) {
                return Option::none<u64>()
            };
            idx = idx - 1;
        }
    }
    
    /// Set fee auto convert switch config, only admin can call
    public fun set_fee_auto_convert_switch(signer: &signer, auto_convert_switch: bool) {
        assert_admin(signer);
        
        let config = SwapFeeSwitchConfig{
            auto_convert_switch,
        };
        if (Config::config_exist_by_address<SwapFeeSwitchConfig>(admin_address())) {
            Config::set<SwapFeeSwitchConfig>(signer, config);
        } else {
            Config::publish_new_config<SwapFeeSwitchConfig>(signer, config);
        }
    }

    /// Global freeze
    public fun set_global_freeze_switch(signer: &signer, freeze_switch: bool) {
        assert_admin(signer);

        let config = SwapGlobalFreezeSwitch{
            freeze_switch,
        };
        if (Config::config_exist_by_address<SwapGlobalFreezeSwitch>(admin_address())) {
            Config::set<SwapGlobalFreezeSwitch>(signer, config);
        } else {
            Config::publish_new_config<SwapGlobalFreezeSwitch>(signer, config);
        }
    }

    /// Global freeze
    public fun get_global_freeze_switch(): bool {
        if (Config::config_exist_by_address<SwapGlobalFreezeSwitch>(admin_address())) {
            let conf = Config::get_by_address<SwapGlobalFreezeSwitch>(admin_address());
            conf.freeze_switch
        } else {
            DEFAULT_SWAP_GLOBAL_FREEZE_SWITCH
        }
    }

    /// Pool alloc mode upgrade switch
    public fun set_alloc_mode_upgrade_switch(signer: &signer, upgrade_switch: bool) {
        assert_admin(signer);

        let config = AllocModeUpgradeSwitch{
            upgrade_switch,
        };
        if (Config::config_exist_by_address<AllocModeUpgradeSwitch>(admin_address())) {
            Config::set<AllocModeUpgradeSwitch>(signer, config);
        } else {
            Config::publish_new_config<AllocModeUpgradeSwitch>(signer, config);
        }
    }

    ///  Pool alloc mode upgrade switch
    public fun get_alloc_mode_upgrade_switch(): bool {
        if (Config::config_exist_by_address<AllocModeUpgradeSwitch>(admin_address())) {
            let conf = Config::get_by_address<AllocModeUpgradeSwitch>(admin_address());
            conf.upgrade_switch
        } else {
            DEFAULT_SWAP_ALLOC_MODE_UPGRADE_SWITCH
        }
    }

    ///  White list boost switch
    public fun set_white_list_boost_switch(signer: &signer, white_list_switch: bool, white_list_pubkey:vector<u8>){
        assert_admin(signer);
        let config = WhiteListBoostSwitch{
            white_list_switch,
            white_list_pubkey,
        };
        if (Config::config_exist_by_address<WhiteListBoostSwitch>(admin_address())) {
            Config::set<WhiteListBoostSwitch>(signer, config);
        } else {
            Config::publish_new_config<WhiteListBoostSwitch>(signer, config);
        }
    }

    ///  White list boost switch
    public fun get_white_list_boost_switch():(bool,vector<u8>){
        if (Config::config_exist_by_address<WhiteListBoostSwitch>(admin_address())) {
            let conf = Config::get_by_address<WhiteListBoostSwitch>(admin_address());
            ( conf.white_list_switch , *&conf.white_list_pubkey )
        } else {
            (DEFAULT_WHITE_LIST_BOOST_SWITCH, DEFAULT_WHITE_LIST_BOOST_PUBKEY)
        }
    }

    public fun admin_address(): address {
        @SwapAdmin
    }

    public fun fee_address(): address {
        @SwapFeeAdmin
    }

    public fun assert_admin(signer: &signer) {
        assert!(Signer::address_of(signer) == admin_address(), Errors::invalid_state(ERROR_NOT_HAS_PRIVILEGE));
    }

    public fun assert_global_freeze() {
        assert!(!get_global_freeze_switch(), Errors::invalid_state(ERROR_GLOBAL_FREEZE));
    }

    public fun get_swap_fee_switch(): bool {
        SWAP_FEE_SWITCH_ON
    }


}
}