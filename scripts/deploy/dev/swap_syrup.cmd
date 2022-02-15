### 提取 STAR
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapGovScript::dispatch -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapGovPoolType::PoolTypeDaoCrosshain --arg  0x2b3d5bd6d0f8a957e6a4abe986056ba7  --arg 210000000000000u128  -b

### 管理员创建Syrup
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrupScript::add_pool -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR --arg 1000000000u128 --arg 0u64 -b

### 查看Syrup池每秒释放额度
dev call --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrup::query_release_per_second -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR

### 质押Syrup
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrupScript::stake -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR --arg 10000u64 --arg 100000000u128 -b

### 查看stake list
dev call --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrupScript::query_stake_list -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR --arg 0x2b3d5bd6d0f8a957e6a4abe986056ba7

### 查看stake info
dev call --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrupScript::get_stake_info -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR --arg 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --arg 1u64

### syrup unstake
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapSyrupScript::unstake -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR  --arg 1u64