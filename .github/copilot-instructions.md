# Starswap Core — Copilot Instructions

## Project Overview

Starswap is a DEX (Decentralized Exchange) on the Starcoin blockchain. This repo (`starswap-core`) contains all on-chain Move smart contracts: AMM swap, liquidity pools, yield farming, governance, boost/veSTAR, and buy-back modules.

## Tech Stack

- **Language:** Move (Starcoin dialect)
- **Package Manager:** `mpm` (Move Package Manager, v1.13.9+)
- **Framework:** StarcoinFramework (`0x1`)

## Build & Test Commands

```bash
mpm package build          # Compile contracts
mpm package test           # Run unit tests
mpm integration-test       # Run all integration tests
mpm integration-test <file> # Run a single integration test
./scripts/build.sh         # Full build + doc generation
```

## Key Addresses

| Name | Address | Role |
|------|---------|------|
| `SwapAdmin` | `0x8c109349c6bd91411d6bc962e080c4a3` | Main admin, deploys all modules |
| `SwapFeeAdmin` | `0x9572abb16f9d9e9b009cc1751727129e` | Fee configuration |
| `BuyBackAccount` | `0xa1869437e19a33eba1b7277218af539c` | Buy-back operations |

## Architecture & Module Map

```
sources/
├── common/       # SafeMath, FixedPoint128, BigExponential
├── swap/         # Core AMM: TokenSwap, Router(1-3), Config, Fee, Oracle
├── farm/         # YieldFarming(V3), TokenSwapFarm, Syrup pools
├── gov/          # STAR token, Governance, BuyBack, TimelyReleasePool
├── boost/        # Boost, VESTAR, VToken
├── helper/       # Test utilities (CommonHelper, SwapTestHelper, TokenMock)
└── MultiChain.move  # Genesis / multi-chain init
```

## Conventions

### Module Structure
- All modules are under `address SwapAdmin { module SwapAdmin::ModuleName { ... } }`
- Token pairs use phantom generics: `<phantom X, phantom Y>` where X < Y (sorted by type)
- Liquidity tokens: `LiquidityToken<X, Y>`

### Error Codes
- Use named constants: `const ERR_SOMETHING: u64 = <code>;`
- Ranges: `10x` = parameter errors, `20x` = state/existence errors
- Always declare error constants at the top of the module

### Events
- Use `Event::EventHandle<T>` for structured on-chain events
- Event structs include token codes and signer info

### Access Control
- Signer-based: compare `Signer::address_of(account)` against admin addresses
- Use `assert!()` with error codes for permission checks

### Testing
- Unit tests: `#[test]` / `#[test_only]` annotations inside module files
- Integration tests: paired `.move` + `.exp` files in `integration-tests/`
- Test subdirectories mirror source: `swap/`, `farm/`, `gov/`, `boost/`
- When adding a module, always add corresponding integration test

### Adding a New Module
1. Create `sources/<category>/MyModule.move`
2. Add unit tests with `#[test]` in the same file
3. Create `integration-tests/<category>/my_module_test.move` + `.exp`
4. Run `mpm integration-test my_module_test.move`
5. Run `./scripts/build.sh`

## Common Pitfalls
- Token pair ordering matters: X must sort before Y by type info
- `u128` overflow: use `SafeMath` or `U256` for intermediate calculations
- Integration test `.exp` files must match output exactly (whitespace-sensitive)
- The `MockToken` sub-package provides test tokens — don't add test tokens to main sources
