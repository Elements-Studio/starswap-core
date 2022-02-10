// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x4783d08fb16990bd35d83f3e23bf93b8 {

module TokenSwapConfig {
    use 0x1::Config;
    use 0x1::Signer;
    use 0x1::Errors;
    use 0x1::Vector;
    use 0x1::Option;

    // Numerator and denumerator default fixed value
    const DEFAULT_OPERATION_NUMERATOR: u64 = 10;
    const DEFAULT_OPERATION_DENUMERATOR: u64 = 60;
    const DEFAULT_POUNDAGE_NUMERATOR: u64 = 3;
    const DEFAULT_POUNDAGE_DENUMERATOR: u64 = 1000;

    const SWAP_FEE_SWITCH_ON: bool = true;
    const SWAP_FEE_SWITCH_OFF: bool = false;

    const ERROR_NOT_HAS_PRIVILEGE: u64 = 101;

    struct SwapFeePoundageConfig<X, Y> has copy, drop, store {
        numerator: u64,
        denumerator: u64,
    }

    struct SwapFeeOperationConfig has copy, drop, store {
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
        multiplier: u64) {
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

    public fun admin_address(): address {
        @0x4783d08fb16990bd35d83f3e23bf93b8
    }

    public fun fee_address(): address {
        @0x0a4183ac9335a9f5804014eab01c0abc
    }

    public fun assert_admin(signer: &signer) {
        assert(Signer::address_of(signer) == admin_address(), Errors::invalid_state(ERROR_NOT_HAS_PRIVILEGE));
    }

    public fun get_swap_fee_switch(): bool {
        SWAP_FEE_SWITCH_ON
    }
}
}