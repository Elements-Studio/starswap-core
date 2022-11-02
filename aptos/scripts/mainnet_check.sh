#!/bin/bash

### 独立账号测试

### 重新生成独立测试账号
#aptos key generate --key-type ed25519 --output-file output.key.test

#Testnet测试
#aptos init --profile mainnet-test --private-key {output.key.test}  --rest-url https://mainnet.aptoslabs.com --skip-faucet

#0xa1f9519d22512ae8b2347ea448463dc85dd49f07f48f78855fc7e920931c58d9

### 钱包手动转gas,测试APT > 5个


### 测试账号接收token
aptos move run --function-id 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::CommonHelper::accept_token_entry --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR --assume-yes --profile  mainnet-test
sleep 5

### 给test account 转 STAR，单次转4500个STAR
aptos move run --function-id 0x1::coin::transfer --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR --args address:0xa1f9519d22512ae8b2347ea448463dc85dd49f07f48f78855fc7e920931c58d9 u64:4500000000000 --profile mainnet-test --assume-yes
sleep 5


### 触发一次swap交易
aptos move run --function-id 'mainnet-test::TokenSwapScripts::swap_exact_token_for_token' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR 0x1::aptos_coin::AptosCoin  --args u128:200000000000 u128:100 --assume-yes --profile  mainnet-test
sleep 5

### 再触发一次swap交易，另一个交易对
aptos move run --function-id 'mainnet-test::TokenSwapScripts::swap_exact_token_for_token' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR 0x1::aptos_coin::AptosCoin  --args u128:100000000000 u128:100 --assume-yes --profile  mainnet-test
sleep 5

### 测试添加流动性
aptos move run --function-id 'mainnet-test::TokenSwapScripts::add_liquidity' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR     0x1::aptos_coin::AptosCoin   --args  u128:1200000000000  u128:300000000  u128:5000  u128:5000  --profile mainnet-test --assume-yes
sleep 5

### 质押流动性
aptos move run --function-id 'mainnet-test::TokenSwapFarmScript::stake' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR 0x1::aptos_coin::AptosCoin --args  u128:26655101   --profile  mainnet-test --assume-yes
sleep 5

### 领取奖励
aptos move run --function-id 'mainnet-test::TokenSwapFarmScript::harvest' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR 0x1::aptos_coin::AptosCoin --args  u128:0   --profile  mainnet-test --assume-yes
sleep 5


### 取出Farm质押
aptos move run --function-id 'mainnet-test::TokenSwapFarmScript::unstake' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:3100   --profile  mainnet-test --assume-yes
sleep 5

### 质押Syrup
aptos move run --function-id 'mainnet-test::TokenSwapSyrupScript::stake' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR  --args  u64:100 u128:12000000000   --profile  mainnet-test --assume-yes
sleep 5

aptos move run --function-id 'mainnet-test::TokenSwapSyrupScript::stake' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR  --args  u64:3600 u128:25000000000   --profile  mainnet-test --assume-yes
sleep 5


### 给farm池boost加速
aptos move run --function-id 'mainnet-test::TokenSwapFarmScript::boost' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR 0x1::aptos_coin::AptosCoin  --args  u128:1445965   --profile  mainnet-test --assume-yes
sleep 5

### syrup unstake
aptos move run --function-id 'mainnet-test::TokenSwapSyrupScript::unstake' --type-args 0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b::STAR::STAR  --args  u64:1   --profile  mainnet-test --assume-yes
sleep 5