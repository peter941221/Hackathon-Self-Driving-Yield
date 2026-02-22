# Self-Driving Yield Engine v2.0

An autonomous, non-custodial yield engine for BNB Chain that combines AsterDEX Earn (ALP) with PancakeSwap V2 LPs and on-chain delta hedging. The goal is to outperform static vaults by dynamically reallocating based on on-chain realized volatility.


## Key Ideas

- Dual Engine: ALP is both a yield source and a volatility hedge.

- Regime Switching: CALM / NORMAL / STORM allocations shift automatically.

- Permissionless Automation: anyone can call `cycle()` and earn a bounded bounty.

- Atomic Rebalance: Flash Swap rebalances reduce MEV surface.

- No Admin: all parameters are immutable, no multisig or keeper dependency.


## Implementation Notes

- LP rebalancing uses on-chain swaps when the base/quote ratio is off target.

- Flash rebalance computes a borrow amount from LP deviation and caps it to 10% of reserves.

- Flash callbacks repay in the opposite token using on-chain reserves.

- Borrowed flash amounts are excluded from target allocation calculations.

- 1001x position size sums short `qty` from `getPositionsV2(address,address)` (reader facet).


## Architecture (High-Level)

```
User (USDT)
  -> EngineVault (ERC-4626 style)
     -> ALP Adapter (AsterDEX Earn)
     -> Pancake V2 Adapter (LP + Flash Swap)
     -> 1001x Adapter (Delta Hedge)
     -> VolatilityOracle (TWAP)
     -> WithdrawalQueue (permissionless claim)
```


## Core Contracts

- `contracts/core/EngineVault.sol`

- `contracts/core/VolatilityOracle.sol`

- `contracts/core/WithdrawalQueue.sol`

- `contracts/adapters/FlashRebalancer.sol`


## Libraries & Interfaces

- `contracts/libs/PancakeOracleLibrary.sol`

- `contracts/libs/PancakeLibrary.sol`

- `contracts/libs/MathLib.sol`

- `contracts/interfaces/IAsterDiamond.sol`


## Docs

- Full Technical Spec: `技术方案2.txt`

- Architecture: `ARCHITECTURE.md`

- Economics: `ECONOMICS.md`

- Implementation Plan: `施工计划.MD`

- Louper Selector Map: `docs/LOUPER_MAP.md`

- Fork demo script: `script/ForkCycleDemo.s.sol`


## Quickstart (Foundry)

```bash
forge build
forge test
forge fmt
```


## Fork Tests (BSC)

Set the following environment variable for forked tests:

```bash
export BSC_RPC_URL="https://bsc-dataseed.binance.org/"
forge test
```

Optional:

```bash
export BSC_FORK_BLOCK=82710000
```


## Status

This repository is a working scaffold for the hackathon build-out. Core contracts and tests compile, and the strategy logic is being implemented iteratively.
