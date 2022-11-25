#!/bin/bash

SWAP_ADMIN=$1

 ###从farm国库提取80万STAR，用于初始流动性
#aptos move run --function-id 'mainnet-admin::TokenSwapGovScript::linear_withdraw_farm'  --args u128:800000000000000  --profile mainnet-admin --assume-yes
#aptos move run --function-id 'mainnet-admin::TokenSwapGovScript::dispatch' --type-args ${SWAP_ADMIN}::TokenSwapGovPoolType::PoolTypeFarmPool --args address:0xc755e4c8d7a6ab6d56f9289d97c43c1c94bde75ec09147c90d35cd1be61c8fb9 u128:800000000000000  --profile mainnet-admin --assume-yes

### 管理员添加代币对流动性（STAR:APT 约等于 615:1,，STAR-APT初始流动性(400000,650.045)）
aptos move run --function-id 'mainnet-admin::TokenSwapScripts::add_liquidity' --type-args ${SWAP_ADMIN}::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:400000000000000  u128:65004500000  u128:5000  u128:5000  --profile mainnet-admin --assume-yes

### 管理员添加代币对流动性（APT:USDC 约等于 1:4.3366，APT:USDC初始流动性(1152.98,5000)）
aptos move run --function-id 'mainnet-admin::TokenSwapScripts::add_liquidity' --type-args  0x1::aptos_coin::AptosCoin 0xf22bede237a07e121b56d91a491eb7bcdfd1f5907926a9e58338f964a01b17fa::asset::USDC  --args  u128:115298000000  u128:5000000000  u128:5000  u128:5000  --profile mainnet-admin --assume-yes