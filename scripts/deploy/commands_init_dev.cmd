# bridge合约admin账号
account import -i 0xf4611222ffb7a0d348596132b94ac63f61e78bea4da87d3d9f9009b2abb4ce82
account default 0x2d81a0427d64ff61b11ede9085efa5ad
account unlock 0x2d81a0427d64ff61b11ede9085efa5ad
dev get-coin 0x2d81a0427d64ff61b11ede9085efa5ad

# Swap Fee admin账号
account import -i 0x1f5bfa4af32fe7c0604efba5146e3341153ff8245cc39a1e4000d09727a58f03
account default   0x0a4183ac9335a9f5804014eab01c0abc
account unlock   0x0a4183ac9335a9f5804014eab01c0abc
dev get-coin   0x0a4183ac9335a9f5804014eab01c0abc

# Swap合约admin账号
account import -i 0x7d50cc0b71d372299d5a3f8aeabc9aa6b911628b6865d9ed78985124633eea37
account default 0x4783d08fb16990bd35d83f3e23bf93b8
account unlock 0x4783d08fb16990bd35d83f3e23bf93b8
dev get-coin 0x4783d08fb16990bd35d83f3e23bf93b8

### 部署XUSDT
dev deploy storage/0x2d81a0427d64ff61b11ede9085efa5ad/modules/XUSDT.mv -s 0x2d81a0427d64ff61b11ede9085efa5ad  -b
dev deploy storage/0x2d81a0427d64ff61b11ede9085efa5ad/modules/XUSDTScripts.mv -s 0x2d81a0427d64ff61b11ede9085efa5ad -b

### XUSDT注册/发币
account execute-function  --function 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDTScripts::init -s 0x2d81a0427d64ff61b11ede9085efa5ad -b
account execute-function  --function 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDTScripts::mint --arg 20088888000000000u128 -s 0x2d81a0427d64ff61b11ede9085efa5ad -b

dev package -n swap -o build storage/0x4783d08fb16990bd35d83f3e23bf93b8/
dev deploy -s 0x4783d08fb16990bd35d83f3e23bf93b8  build/swap.blob -b

# 提交带时间设置的升级配置（10s）
account execute-function -s 0x4783d08fb16990bd35d83f3e23bf93b8 --function 0x4783d08fb16990bd35d83f3e23bf93b8::UpgradeScripts::update_module_upgrade_strategy_with_min_time --arg 1u8 --arg 10000u64 -b

### Swap Fee admin账号 accept XUSDT
account execute-function --function 0x1::Account::accept_token -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT -s 0x0a4183ac9335a9f5804014eab01c0abc -b

### 治理币创世初始化
account execute-function  --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovScript::genesis_initialize -s 0x4783d08fb16990bd35d83f3e23bf93b8 -b

### 设置swap operation fee rate
account execute-function  --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapScripts::set_swap_fee_operation_rate --arg 10u64 --arg 60u64  -s 0x4783d08fb16990bd35d83f3e23bf93b8 -b

### 提取STAR
account execute-function -s 0x4783d08fb16990bd35d83f3e23bf93b8 --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovScript::dispatch -t 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovPoolType::PoolTypeDaoCrosshain --arg  0x4783d08fb16990bd35d83f3e23bf93b8  --arg 210000000000000u128 -b

### 管理员创建swap交易对
account execute-function  --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapScripts::register_swap_pair -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT -s 0x4783d08fb16990bd35d83f3e23bf93b8 -b

# account execute-function -s 0x4783d08fb16990bd35d83f3e23bf93b8 --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapScripts::register_swap_pair -t 0x1::STC::STC -t 0xfe125d419811297dfab03c61efec0bc9::FAI::FAI  -b
account execute-function -s 0x4783d08fb16990bd35d83f3e23bf93b8 --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapScripts::register_swap_pair -t 0x4783d08fb16990bd35d83f3e23bf93b8::STAR::STAR -t 0x1::STC::STC -b

###  添加代币对流动性
account execute-function -s 0x2d81a0427d64ff61b11ede9085efa5ad --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapScripts::add_liquidity -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT --arg 50000000000u128 --arg 25000000000u128 --arg 5000u128 --arg 5000u128 -b

###  查询刚刚创建的交易对流动性
dev call --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapRouter::total_liquidity -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT
