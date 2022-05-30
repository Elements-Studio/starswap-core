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

