# Release Notes

## 2026-03-06 — Investor-Ready Research & Risk Hardening

### Suggested GitHub Release Title

`Investor-Ready Research & Risk Hardening`

### Release Map

```text
[Risk Accounting]
      |
      v
[Fairer NAV + Share Pricing]
      |
      v
[Cleaner Investor Protection]

[Control Logic]
      |
      v
[Less Churn + Better Unwind Behavior]
      |
      v
[More Stable Automation]

[Research Output]
      |
      v
[Backtest SVG + One-Pager + README Hero]
      |
      v
[Faster Investor Diligence]
```

### Short Release Note

Self-Driving Yield Engine is now materially stronger across accounting, control logic, and investor communication. The vault now accounts for hedge margin and unrealized PnL in NAV, hardens share pricing with TWAP-aware protections, suppresses no-op bounty farming, adds hysteresis plus partial hedge close behavior, and ships a research-grade 90d comparison backtest with investor-ready SVG charts and one-pager assets.

### Copy-Ready GitHub Release Body

```md
## Highlights

- Hedge-aware NAV now includes margin, unrealized PnL, and accrued hedge fees.
- Share pricing is hardened with virtual shares plus TWAP-vs-spot deposit protection.
- Keeper incentives are cleaner: no-op cycles no longer farm gas-only bounty.
- Control logic is more stable with hysteresis regime switching and partial hedge close.
- Research output is now investor-ready with baseline/stress backtests, SVG charts, and a one-pager hero embedded in the README.

## Why It Matters

This release moves the project from a strong hackathon prototype toward a more investor-legible system:

- Better accounting improves NAV credibility.
- Better controls reduce churn and pathological rebalance behavior.
- Better research assets shorten diligence time for partners and investors.

## Investor Snapshot (as of 2026-03-06)

| Scenario | Dynamic CAGR | Dynamic CumRet | Fixed NORMAL CAGR | Pure LP CAGR | Dynamic MaxDD | Trade Days |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 14.29% | 3.31% | 13.08% | -1.44% | -0.06% | 5 |
| Stress | 9.94% | 2.34% | 8.68% | -11.04% | -0.17% | 5 |

## Validation

- `forge test` → 48/48 passing
- `python -m py_compile scripts/backtest.py`
- `python scripts/backtest.py --days 90 --tvl 100000 --cycles-per-day 4 --gas-gwei 50 --compare-scenarios --svg-dir docs/assets --one-pager-svg docs/assets/investor-one-pager.svg --json-out out/backtest-report.json`
```

### What Changed

#### 1. Risk Accounting (Risk Accounting)

- Hedge account value is included in vault NAV: margin + unrealized PnL - accrued fees.
- LP and base exposure valuation prefer oracle TWAP marks over raw spot when available.
- Deposit and redeem flows now sit behind stronger fair-value assumptions.

#### 2. Investor Protection (Investor Protection)

- Virtual assets / virtual shares reduce ERC-4626-style inflation surface.
- TWAP-vs-spot deposit guard blocks obviously distorted entry conditions.
- `ONLY_UNWIND` safety mode keeps the system defensive under oracle deviation / NAV shock conditions.

#### 3. Control Loop (Control Loop)

- Hysteresis reduces noisy regime flipping.
- Partial hedge close unwinds only what is needed to re-enter band.
- No-op bounty suppression aligns permissionless automation with useful work.

#### 4. Research & Communication (Research Output)

- The backtest now compares `dynamic`, `fixed_normal`, `pure_alp`, and `pure_lp`.
- `README.md` now carries investor KPI badges, stress/baseline SVG charts, and a one-pager hero.
- `docs/assets/investor-one-pager.svg` is ready for README and social preview usage.

### Validation Summary

- Solidity regression: `forge test` → `48/48 PASS`
- Research script: `python -m py_compile scripts/backtest.py` → `PASS`
- Investor asset generation: backtest JSON + SVG charts + one-pager SVG regenerated successfully

### Residual Risk

- KPI values are still point-in-time research outputs, not realized live performance.
- CoinGecko historical backfill can still move trailing-window numbers slightly over time.
- ALP carry, funding, and execution assumptions remain model inputs rather than audited production PnL.

