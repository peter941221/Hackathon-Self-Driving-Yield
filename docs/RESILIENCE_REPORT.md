# Resilience Report

## Main Point

As of `2026-03-08`, Self-Driving Yield Engine has a credible resilience stack for investor diligence.

It is not just a smart-contract repo with passing unit tests.

It now combines:

- green mainline CI,
- green nightly fork-chaos execution,
- partial formal verification,
- invariant testing,
- adversarial failure-path testing,
- static-analysis triage,
- and a written manual review of the remaining callback hotspot.


## Current Status

```text
Validation stack
├─ Regression         54/54 PASS
├─ Invariants         5/5 PASS
├─ Formal            10/10 PASS
├─ Slither            1 known finding
├─ Main CI            green
└─ Nightly chaos      green
```

- Main CI latest success: run `22814604193`
- Nightly chaos latest success: run `22814462822`
- Latest release: `v0.1.1`


## What We Exercise

### Contract correctness

- vault accounting
- share pricing boundaries
- bounty behavior
- `ONLY_UNWIND` entry and recovery
- flash-accounting edge handling

### Failure behavior

- oracle divergence
- blocked hedge close
- ALP cooldown unwind limits
- gas spike / bounded bounty
- constrained flash liquidity
- degraded RPC timeout behavior


## Remaining Hotspot

- Primary remaining audit focus: `contracts/core/EngineVault.sol:308`
- Current static-analysis remainder: one `reentrancy-events` warning on `pancakeCall()`
- Manual review note: `docs/PANCAKECALL_AUDIT.md`


## Investor Interpretation

- The system does not claim perfection.
- The remaining risk is concentrated and documented.
- The repo demonstrates both prevention and failure-handling discipline.
- The resilience process is now repeatable, not ad hoc.


## Honest Boundary

- This is not a claim that all external protocols and market conditions are formally proven.
- It is a claim that the highest-value internal safety properties and key dependency-failure paths are now exercised in a disciplined way.
