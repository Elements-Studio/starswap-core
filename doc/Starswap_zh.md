## Starswap

Starswap 的代码分为 7 个大类：
- gov
- swap
- farm
- boost
- upgrade
- farm
- common

### Gov 
其中 Gov 是 Starswap 国库相关的所有代码，包含了 STAR 的初始化、释放等
#### STAR.move
STAR.move 内部包括多个接口：
- init - 初始化接口
- mint - mint 接口
- is_star - 判断传入泛型否是STAR
- assert_genesis_address - 断言传入的 signer 是否是 STAR 的创建者
- token_address - 获得 STAR 的创建者
- precision - 获得 STAR 的精度

```
    public fun init(account: &signer) {
    }

    public fun mint(account: &signer, amount: u128) {
    }

    /// Returns true if `TokenType` is `STAR::STAR`
    public fun is_star<TokenType: store>(): bool {
    }

    public fun assert_genesis_address(account : &signer) {
    }

    /// Return STAR token address.
    public fun token_address(): address {
    }

    /// Return STAR precision.
    public fun precision(): u8 {
    }
```

#### TokenSwapGov.move
TokenSwapGov.move 包含了有关 STAR 国库的代码，具体管理了 Farm、Syrup、Community、IDO、DeveloperFund、ProtocolTreasury 几种类型的国库
国库的结构经历了升级：
旧版结构：
旧版结构仅支持 genesis 释放，并不能实现线性释放的特性
```
    struct GovTreasury<phantom PoolType> has key, store {
        treasury: Token::Token<STAR::STAR>,
        locked_start_timestamp: u64,    // locked start time
        locked_total_timestamp: u64,    // locked total time
    }
```
新版结构：
新版结构兼顾了 genesis 释放和 线性国库的释放特性，增加字段用来标识线性国库的总量、线性国库、genesis 国库
```
    struct GovTreasuryV2<phantom PoolType> has key,store{
        linear_total:u128,                        
        linear_treasury:Token::Token<STAR::STAR>,
        genesis_treasury:Token::Token<STAR::STAR>,
        locked_start_timestamp:u64,         // locked start time
        locked_total_timestamp:u64,         // locked total time
    }
```
TokenSwapGov.move 的接口有 4 类：
- 初始化
- 提取
- 升级
- 查看

初始化：
Swap 启动时的初始化，内部初始化 IDO、Farm、Syrup 、Community国库用于项目启动
```
public fun genesis_initialize(account: &signer){}
```
Swap 将国库升级为线性释放国库的初始化，内部将旧版国库转换为新版国库
```
public fun linear_initialize(account: &signer) acquires GovTreasury {}
```
提取：
用于提取新版国库中的 genesis_treasury 部分、可用于 Community 国库的提取
```
public fun dispatch<PoolType: store>(account: &signer, acceptor: address, amount: u128) acquires GovTreasuryV2 ,GovTreasuryEvent {}
```
用于 Commuity 线性释放国库的提取
```
public fun linear_withdraw_community(account:&signer,to:address,amount:u128) acquires GovTreasuryV2,GovTreasuryEvent{}
```
用于 developerfund 线性释放国库的提取
```
public fun linear_withdraw_developerfund(account:&signer,to:address,amount:u128) acquires GovTreasuryV2,GovTreasuryEvent{}
```
用于 Farm 线性释放国库的提取
```
public fun linear_withdraw_farm(account:&signer,to:address,amount:u128) acquires GovTreasuryV2,GovTreasuryEvent{}
```
用于 Syrup 线性释放国库的提取
```
public fun linear_withdraw_syrup(account:&signer,to:address,amount:u128) acquires GovTreasuryV2,GovTreasuryEvent{}
```
升级:
已经弃用：升级 GovPoolType 时使用
```
public(script) fun upgrade_pool_type_genesis(signer: signer) {}
```
升级/创建协议国库
```
public(script) fun upgrade_dao_treasury_genesis(signer: signer) {}
```
#### TokenSwapGovPoolType.move
包括几种国库的类型，并使用他们作为 Swap 的区分类型
```
    struct PoolTypeFarmPool has key, store {}

    struct PoolTypeSyrup has key, store {}

    struct PoolTypeCommunity has key, store {}

    struct PoolTypeIDO has key, store {}

    struct PoolTypeDeveloperFund has key, store {}

    struct PoolTypeProtocolTreasury has key, store {}
```
#### TokenSwapGovScript.move
将 Swap Gov 相关的脚本暴露出来方便调用,作用与 TokenSwapGov.move 中同名函数的功能相同
```
    public(script) fun genesis_initialize(account: signer) {}

    /// Harverst STAR by given pool type, call ed by user
    public(script) fun dispatch<PoolType: store>(account: signer, acceptor: address, amount: u128) {}

    ///Initialize the linear treasury by Starswap Ecnomic Model list
    public(script) fun linear_initialize(account: signer) {}

    /// Linear extraction of Farm treasury
    public(script) fun linear_withdraw_farm(account: signer , amount:u128 ) {}

    /// Linear extraction of Syrup treasury
    public(script) fun linear_withdraw_syrup(account: signer , amount:u128 ) {}

    /// Linear extraction of Community treasury
    public(script) fun linear_withdraw_community(account: signer ,to:address,amount :u128) {}
    
    /// Linear extraction of developerfund treasury
    public(script) fun linear_withdraw_developerfund(account: signer ,to:address,amount :u128) {}
```

### Swap 
#### TokenSwapConfig.move
保存 Starswap 相关的所有配置，通过 0x1 的 Config 模块实现
- SwapFeePoundageConfig - 交易手续费配置
- SwapFeeOperationConfigV2 - 手续费分成配置
- SwapStepwiseMultiplierConfig - Swap Syrup 质押时长倍率配置
- SwapFeeSwitchConfig - Swap 交易手续费自动转换
- SwapGlobalFreezeSwitch - 冻结开关
- AllocModeUpgradeSwitch - Boost 升级开关
- WhiteListBoostSwitch - 白名单开关
#### TokenSwapFee.move
Swap 交易手续费的相关代码
- initialize_token_swap_fee - Swap 交易费初始化
- init_swap_oper_fee_config - 设置 Swap 交易费分成比例
- handle_token_swap_fee - 交易手续费处理
- intra_handle_token_swap_fee - 交易手续费处理
- emit_swap_fee_event - 手续费事件
- swap_fee_direct_deposit - 手续费支付给 管理员 或者输入到 LP 中
- swap_fee_swap - 将 X 换为  FeeToken 支付给管理员
#### TokenSwapOracleLibrary.move
价格预言机，可以保存一定时间内的平均价格
- current_block_timestamp - 获取当前的区块时间
- current_cumulative_prices_v2 - 获取一定时间内两个Token平均价格
current_cumulative_prices_v2 相对于 current_cumulative_prices 增加了根据区块时间来更新返回价格
```
    /// TWAP price oracle, include update price accumulators, on the first call per block
    /// return U256 with precision
    public fun current_cumulative_prices_v2<X: copy + drop + store, Y: copy + drop + store>(): (U256, U256, u64) {
        let block_timestamp = current_block_timestamp();
        let (price_x_cumulative, price_y_cumulative, last_block_timestamp) = TokenSwapRouter::get_cumulative_info<X, Y>();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        if (last_block_timestamp != block_timestamp) {
            let (x_reserve, y_reserve) = TokenSwapRouter::get_reserves<X, Y>();
            if (x_reserve !=0 && y_reserve != 0){
                let time_elapsed = block_timestamp - last_block_timestamp;
                // counterfactual
                let new_price_x_cumulative = U256::mul(FixedPoint128::to_u256(FixedPoint128::div(FixedPoint128::encode(y_reserve), x_reserve)), U256::from_u64(time_elapsed));
                let new_price_y_cumulative = U256::mul(FixedPoint128::to_u256(FixedPoint128::div(FixedPoint128::encode(x_reserve), y_reserve)), U256::from_u64(time_elapsed));
                price_x_cumulative = U256::add(price_x_cumulative, new_price_x_cumulative);
                price_y_cumulative = U256::add(price_y_cumulative, new_price_y_cumulative);
            };
        };
        (price_x_cumulative, price_y_cumulative, block_timestamp)
    }
```

#### TokenSwapLibrary.move
作为 Swap 底层公共库，与代币具体类型无关
- quote - 提供流动性时给定 代币 X 数量，返回需要的 代币 Y 的数量
- get_amount_in - 给定输出的 代币 数量，求需要输入的代币数
- get_amount_out - 给定输入的 代币 数量，求输出的代币数
- get_amount_in_without_fee - 无费率时给定输出的 代币 数量，求需要输入的代币数
- get_amount_out_without_fee - 无费率时给定输入的 代币 数量，求输出的代币数

#### TokenSwap.move
Starswap 的 swap功能实现
- maybe_init_event_handle - 尝试初始化事件
- swap_pair_exists - 检查币对是否存在
- register_swap_pair - 注册币对
- mint - 将X,Y币对放入流动池中并 mint 对应币对的 LP Token 
- burn  - 将 X,Y 币对从流动池中取出并 burn 对应的LP Token
- get_reserves - 获取一个币对的 X,Y 流动性数量
- get_cumulative_info - 获取 一个币对累计的价格信息
- swap - 交换两个代币
- compare_token - 对比两个代币
- assert_is_token - 检测 传入的泛型是否是 TokenType 类型
- return_back_to_lp_pool - 将 fee 注入到LP中 
- cacl_actual_swap_fee_operation_rate - 计算费率
- mint_and_emit_event - 注入流动性并mint LPToken 发出事件
- burn_and_emit_event - 提取流动性并 burn LPToken 发出事件
- swap_and_emit_event - Swap 代币 并发出事件
#### TokenSwapRouter.move
用来调换币对的顺序，方便调用底层的函数
- swap_pair_exists - 检查币对是否存在
- swap_pair_token_auto_accept - 调用者接收该币对
- register_swap_pair - 注册币对
- add_liquidity - 添加指定币对的流动性
- remove_liquidity - 移除指定币对的流动性
- swap_exact_token_for_token - 指定最小换出代币的交换
- swap_token_for_exact_token - 指定最大输入代币的交换 
- liquidity - 获取 指定用户指定币对的 LP Token 数量
- total_liquidity - 获取指定币对的 LP Token 数量
- get_reserves - 获取一个币对的 X,Y 流动性数量
- get_cumulative_info - 获取 一个币对累计的价格信息
- withdraw_liquidity_token - 提取指定数量的指定代币对的 LP Token
- deposit_liquidity_token - 输入指定数量的指定代币对的 LP Token
- get_poundage_rate - 获取指定币对的手续费比例
- get_swap_fee_operation_rate_v2 - 获取指定币对的手续费流向比例
- set_swap_fee_operation_rate_v2 - 设置指定币对的手续费流向比例
- set_fee_auto_convert_switch - 设置 Fee 自动兑换开关
- set_global_freeze_switch - 设置冻结开关
- set_alloc_mode_upgrade_switch - 设置 boost 升级开关
- set_white_list_boost_switch - 设置 boost 白名单开关
#### TokenSwapFarm.move
Swap 的 Farm 功能层 ，包含了大多数的 Farm 操作
- initialize_farm_pool - 初始化 Farm 国库
- initialize_global_pool_info - 升级 Farm 
- add_farm - Boost 之前的 添加 Farm池
- add_farm_v2 - Boost 之后的 添加 Farm 池
- extend_farm_pool - 升级Boost 开关前的 Farm 池
- get_farm_multiplier - 获得池子的倍率
- set_farm_alloc_point - 设置池子的分配占比
- deposit - 存入 Token 到 Farm 的国库中
- stake - 将指定的币对流动性质押到 Farm 池中
- unstake -  将指定的币对流动性从 Farm 池取出
- harvest - harvest 指定的 Farm 池中的奖励
- boost - 加速指定币对的 Farm 池
- get_treasury_balance - 查看 Farm 的国库中的余额
- lookup_gain - 获取指定币对 Farm 的 APY
- query_info_v2 - 获取 Farm 池子的信息
- query_total_stake - 获指定币对总质押数
- query_stake - 获取指定地址的指定币对质押数
- query_release_per_second - 获取指定币对 Farm 池每秒释放量
- query_global_pool_info - 获取全部 Farm 池子的信息
#### TokenSwapFarmBoost.move
Swap 的 Farm Boost 相关操作
- initialize_boost_event - 初始化 Boost 事件
- set_treasury_cap - 设置国库能力
- get_default_boost_factor_scale - 获取默认的boost 倍率
- get_boost_factor - 查询某个地址的boost 倍率
- get_boost_locked_vestar_amount - 查询某个地址的VeSTAR质押量
- calculate_boost_weight - 计算加速占比重
- predict_boost_factor - 预测 boost 倍率
- boost_to_farm_pool - 对指定币对的 Farm 质押
- unboost_from_farm_pool - 取消指定币对的 Farm 质押
#### TokenSwapFarmRouter.move
Swap 的 Farm 路由相关操作，主要用于币对查找
- add_farm_pool - Boost 前增加指定币对的Farm池子
- add_farm_pool_v2 - Boost 后增加指定币对的Farm池子
- stake - 质押指定币对LP Token 到指定Farm 池
- unstake - 取消质押指定币对 LP Token
- harvest - 提取质押指定币对 LP Token 的奖励
- boost - 加速指定币对的 Farm 池子
- set_farm_multiplier - 设置指定币对 Farm 池子的倍率
- set_farm_alloc_point - 设置指定币对 Farm 池子的倍率
- lookup_gain - 获取指定币对 Farm 的 APY
- query_total_stake - 获指定币对总质押数
- query_stake - 获取指定地址的指定币对质押数
- query_info_v2 - 获取 Farm 池子的信息
- query_release_per_second - 获取指定币对 Farm 池每秒释放量
- get_farm_multiplier - 获得池子的倍率
- query_global_pool_info - 获取全部 Farm 池子的信息
- get_boost_factor - 获取某个地址的 boost 倍率
#### TokenSwapFarmScript.move
用于合约调用的脚本函数
- add_farm_pool - Boost 前增加指定币对的Farm池子
- add_farm_pool_v2 - Boost 后增加指定币对的Farm池子
- stake - 质押指定币对LP Token 到指定Farm 池
- unstake - 取消质押指定币对 LP Token
- harvest - 提取质押指定币对 LP Token 的奖励
- boost - 加速指定币对的 Farm 池子
- set_farm_multiplier - 设置指定币对 Farm 池子的倍率
- set_farm_alloc_point - 设置指定币对 Farm 池子的倍率
- initialize_boost_event - 初始化 Boost 事件
#### TokenSwapSyrup.move
Swap 的 Syrup 功能层 ，包含了大多数的 Syrup 操作
- initialize - Syrup 的初始化
- add_pool_v2 - Boost 后加新 Syrup 池
- set_release_per_second - 设置 Syrup 池每秒释放量
- set_alive - 设置 Syrup 池的状态
- update_allocation_point - 设置 Syrup 池的分配占比
- deposit - 注入 Token 到 Syrup 国库中
- get_treasury_balance - 查看 Syrup 的国库中的余额
- stake - 质押指定币 到 Syrup 池
- unstake - 取消质押指定币的 Syrup 池
- get_stake_info - 获取某个地址某个币的某次质押状态
- query_total_stake - 获取某个币 Syrup 总质押状态
- query_expect_gain - 获取某个地址某个币某次质押的预期收益
- query_stake_list - 获取某个地址某个币所有的质押
- query_release_per_second - 获取指定币 Syrup 池每秒释放量
- query_pool_info_v2 - 获取指定币 Syrup 的状态
- get_global_stake_id - 获取某个地址的当前最大质押ID
- pledage_time_to_multiplier - 获取质押时间对应的倍率
- upgrade_syrup_global - Syrup 的 Boost 升级
- extend_syrup_pool - 升级 Syrup 池结构
#### TokenSwapSyrupScript.move
- add_pool - 加新 Syrup 池
- set_release_per_second - 设置 Syrup 池每秒释放量
- set_alive - 设置 Syrup 池的状态
- stake - 质押指定币 到 Syrup 池
- unstake - 取消质押指定币的 Syrup 池
- take_vestar_by_stake_id - Boost 开启前的 Syrup 获取 VeSTAR
- put_stepwise_multiplier - 设置质押时间以及对应的倍率
#### TokenSwapVestarMinter.move
Swap层关于VeSTAR的相关操作
- init - 初始化 VeSTAR 
- mint_with_cap_T - 通过capability Mint 指定Token
- burn_with_cap_T - 通过capability Burn 指定Token
- value - 获得指定账号下 VESTAR 的数量
- value_of_id - 获得在指定账号下的指定Stake 获得的VeSTAR
- value_of_id_by_token - 获得在指定账号下的指定Stake 获得的指定 Token
- withdraw_with_cap - 通过 capability 提取 VESTAR
- deposit_with_cap - 通过 capability 注入 VESTAR
- maybe_upgrade_records - 升级 record list
#### TokenSwapVestarRouter.move
Vestar的功能整合路由
- initialize_global_syrup_info - 初始化 Boost 后的 VeSTAR 
- stake_hook - 质押时Mint VeSTAR
- stake_hook_with_id - 给指定的 ID Syrup Mint VeSTAR
- unstake_hook - 取消质押时burn VeSTAR
- exists_record - 查看是否有 Record 表格
