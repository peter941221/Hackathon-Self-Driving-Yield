# Release Notes

## 2026-03-08 — Investor Assurance Pack & Safety Coverage

### Suggested GitHub Release Title

`Investor Assurance Pack & Safety Coverage`

### Short Release Note

Self-Driving Yield Engine now ships with a stronger investor-proof story: a dedicated assurance packet, expanded invariants, DeFi adversarial failure-path tests, minimal CI, refreshed Slither triage, and a wider five-scenario research model. The strategy story is still model-based, but the repo now shows more disciplined evidence around accounting, risk controls, and dependency failure handling.

### Copy-Ready GitHub Release Body

```md
## Highlights

- Added an investor-facing `docs/ASSURANCE.md` that links research, tests, static analysis, and fork checks into one proof index.
- Added an actual Halmos-based formal layer proving eight core internal properties.
- Expanded machine-checked invariants around asset conservation, flash-borrow cleanup, and no-profit/no-bounty behavior.
- Added adversarial tests for `ONLY_UNWIND`, blocked hedge closes, and ALP cooldown-constrained unwinds.
- Added minimal GitHub Actions CI for `forge build/test`, invariant runs, research script checks, scenario backtests, and Slither.
- Upgraded the research menu to five scenarios: `baseline`, `stress`, `funding_adverse`, `liquidity_crunch`, and `gas_spike`.
- Refreshed Slither notes so the documented findings match the latest actual run, now reduced to callback event-order warnings only.

## Why It Matters

This release makes the project easier to diligence:

- investors can see a cleaner evidence stack,
- reviewers can reproduce the commands locally,
- and safety discussions can point to concrete invariants and adversarial tests instead of only narrative claims.

## Investor Snapshot (research output as of 2026-03-08)

| Scenario | Dynamic CAGR | Dynamic CumRet | Fixed NORMAL CAGR | Pure LP CAGR | Dynamic MaxDD | Trade Days |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 15.09% | 3.49% | 13.61% | -1.60% | -0.06% | 5 |
| Stress | 10.93% | 2.56% | 9.30% | -11.27% | -0.17% | 5 |

## Validation

- `forge test` → `54/54 PASS`
- `forge test --match-path test/Invariant.t.sol` → `5/5 PASS`
- `python scripts/run_formal.py` → `8/8 PASS`
- `python -m py_compile scripts/backtest.py` → `PASS`
- `python scripts/backtest.py --days 90 --tvl 100000 --cycles-per-day 4 --gas-gwei 50 --compare-scenarios --json-out cache/backtest-report.json` → `PASS`
- `slither . --exclude-dependencies --exclude incorrect-equality,timestamp,low-level-calls,naming-convention,cyclomatic-complexity` → `1 finding triaged`
```

### Release Map

```text
[Research Model]
      |
      v
[5 Scenarios + Reproducible Outputs]
      |
      v
[Stronger Diligence Story]

[Contract Safety]
      |
      v
[Regression + Invariants + Adversarial Tests]
      |
      v
[More Credible Risk Controls]

[Engineering Workflow]
      |
      v
[CI + Current Slither Triage]
      |
      v
[Repeatable Validation]
```

### What Changed

#### 1. Assurance Layer

- Added `docs/ASSURANCE.md` as the single investor-facing index for proof points.
- Linked research, tests, static analysis, and fork checks in one place.

#### 2. Safety Coverage

- Invariants now cover asset conservation, flash state cleanup, and zero bounty without profit.
- Formal verification now covers eight symbolic properties around accounting, share math, price-guard behavior, `ONLY_UNWIND`, and no-profit bounty behavior.
- Added a dedicated manual review note for the remaining flash-callback hotspot in `docs/PANCAKECALL_AUDIT.md`.
- Adversarial tests now prove safer behavior under dependency stress.

#### 3. Research Story

- Backtest coverage now extends beyond `baseline` and `stress` into funding, liquidity, and gas-stress variants.
- The repo can now show both upside narrative and stress-discipline narrative more cleanly.

#### 4. Validation Workflow

- Added minimal GitHub Actions CI.
- Updated Slither notes to match the latest real output rather than an older zero-finding summary.
- Reduced flash-path static-analysis noise by moving flash callback context out of storage and into local execution context.

### Validation Summary

- Solidity regression: `forge test` → `54/54 PASS`
- Invariants: `forge test --match-path test/Invariant.t.sol` → `5/5 PASS`
- Formal verification: `python scripts/run_formal.py` → `8/8 PASS`
- Research script: `python -m py_compile scripts/backtest.py` → `PASS`
- Scenario research run: `python scripts/backtest.py --days 90 --tvl 100000 --cycles-per-day 4 --gas-gwei 50 --compare-scenarios --json-out cache/backtest-report.json` → `PASS`
- Static analysis: Slither run completed and triaged; only `pancakeCall()` event-order warnings remain

### Residual Risk

- Research KPIs remain model outputs, not realized live vault performance.
- `pancakeCall()` is still the main manual-audit hotspot because flash callbacks inherently combine external calls and event emission ordering.
- This release improves assurance discipline, but it does not replace an external smart-contract audit.
