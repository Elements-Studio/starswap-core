### 设置默认账号和解锁
account default 0x4783d08fb16990bd35d83f3e23bf93b8
account unlock

### Swap Fee admin账号 accept XUSDT
account execute-function --function 0x1::Account::accept_token -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT -s 0x0a4183ac9335a9f5804014eab01c0abc -b

### 管理员创建Farm 
account execute-function -s 0x4783d08fb16990bd35d83f3e23bf93b8 --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmScript::add_farm_pool -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT --arg 1000000000u128 -b

### 查看Farm池每秒释放额度 
dev call --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmScript::query_release_per_second -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT

### 质押流动性 
account execute-function -s 0x2d81a0427d64ff61b11ede9085efa5ad --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmScript::stake -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT -b --arg 30622u128

### 查询该用户质押的流动性 
dev call --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmScript::query_stake -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT --arg 0x2d81a0427d64ff61b11ede9085efa5ad

### 等待N个时间 
dev sleep -t 3600000
dev gen-block

### 查看奖励 
dev call --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmScript::lookup_gain -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT --arg 0x2d81a0427d64ff61b11ede9085efa5ad

### 领取奖励 
account execute-function -s 0x2d81a0427d64ff61b11ede9085efa5ad --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmScript::harvest -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT -b --arg 0u128

### 查看STAR额度 
account show 0x2d81a0427d64ff61b11ede9085efa5ad

### 取出流动性 
account execute-function -s 0x2d81a0427d64ff61b11ede9085efa5ad --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapFarmScript::unstake -t 0x1::STC::STC -t 0x2d81a0427d64ff61b11ede9085efa5ad::XUSDT::XUSDT -b --arg 10002u128