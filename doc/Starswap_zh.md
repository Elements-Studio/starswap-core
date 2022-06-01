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