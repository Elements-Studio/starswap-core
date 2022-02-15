
account default 0x2b3d5bd6d0f8a957e6a4abe986056ba7
account unlock

### 管理员创建Farm
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::add_farm_pool -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT --arg 1000000000u128 -b
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::add_farm_pool -t 0x1::STC::STC -t 0xfe125d419811297dfab03c61efec0bc9::FAI::FAI --arg 1000000000u128 -b
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::add_farm_pool -t 0x1::STC::STC -t 0x2b3d5bd6d0f8a957e6a4abe986056ba7::STAR::STAR --arg 1000000000u128 -b

### 查看Farm池每秒释放额度
dev call --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::query_release_per_second -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT

### 质押流动性
account execute-function -s 0x4c438026f963f52f01f612d1e8c41bc4 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::stake -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT -b --arg 30622u128
account execute-function -s 0x2b3d5bd6d0f8a957e6a4abe986056ba7 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::stake -t 0x1::STC::STC -t 0xfe125d419811297dfab03c61efec0bc9::FAI::FAI -b --arg 10000u128

### 查询该用户质押的流动性
dev call --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::query_stake -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT --arg 0x4c438026f963f52f01f612d1e8c41bc4

### 等待N个时间
dev sleep -t 3600000
dev gen-block

### 查看奖励
dev call --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::lookup_gain -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT --arg 0x4c438026f963f52f01f612d1e8c41bc4

### 领取奖励
account execute-function -s 0x4c438026f963f52f01f612d1e8c41bc4 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::harvest -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT -b --arg 0u128

### 查看STAR额度
account show 0x4c438026f963f52f01f612d1e8c41bc4

### 取出Farm质押
account execute-function -s 0x4c438026f963f52f01f612d1e8c41bc4 --function 0x2b3d5bd6d0f8a957e6a4abe986056ba7::TokenSwapFarmScript::unstake -t 0x1::STC::STC -t 0x4c438026f963f52f01f612d1e8c41bc4::XUSDT::XUSDT -b --arg 10002u128