# Architecture

This document explains the system components, fund flow, state machine, and risk controls.


## 1. Components

```
EngineVault (ERC-4626)
├─ AsterAlpAdapter        (ALP mint/burn/NAV)
├─ PancakeV2Adapter       (LP add/remove/price)
├─ Aster1001xAdapter      (open/close hedge)
├─ VolatilityOracle       (TWAP volatility)
└─ WithdrawalQueue        (permissionless redemption)
```

EngineVault also implements:
- Pancake V2 flash swap rebalance via `flashPair.swap(...)` + `pancakeCall(...)` callback
- `flashPair` must be different from the LP pair (`v2Pair`) to avoid UniswapV2 `lock()` deadlock


## 2. Fund Flow

```
Deposit
  USDT -> EngineVault -> cashBuffer
  (wait for cycle())

Cycle
  cashBuffer -> ALP / LP / Hedge
  re-evaluate target allocation

Withdraw
  cashBuffer -> direct redeem
  otherwise: unwind hedge -> remove LP -> burn ALP
```


## 3. cycle State Machine

```
Phase 0  Pre-checks
Phase 1  Read state (ALP, LP, hedge, cash)
Phase 2  TWAP snapshot + Regime (with MIN_SAMPLES)
Phase 3  Target allocation
Phase 4  Rebalance (Flash or incremental)
Phase 5  Delta hedge
Phase 6  Bounty payout + events
```

Rules:

- Snapshot sampling must respect `minSnapshotInterval`.

- Cold start (samples < MIN_SAMPLES) forces NORMAL regime.

- Cold start does not trigger the flash-swap rebalance path.


## 4. Regime Switching

```
CALM   : vol < 1%   => ALP 40% / LP 57% / Buffer 3%
NORMAL : 1%-3%      => ALP 60% / LP 37% / Buffer 3%
STORM  : >= 3%      => ALP 80% / LP 17% / Buffer 3%
```


## 5. Flash Swap Rebalance (Atomic)

```
1) EngineVault calls `flashPair.swap(...)` to borrow base/quote
2) `flashPair` calls back `EngineVault.pancakeCall(...)`
3) In callback: remove/adjust LP, run swaps, add LP, adjust 1001x hedge
4) Compute repay amount via UniswapV2 formula (`PancakeLibrary.getAmountIn`) and repay
```


## 6. Risk Mode

```
RiskMode.NORMAL      : allow add / reduce
RiskMode.ONLY_UNWIND : only reduce / unwind
```

Triggers:

- ALP NAV drops beyond threshold.

- TWAP vs spot deviation exceeds threshold.

- 1001x health factor approaches liquidation.

Exit:

- N consecutive safe cycles.


## 7. Repo Layout

```
contracts/
  core/
  adapters/
  libs/
  interfaces/
test/
script/
docs/
```


## 8. External Addresses

- Aster 1001x Diamond: 0x1b6f2d3844c6ae7d56ceb3c3643b9060ba28feb0

- Pancake Router V2:  0x10ED43C718714eb63d5aA57B78B54704E256024E

- Pancake Factory V2: 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73

- WBNB:               0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c

- USDT (BSC):         0x55d398326f99059fF775485246999027B3197955

- BTCB (BSC):         0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c
