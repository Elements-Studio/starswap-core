#!/bin/bash

SWAP_ADMIN=$1

 ###从farm国库提取80万STAR，用于初始流动性
#aptos move run --function-id 'mainnet-admin::TokenSwapGovScript::linear_withdraw_farm'  --args u128:800000000000000  --profile mainnet-admin --assume-yes
aptos move run --function-id 'mainnet-admin::TokenSwapGovScript::dispatch' --type-args ${SWAP_ADMIN}::TokenSwapGovPoolType::PoolTypeFarmPool --args address:0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b u128:800000000000000  --profile mainnet-admin --assume-yes

### 管理员添加代币对流动性（STAR:APT 约等于 230:1,，STAR-APT初始流动性(800000,3478.26)）
aptos move run --function-id 'mainnet-admin::TokenSwapScripts::add_liquidity' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:800000000000000  u128:347826000000  u128:5000  u128:5000  --profile mainnet-admin --assume-yes

### 管理员添加代币对流动性（APT:USDC 约等于 1:7.8，APT:USDC初始流动性(1282.05,10000)）
aptos move run --function-id 'mainnet-admin::TokenSwapScripts::add_liquidity' --type-args  0x1::aptos_coin::AptosCoin 0xf22bede237a07e121b56d91a491eb7bcdfd1f5907926a9e58338f964a01b17fa::asset::USDC  --args  u128:128205000000  u128:10000000000  u128:5000  u128:5000  --profile mainnet-admin --assume-yes