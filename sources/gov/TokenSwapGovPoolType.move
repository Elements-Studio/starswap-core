// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address SwapAdmin {
module TokenSwapGovPoolType {
    struct PoolTypeInitialLiquidity has key, store {}

    struct PoolTypeFarmPool has key, store {}

    struct PoolTypeSyrup has key, store {}

    struct PoolTypeTeam has key, store {}

    struct PoolTypeCommunity has key, store {}

    struct PoolTypeDaoTreasury has key, store {}
}
}