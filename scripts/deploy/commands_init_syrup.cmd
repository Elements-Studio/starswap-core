### 提取 STAR
account execute-function -s 0x4783d08fb16990bd35d83f3e23bf93b8 --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovScript::dispatch   -t 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapGovPoolType::PoolTypeDaoCrosshain --arg  0x4783d08fb16990bd35d83f3e23bf93b8  --arg 210000000000000u128  -b

### 管理员创建Syrup
account execute-function -s 0x4783d08fb16990bd35d83f3e23bf93b8 --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrupScript::add_pool -t 0x4783d08fb16990bd35d83f3e23bf93b8::STAR::STAR --arg 1000000000u128 --arg 0u64 -b

### 查看Syrup池每秒释放额度
dev call --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrup::query_release_per_second -t 0x4783d08fb16990bd35d83f3e23bf93b8::STAR::STAR

### 质押Syrup
account execute-function -s 0x4783d08fb16990bd35d83f3e23bf93b8 --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrupScript::stake -t 0x4783d08fb16990bd35d83f3e23bf93b8::STAR::STAR --arg 10000u64 --arg 100000000u128 -b

### 查看stake list
dev call --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrupScript::query_stake_list -t 0x4783d08fb16990bd35d83f3e23bf93b8::STAR::STAR --arg 0x4783d08fb16990bd35d83f3e23bf93b8

### 查看stake info
dev call --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrupScript::get_stake_info -t 0x4783d08fb16990bd35d83f3e23bf93b8::STAR::STAR --arg 0x4783d08fb16990bd35d83f3e23bf93b8 --arg 1u64

###  syrup unstake
account execute-function -s 0x4783d08fb16990bd35d83f3e23bf93b8 --function 0x4783d08fb16990bd35d83f3e23bf93b8::TokenSwapSyrupScript::unstake -t 0x4783d08fb16990bd35d83f3e23bf93b8::STAR::STAR  --arg 1u64