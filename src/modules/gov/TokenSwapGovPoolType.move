// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

// TODO: replace the address with admin address
address 0x4783d08fb16990bd35d83f3e23bf93b8 {
module TokenSwapGovPoolType {

    struct PoolTypeLiquidityMint has key, store {} // Obsoleted in latest test version

    struct PoolTypeFarmPool has key, store {}

    struct PoolTypeSyrup has key, store {}

    struct PoolTypeTeam has key, store {}

    struct PoolTypeInvestor has key, store {}

    struct PoolTypeTechMaintenance has key, store {}

    struct PoolTypeMarket has key, store {}

    struct PoolTypeStockManagement has key, store {}

    struct PoolTypeDaoCrosshain has key, store {}
}
}