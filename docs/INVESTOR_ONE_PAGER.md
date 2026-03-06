# Investor One-Pager

## Project

Self-Driving Yield Engine is an autonomous, non-custodial yield vault on BNB Chain.

It rotates capital across:

- `Aster ALP` for volatility-linked carry.
- `Pancake V2 LP` for fee income.
- `1001x short hedge` for LP base-exposure control.


## Core Thesis

```text
[Calm Market]
   |
   v
[LP fees matter more] ---> [Keep more LP exposure]

[Storm Market]
   |
   v
[ALP carry + volatility capture matter more] ---> [Shift toward ALP]
```

- Pure LP is vulnerable to impermanent loss.

- Pure ALP is a concentration bet.

- The product thesis is a **middle path**: adaptive allocation plus hedge-aware controls.


## Why It Is More Investable Now

- **Accurate NAV**: hedge account value is included in vault accounting.

- **Fairer Share Pricing**: virtual shares plus TWAP-vs-spot deposit guard reduce inflation/manipulation surface.

- **Cleaner Incentives**: no-op cycles no longer farm gas-only bounty.

- **More Stable Control**: hysteresis regime switching and partial hedge close reduce churn.


## Research Snapshot (90d model)

As of `2026-03-06` using trailing 90d CoinGecko BTC data.

Assumptions:

- `TVL = $100k`
- `BTC path = CoinGecko daily data`
- `Baseline + Stress scenarios`
- `Dynamic vs Fixed NORMAL vs Pure ALP vs Pure LP`


### Baseline

- Dynamic CAGR: `14.29%`
- Dynamic cumulative return: `3.31%`
- Dynamic max drawdown: `-0.06%`
- Fixed NORMAL CAGR: `13.08%`
- Pure LP CAGR: `-1.44%`


### Stress

- Dynamic CAGR: `9.94%`
- Dynamic cumulative return: `2.34%`
- Dynamic max drawdown: `-0.17%`
- Fixed NORMAL CAGR: `8.68%`
- Pure LP CAGR: `-11.04%`


## Interpretation

- Dynamic strategy remains positive in the model under both baseline and stress scenarios.

- Pure LP is the cleanest negative control: it shows why IL-aware risk management matters.

- Pure ALP can outperform in some windows, but that is concentration risk, not the intended product shape.


## Current Risk Framing

- This is still a **research model**, not realized production performance.

- ALP returns are parameterized (`carry + volatility capture - move drag`).

- Hedge PnL is approximated from LP base exposure, not a full liquidation-path replay.


## Visual Asset

- Embedded README screenshot asset: `docs/assets/investor-one-pager.svg`
