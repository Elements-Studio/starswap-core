#!/bin/bash


# Please import manager account into node
SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd $SCRIPT_DIR || exit

NETWORK=$1
ADMIN_ACCOUNT=$2
RUN_CMD="./starcoin.sh $NETWORK ~/.starcoin/$NETWORK"

### ！！注意这里需要先导入管理员账户，否则下面的命令不会生效！！ ###

## 需要获取 STC 和 STAR TODO

### 这里需要将Poly-STC-Bridge部署包拷贝到release目录下
$RUN_CMD 'account unlock 0x8c109349c6bd91411d6bc962e080c4a3'

### 这里还需要部署一下./MockToken工程否则会报LinkedError
$RUN_CMD 'dev deploy -s 0xe52552637c5897a2d499fbf08216f73e release/Poly-STC-Bridge.v1.0.12.blob -b'

$RUN_CMD 'dev deploy -s 0x8c109349c6bd91411d6bc962e080c4a3 release/Starswap-Core.v1.0.12.blob -b'

### 执行初始化
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::UpgradeScripts::genesis_initialize_for_latest_version_entry --arg 800000000u128 --arg 46000000u128 -b'

### 注册swap交易池
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapScripts::register_swap_pair -t 0x8c109349c6bd91411d6bc962e080c4a3::STAR::STAR -t 0x1::STC::STC -b'

### 添加 STAR-STC流动性(200,20)
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapScripts::add_liquidity -t 0x1::STC::STC -t 0x8c109349c6bd91411d6bc962e080c4a3::STAR::STAR --arg 20000000000u128 --arg 200000000000u128 --arg 2000u128 --arg 2000u128 -b'

############### Farm相关  ###########################

### 管理员创建 STAR-STC Farm
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapFarmScript::add_farm_pool_v2 -t 0x1::STC::STC -t 0x8c109349c6bd91411d6bc962e080c4a3::STAR::STAR --arg 0u128 -b'

### 查看STAR-STC池子倍率
$RUN_CMD 'dev call --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapFarmRouter::query_info_v2 -t 0x1::STC::STC -t 0x8c109349c6bd91411d6bc962e080c4a3::STAR::STAR'

### 查询farm池子Global信息
$RUN_CMD 'dev call --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapFarmRouter::query_global_pool_info'

### 管理员设置 STAR-STC Farm 分配 alloc-point
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapFarmScript::set_farm_alloc_point -t 0x1::STC::STC -t 0x8c109349c6bd91411d6bc962e080c4a3::STAR::STAR  --arg 5u128 -b'

### 查看池子倍率
$RUN_CMD'dev call --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapFarmRouter::query_info_v2 -t -t 0x1::STC::STC -t 0x8c109349c6bd91411d6bc962e080c4a3::STAR::STAR'

### 查询farm池子总体Global信息
$RUN_CMD 'dev call --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapFarmRouter::query_global_pool_info'

### 查询用户手上的质押所有的代币的权重
$RUN_CMD 'dev call --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapFarm::query_total_stake_weight -t 0x1::STC::STC -t 0x8c109349c6bd91411d6bc962e080c4a3::STAR::STAR  --arg 0x8c109349c6bd91411d6bc962e080c4a3'

### 管理员创建Syrup
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapSyrupScript::add_pool -t 0x8c109349c6bd91411d6bc962e080c4a3::STAR::STAR --arg 2000000u128 --arg 0u64 -b'

### 添加Syrup池子阶梯倍率

#### 7d
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapSyrupScript::put_stepwise_multiplier --arg 604800u64 --arg 2u64 -b'
#### 14d
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapSyrupScript::put_stepwise_multiplier --arg 1209600u64 --arg 3u64 -b'
#### 30d
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapSyrupScript::put_stepwise_multiplier --arg 2592000u64 --arg 4u64 -b'
#### 60d
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapSyrupScript::put_stepwise_multiplier --arg 5184000u64 --arg 6u64 -b'
#### 90d
$RUN_CMD 'account execute-function -s 0x8c109349c6bd91411d6bc962e080c4a3 --function 0x8c109349c6bd91411d6bc962e080c4a3::TokenSwapSyrupScript::put_stepwise_multiplier --arg 7776000u64 --arg 8u64 -b'