#!/bin/bash

SWAP_ADMIN=$1

#cd starswap-core/aptos目录

### 生成私钥（文件在当前目录）
#aptos key generate --key-type ed25519 --output-file output.key.mainnet.admin

### 连接mainnet网络
#aptos init --profile mainnet-admin --private-key {output.key.admin}  --rest-url https://mainnet.aptoslabs.com --skip-faucet
#${SWAP_ADMIN}

### 手动转gas, 测试APT > 2个

### 编译starswap core
aptos move compile  --package-dir ./core  --named-addresses SwapAdmin=mainnet-admin,SwapFeeAdmin=mainnet-admin

### 部署starswap core
aptos move publish  --package-dir ./core  --named-addresses SwapAdmin=mainnet-admin,SwapFeeAdmin=mainnet-admin --profile mainnet-admin  --included-artifacts none --assume-yes
sleep 5

### 编译starswap farming
aptos move compile  --package-dir ./farming  --named-addresses SwapAdmin=mainnet-admin,SwapFeeAdmin=mainnet-admin

### 部署starswap farming
aptos move publish  --package-dir ./farming  --named-addresses SwapAdmin=mainnet-admin,SwapFeeAdmin=mainnet-admin --profile mainnet-admin  --included-artifacts none --assume-yes
sleep 5


## 初始化合约

### 初始化为最新版本
aptos move run --function-id 'mainnet-admin::UpgradeScripts::genesis_initialize_for_latest_version' --args u128:270000000 u128:8000000 --profile mainnet-admin --assume-yes
sleep 5

### 初始化设置，包括swap、pool、farm和stake
aptos move run --function-id 'mainnet-admin::UpgradeScripts::genesis_initialize_for_setup' --profile mainnet-admin --assume-yes
sleep 5

### 治理币创世初始化
#aptos move run --function-id 'mainnet-admin::TokenSwapGovScript::genesis_initialize'  --profile mainnet-admin --assume-yes
#sleep 5

### 线性释放升级初始化
#aptos move run --function-id 'mainnet-admin::TokenSwapGovScript::linear_initialize'  --profile mainnet-admin --assume-yes
#sleep 5

### 设置swap operation fee rate
#aptos move run --function-id 'mainnet-admin::TokenSwapScripts::set_swap_fee_operation_rate'  --args  u64:10 u64:60  --profile mainnet-admin --assume-yes


### 添加第一个LP交易对

### 管理员创建swap交易对
#aptos move run --function-id 'mainnet-admin::TokenSwapScripts::register_swap_pair' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --profile mainnet-admin --assume-yes
#sleep 5

### 管理员添加代币对流动性（STAR:APT 约等于 400:1,，STAR-APT初始流动性(4000,10)）
#aptos move run --function-id 'mainnet-admin::TokenSwapScripts::add_liquidity' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:4000000000000  u128:1000000000  u128:5000  u128:5000  --profile mainnet-admin --assume-yes



#按STAR-APT X30、APT-USDT X10 来计算：

### 添加第二个LP交易对

### 管理员创建swap交易对
#aptos move run --function-id 'mainnet-admin::TokenSwapScripts::register_swap_pair' --type-args  0x1::aptos_coin::AptosCoin 0xf22bede237a07e121b56d91a491eb7bcdfd1f5907926a9e58338f964a01b17fa::asset::USDT  --profile mainnet-admin --assume-yes
#sleep 5

### 管理员添加代币对流动性（APT:USDT 约等于 1:7，APT:USDT初始流动性(10,70)）
#aptos move run --function-id 'mainnet-admin::TokenSwapScripts::add_liquidity' --type-args  0x1::aptos_coin::AptosCoin 0xf22bede237a07e121b56d91a491eb7bcdfd1f5907926a9e58338f964a01b17fa::asset::USDT  --args  u128:1000000000  u128:70000000  u128:5000  u128:5000  --profile mainnet-admin --assume-yes


## 初始化farm+stake

### 打开boost 开关
#aptos move run --function-id 'mainnet-admin::TokenSwapScripts::set_alloc_mode_upgrade_switch' --args bool:true --profile mainnet-admin --assume-yes
#sleep 5

### 事件初始化
#aptos move run --function-id 'mainnet-admin::TokenSwapFarmScript::initialize_boost_event' --profile mainnet-admin --assume-yes
#sleep 5

### 初始化Farm池global pool info，farm池每秒恒定释放0.27个STAR
#aptos move run --function-id 'mainnet-admin::UpgradeScripts::initialize_global_pool_info' --args u128:270000000 --profile mainnet-admin --assume-yes
#sleep 5

### 管理员创建第一个Farm池
#aptos move run --function-id 'mainnet-admin::TokenSwapFarmScript::add_farm_pool_v2' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args u128:30 --profile mainnet-admin --assume-yes
#sleep 5

### 管理员创建第二个Farm池
#aptos move run --function-id 'mainnet-admin::TokenSwapFarmScript::add_farm_pool_v2' --type-args  0x1::aptos_coin::AptosCoin 0xf22bede237a07e121b56d91a491eb7bcdfd1f5907926a9e58338f964a01b17fa::asset::USDT  --args u128:10 --profile mainnet-admin --assume-yes
#sleep 5

###初始化Syrup池global pool info，syrup池每秒恒定释放0.008个STAR
#aptos move run --function-id 'mainnet-admin::UpgradeScripts::initialize_global_syrup_info' --args u128:8000000 --profile mainnet-admin --assume-yes
#sleep 5

### 管理员创建Syrup
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::add_pool_v2' --type-args ${SWAP_ADMIN}::STAR::STAR --args  u128:30  u64:0 --profile mainnet-admin --assume-yes
#sleep 5

### 添加Syrup池子阶梯倍率
#### 100s
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:100  u64:1 --profile mainnet-admin --assume-yes

#### 1hour
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:3600 u64:1 --profile mainnet-admin --assume-yes

#### 7d
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:604800 u64:1 --profile mainnet-admin --assume-yes
#sleep 5

#### 14d
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:1209600 u64:2 --profile mainnet-admin --assume-yes
#sleep 5

#### 30d
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:2592000 u64:6 --profile mainnet-admin --assume-yes
#sleep 5


#### 60d
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:5184000 u64:9 --profile mainnet-admin --assume-yes
#sleep 5

#### 90d
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:7776000 u64:12 --profile mainnet-admin --assume-yes
#sleep 5

### 验证farm + stake

### 质押流动性
#aptos move run --function-id 'mainnet-admin::TokenSwapFarmScript::stake' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:30622   --profile  mainnet-admin --assume-yes

### 领取奖励
#aptos move run --function-id 'mainnet-admin::TokenSwapFarmScript::harvest' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:0   --profile  mainnet-admin --assume-yes

### 取出Farm质押
#aptos move run --function-id 'mainnet-admin::TokenSwapFarmScript::unstake' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:3100   --profile  mainnet-admin --assume-yes

### 质押Syrup
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::stake' --type-args ${SWAP_ADMIN}::STAR::STAR  --args  u64:100 u128:100000000   --profile  mainnet-admin --assume-yes

### syrup unstake
#aptos move run --function-id 'mainnet-admin::TokenSwapSyrupScript::unstake' --type-args ${SWAP_ADMIN}::STAR::STAR  --args  u64:1   --profile  mainnet-admin --assume-yes

### adjust farm and stake release per second
#aptos move run --function-id 'mainnet-admin::UpgradeScripts::set_farm_pool_release_per_second' --args  u128:180000000 --profile  mainnet-admin --assume-yes
#aptos move run --function-id 'mainnet-admin::UpgradeScripts::set_stake_pool_release_per_second' --args u128:4000000   --profile  mainnet-admin --assume-yes