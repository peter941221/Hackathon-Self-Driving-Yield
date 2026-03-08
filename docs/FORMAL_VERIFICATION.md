# Formal Verification

## Main Point

This repo now includes an actual symbolic-proof layer using `halmos`, not just conventional tests.

Current local result: `9/9` symbolic properties passing via `python scripts/run_formal.py`.

The goal is not to claim that the entire strategy and all external markets are mathematically proven.

The goal is to prove the **highest-value internal safety properties** that are realistically verifiable inside this repository.


## Proved Target Set

```text
Formal targets
├─ isolated cash accounting
├─ empty-vault deposit preview is one-to-one
├─ empty-vault redeem preview is zero
├─ no-profit => no bounty payout
├─ broken mark => deposit rejection
├─ ONLY_UNWIND blocks fresh exposure
├─ ONLY_UNWIND recovers after two safe cycles
├─ flash borrowed base caps at zero when underwater
└─ deposits pause when risk mode is `ONLY_UNWIND`
```

These properties are implemented in `test/FormalEngineVault.t.sol` and run by `scripts/run_formal.py`.


## What Is In Scope

- vault accounting in simplified local models
- share math in isolated paths
- risk-mode safety boundaries
- flash accounting under bounded local assumptions


## What Is Not In Scope

- proving Aster, Pancake, or upstream contracts themselves
- proving market prices are truthful
- proving backtest alpha or realized future PnL
- proving all integration behavior on live BNB Chain under every external condition


## Run It

```bash
python scripts/run_formal.py
```

Direct Halmos command shape:

```bash
halmos --contract EngineVaultFormalTest --function check_ --loop 2 --solver-timeout-branching 5s --solver-timeout-assertion 30s --json-output cache/halmos-formal.json --minimal-json-output
```

Note: the repo uses `python scripts/run_formal.py` as the preferred entrypoint because it safely wraps a local Halmos UI issue in this Windows terminal environment.


## Why This Matters

- It turns “we think these properties are true” into “a symbolic prover checked these properties under stated assumptions”.
- It makes investor and reviewer conversations much more concrete.
- It narrows future audit attention to the remaining hard surfaces, especially live integration and callback-heavy external execution.


## Current Boundary

This is **partial formal verification of core internal properties**, which is the honest and useful claim for this project stage.

That is much stronger than having no formal layer, and much more truthful than claiming the whole strategy system is fully proven.
