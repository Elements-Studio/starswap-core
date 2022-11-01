#!/bin/bash

### 生成私钥（文件在当前目录）
aptos key generate --key-type ed25519 --output-file output.key.miannet.admin

### 连接mainnet网络
aptos init --profile mainnet-admin --private-key {output.key.miannet.admin}  --rest-url https://mainnet.aptoslabs.com --skip-faucet
#0xf0b07b5181ce76e447632cdff90525c0411fd15eb61df7da4e835cf88dc05f5b
# 用命令行生成的账号，替换mainnet_deploy.sh里面的账号。注意在命令行生成的账号前手动补齐全0x。