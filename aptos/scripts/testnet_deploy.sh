#!/bin/bash

SWAP_ADMIN=$1

#cd starswap-core/aptos目录

### 生成私钥（文件在当前目录）
#aptos key generate --key-type ed25519 --output-file output.key.admin

### 连接testnet网络
#aptos init --profile testnet-admin --private-key {output.key.admin}  --rest-url https://testnet.aptoslabs.com --skip-faucet
#${SWAP_ADMIN}

### 手动转gas, 测试APT > 6个

#cd aptos目录，为了方便，依赖的项目临时使用swap同样的地址来测试

### 编译依赖项目usdt-dep
aptos move compile  --package-dir ./bridge-mock  --named-addresses bridge=testnet-admin

### 部署依赖项目usdt-dep
aptos move publish  --package-dir ./bridge-mock  --named-addresses bridge=testnet-admin --profile testnet-admin  --included-artifacts sparse --assume-yes
sleep 5

### 编译依赖项目u256
#aptos move compile  --package-dir ./u256-dep  --named-addresses u256=testnet-admin

### 部署依赖项目u256
#aptos move publish  --package-dir ./u256-dep  --named-addresses u256=testnet-admin --profile testnet-admin  --included-artifacts sparse --assume-yes

### 编译starswap core
aptos move compile  --package-dir ./core  --named-addresses SwapAdmin=testnet-admin,SwapFeeAdmin=testnet-admin

### 部署starswap core
aptos move publish  --package-dir ./core  --named-addresses SwapAdmin=testnet-admin,SwapFeeAdmin=testnet-admin --profile testnet-admin  --included-artifacts none --assume-yes
sleep 5

### 编译starswap farming
aptos move compile  --package-dir ./farming  --named-addresses SwapAdmin=testnet-admin,SwapFeeAdmin=testnet-admin

### 部署starswap farming
aptos move publish  --package-dir ./farming  --named-addresses SwapAdmin=testnet-admin,SwapFeeAdmin=testnet-admin --profile testnet-admin  --included-artifacts none --assume-yes
sleep 5


### 查看profile
#aptos config show-profiles

## 初始化合约

### USDT初始化
aptos move run --function-id 'testnet-admin::asset::init' --profile testnet-admin --assume-yes
sleep 5

### 初始化为最新版本
aptos move run --function-id 'testnet-admin::UpgradeScripts::genesis_initialize_for_latest_version' --args u128:270000000 u128:8000000 --profile testnet-admin --assume-yes
sleep 5

### 初始化设置，包括swap、pool、farm和stake
aptos move run --function-id 'testnet-admin::UpgradeScripts::genesis_initialize_for_setup' --profile testnet-admin --assume-yes
sleep 5

### 治理币创世初始化
#aptos move run --function-id 'testnet-admin::TokenSwapGovScript::genesis_initialize'  --profile testnet-admin --assume-yes
#sleep 5

### 升级国库
#aptos move run --function-id 'testnet-admin::TokenSwapGov::upgrade_dao_treasury_genesis'  --profile testnet-admin --assume-yes

### 线性释放升级初始化
#aptos move run --function-id 'testnet-admin::TokenSwapGovScript::linear_initialize'  --profile testnet-admin --assume-yes
#sleep 5

### 设置swap operation fee rate
#aptos move run --function-id 'testnet-admin::TokenSwapScripts::set_swap_fee_operation_rate'  --args  u64:10 u64:60  --profile testnet-admin --assume-yes

### 管理员创建swap交易对
#aptos move run --function-id 'testnet-admin::TokenSwapScripts::register_swap_pair' --type-args ${SWAP_ADMIN}::STAR::STAR ${SWAP_ADMIN}::asset::USDT  --profile testnet-admin --assume-yes

##  准备测试Token

 ###提取STAR
#aptos move run --function-id 'testnet-admin::TokenSwapGovScript::dispatch' --type-args ${SWAP_ADMIN}::TokenSwapGovPoolType::PoolTypeCommunity --args address:${SWAP_ADMIN} u128:50000000000000  --profile testnet-admin --assume-yes
aptos move run --function-id 'testnet-admin::TokenSwapGovScript::linear_withdraw_farm'  --args u128:800000000000000  --profile testnet-admin --assume-yes
sleep 5

### mint USDT
aptos move run --function-id 'testnet-admin::asset::mint'  --args u128:50000000000  --profile testnet-admin --assume-yes
sleep 5

### 管理员添加代币对流动性（STAR:USDT 约等于 60:1,，STAR-USDT初始流动性(30000,500)）
#aptos move run --function-id 'testnet-admin::TokenSwapScripts::add_liquidity' --type-args ${SWAP_ADMIN}::STAR::STAR ${SWAP_ADMIN}::asset::USDT  --args  u128:30000000000000  u128:500000000  u128:5000  u128:5000  --profile testnet-admin --assume-yes


### 添加第二个LP交易对

### 管理员创建swap交易对
#aptos move run --function-id 'testnet-admin::TokenSwapScripts::register_swap_pair' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --profile testnet-admin --assume-yes
#sleep 5

### 管理员添加代币对流动性（STAR:APT 约等于 400:1,，STAR-APT初始流动性(400,1)）
aptos move run --function-id 'testnet-admin::TokenSwapScripts::add_liquidity' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:400000000000  u128:100000000  u128:5000  u128:5000  --profile testnet-admin --assume-yes
sleep 5


#方案C：按STAR-APT X30、APT-USDT X10 来计算：

### 添加第三个LP交易对

### 管理员创建swap交易对
#aptos move run --function-id 'testnet-admin::TokenSwapScripts::register_swap_pair' --type-args  0x1::aptos_coin::AptosCoin ${SWAP_ADMIN}::asset::USDT  --profile testnet-admin --assume-yes
#sleep 5

### 管理员添加代币对流动性（APT:USDT 约等于 1:7，APT:USDT初始流动性(1,7)）
aptos move run --function-id 'testnet-admin::TokenSwapScripts::add_liquidity' --type-args  0x1::aptos_coin::AptosCoin ${SWAP_ADMIN}::asset::USDT  --args  u128:100000000  u128:7000000  u128:5000  u128:5000  --profile testnet-admin --assume-yes
sleep 5

## 初始化farm+stake

### 打开boost 开关
#aptos move run --function-id 'testnet-admin::TokenSwapScripts::set_alloc_mode_upgrade_switch' --args bool:true --profile testnet-admin --assume-yes

### 事件初始化
#aptos move run --function-id 'testnet-admin::TokenSwapFarmScript::initialize_boost_event' --profile testnet-admin --assume-yes
#sleep 5

### 初始化Farm池global pool info，farm池每秒恒定释放0.27个STAR
#aptos move run --function-id 'testnet-admin::UpgradeScripts::initialize_global_pool_info' --args u128:270000000 --profile testnet-admin --assume-yes
#sleep 5


### 管理员创建Farm池
#aptos move run --function-id 'testnet-admin::TokenSwapFarmScript::add_farm_pool_v2' --type-args ${SWAP_ADMIN}::STAR::STAR ${SWAP_ADMIN}::asset::USDT --args u128:30 --profile testnet-admin --assume-yes

### 调整Farm池子倍率
#aptos move run --function-id 'testnet-admin::TokenSwapFarmScript::set_farm_alloc_point' --type-args ${SWAP_ADMIN}::STAR::STAR ${SWAP_ADMIN}::asset::USDT  --args u128:0 --profile testnet-admin --assume-yes

### 管理员创建第二个Farm池
#aptos move run --function-id 'testnet-admin::TokenSwapFarmScript::add_farm_pool_v2' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args u128:30 --profile testnet-admin --assume-yes
#sleep 5

### 调整Farm池子倍率
#aptos move run --function-id 'testnet-admin::TokenSwapFarmScript::set_farm_alloc_point' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args u128:30 --profile testnet-admin --assume-yes


### 管理员创建第三个Farm池
#aptos move run --function-id 'testnet-admin::TokenSwapFarmScript::add_farm_pool_v2' --type-args  0x1::aptos_coin::AptosCoin ${SWAP_ADMIN}::asset::USDT  --args u128:10 --profile testnet-admin --assume-yes
#sleep 5

###初始化Syrup池global pool info，syrup池每秒恒定释放0.008个STAR
#aptos move run --function-id 'testnet-admin::UpgradeScripts::initialize_global_syrup_info' --args u128:8000000 --profile testnet-admin --assume-yes
#sleep 5

### 升级syrup 释放量
#aptos move run --function-id 'testnet-admin::UpgradeScripts::upgrade_from_v1_0_11_to_v1_0_12'  --profile testnet-admin --assume-yes


### 管理员创建Syrup
#aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::add_pool_v2' --type-args ${SWAP_ADMIN}::STAR::STAR --args  u128:30  u64:0 --profile testnet-admin --assume-yes
#sleep 5

### 添加Syrup池子阶梯倍率
#### 100s
aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:100  u64:1 --profile testnet-admin --assume-yes
sleep 5

#### 1hour
aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:3600 u64:1 --profile testnet-admin --assume-yes
sleep 5

#### 7d
#aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:604800 u64:1 --profile testnet-admin --assume-yes
#sleep 5

#### 14d
#aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:1209600 u64:2 --profile testnet-admin --assume-yes
#sleep 5

#### 30d
#aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:2592000 u64:6 --profile testnet-admin --assume-yes
#sleep 5

#### 60d
#aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:5184000 u64:9 --profile testnet-admin --assume-yes
#sleep 5

#### 90d
#aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::put_stepwise_multiplier_with_token_type' --type-args ${SWAP_ADMIN}::STAR::STAR --args u64:7776000 u64:12 --profile testnet-admin --assume-yes
#sleep 5

### 验证

### 测试账号接收token
#aptos move run --function-id ${SWAP_ADMIN}::CommonHelper::accept_token_entry --type-args ${SWAP_ADMIN}::STAR::STAR  --private-key {output.key.test}  --url https://testnet.aptoslabs.com --assume-yes

### 给test account 转 STAR，单次转200个STAR
#aptos move run --function-id 0x1::coin::transfer --type-args ${SWAP_ADMIN}::STAR::STAR --args address:${SWAP_ADMIN} u64:200000000000 --profile testnet-admin --assume-yes

### 触发一次swap交易
#aptos move run --function-id 'testnet-admin::TokenSwapScripts::swap_exact_token_for_token' --type-args ${SWAP_ADMIN}::STAR::STAR ${SWAP_ADMIN}::asset::USDT  --args u128:10000000000 u128:100 --private-key {output.key.test}  --url https://testnet.aptoslabs.com --assume-yes

### 查看resource信息
#https://url:port/accounts/{address}/resource/{resource_type}

#http://127.0.0.1:8080/0x41422f5825e00c009a86ad42bc104228ac5f841313d8417ce69287e36776d1ee/resource/0x41422f5825e00c009a86ad42bc104228ac5f841313d8417ce69287e36776d1ee::STAR::STAR



### 验证farm + stake

### 质押流动性
aptos move run --function-id 'testnet-admin::TokenSwapFarmScript::stake' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:30622   --profile  testnet-admin --assume-yes
sleep 5

### 领取奖励
aptos move run --function-id 'testnet-admin::TokenSwapFarmScript::harvest' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:0   --profile  testnet-admin --assume-yes
sleep 5

### 取出Farm质押
aptos move run --function-id 'testnet-admin::TokenSwapFarmScript::unstake' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:3100   --profile  testnet-admin --assume-yes
sleep 5

### 质押Syrup
aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::stake' --type-args ${SWAP_ADMIN}::STAR::STAR  --args  u64:100 u128:100000000   --profile  testnet-admin --assume-yes
sleep 5

### syrup unstake
aptos move run --function-id 'testnet-admin::TokenSwapSyrupScript::unstake' --type-args ${SWAP_ADMIN}::STAR::STAR  --args  u64:1   --profile  testnet-admin --assume-yes
sleep 5


### adjust farm and stake release per second
#aptos move run --function-id 'testnet-admin::UpgradeScripts::set_farm_pool_release_per_second' --args  u128:180000000 --profile  testnet-admin --assume-yes
#aptos move run --function-id 'testnet-admin::UpgradeScripts::set_stake_pool_release_per_second' --args u128:4000000   --profile  testnet-admin --assume-yes