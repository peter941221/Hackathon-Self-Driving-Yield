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
- The target product shape is a middle path: adaptive allocation plus hedge-aware controls.


## Why It Is More Investable Now

- **More Accurate NAV**: hedge account value is included in vault accounting.
- **Fairer Share Pricing**: virtual shares plus TWAP-vs-spot guards reduce manipulation surface.
- **Cleaner Incentives**: no-op cycles no longer farm gas-only bounty.
- **Safer Control Logic**: hysteresis, partial hedge close, and `ONLY_UNWIND` improve defensive behavior.
- **Better Evidence**: the repo now includes invariants, adversarial tests, static-analysis triage, and CI.


## Assurance Snapshot

This repo is not presented as “fully formally verified production software”.

It is presented as a strategy system with a growing assurance stack:

- `54/54` contract tests passing locally.
- `5/5` invariant checks passing.
- `8/8` symbolic formal properties passing via Halmos.
- adversarial tests covering dependency and unwind edge cases.
- Slither reduced to `1` remaining finding family focused on flash-callback event ordering.

Manual callback review: `docs/PANCAKECALL_AUDIT.md`.
- optional BNB Chain fork checks for live integration readability.

For the full proof index, see `docs/ASSURANCE.md`.


## Research Snapshot (90d model)

As of `2026-03-08` using trailing 90d CoinGecko BTC data.

Assumptions:

- `TVL = $100k`
- `BTC path = CoinGecko daily data`
- scenarios = `baseline`, `stress`, `funding_adverse`, `liquidity_crunch`, `gas_spike`
- comparison = `dynamic` vs `fixed_normal` vs `pure_alp` vs `pure_lp`


### Baseline

- Dynamic CAGR: `15.09%`
- Dynamic cumulative return: `3.49%`
- Dynamic max drawdown: `-0.06%`
- Fixed NORMAL CAGR: `13.61%`
- Pure LP CAGR: `-1.60%`


### Stress

- Dynamic CAGR: `10.93%`
- Dynamic cumulative return: `2.56%`
- Dynamic max drawdown: `-0.17%`
- Fixed NORMAL CAGR: `9.30%`
- Pure LP CAGR: `-11.27%`


## Interpretation

- The dynamic strategy remains positive in the model under both baseline and stress assumptions.
- Pure LP remains the cleanest negative control: it shows why IL-aware risk management matters.
- Pure ALP can outperform in some windows, but that is concentration risk, not the intended product shape.
- The stronger investor story is now “adaptive strategy + clearer assurance”, not just “higher modeled return”.


## Boundaries

- This is still a research model, not realized production performance.
- ALP carry and hedge behavior are modeled, not full live liquidation-path replay.
- The remaining static-analysis hotspot is still the flash callback path, which is exactly where manual audit attention should stay focused.


## Visual Asset

- Embedded README screenshot asset: `docs/assets/investor-one-pager.svg`
