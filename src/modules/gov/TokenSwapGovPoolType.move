// Copyright (c) The Elements Studio Core Contributors
// SPDX-License-Identifier: Apache-2.0

address 0x8c109349c6bd91411d6bc962e080c4a3 {
module TokenSwapGovPoolType {
    struct PoolTypeFarmPool has key, store {}

    struct PoolTypeSyrup has key, store {}

    struct PoolTypeCommunity has key, store {}

    struct PoolTypeIDO has key, store {}

    struct PoolTypeDeveloperFund has key, store {}

    struct PoolTypeProtocolTreasury has key, store {}

    // Deprecated TODO to be removed
    struct PoolTypeInitialLiquidity has key, store {}
    // Deprecated TODO to be removed
    struct PoolTypeTeam has key, store {}
    // Deprecated TODO to be removed
    struct PoolTypeDaoTreasury has key, store {}
}
}