# Operational Resilience Brief

## Main Point

Self-Driving Yield Engine now has a clearer resilience story than a typical hackathon repo.

It is no longer just “contracts + tests”.

It is now:

- CI-gated,
- partially formally verified,
- static-analysis triaged,
- manually reviewed at the main callback hotspot,
- and backed by nightly DeFi-adapted chaos experiments.


## Current Evidence Stack

```text
Operational resilience
├─ main CI green
├─ nightly chaos green
├─ formal 10/10
├─ invariants 5/5
├─ regression 54/54
├─ one known Slither finding
└─ callback manual review written down
```


## What This Means For Investors

- The system is not being presented as “perfect” or “finished forever”.
- The main remaining hotspot is visible and documented.
- The validation stack now tests both correctness and failure behavior.


## Current Status

- Regression tests: `54/54`
- Invariants: `5/5`
- Formal properties: `10/10`
- Slither: `1` known triaged finding
- Main callback review: `docs/PANCAKECALL_AUDIT.md`
- Nightly chaos workflow: `.github/workflows/nightly-chaos.yml`


## Failure Modes We Now Exercise

- oracle divergence
- `ONLY_UNWIND` entry and recovery
- blocked hedge close
- ALP cooldown unwind limits
- gas spike / bounded bounty
- flash liquidity shortfall
- degraded RPC timeout behavior


## Remaining Honest Boundary

- This is still not a claim that the full strategy and external markets are mathematically proven.
- It is a claim that the repo now has a credible resilience process around the highest-risk internal and dependency-driven behaviors.
