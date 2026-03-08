# 🧠 Hackathon-Self-Driving-Yield AGENTS

```text
Project AGENTS
├─ Project goal
├─ Working commands
├─ Repo map
├─ Project rules
├─ Validation
└─ Reusable lessons
```

## 1) Project Snapshot

- Project name: `Self-Driving Yield Engine`
- Main goal: ship and defend a DeFi yield vault that rotates across ALP, Pancake V2 LP, and a short hedge with no admin controls.
- Current phase: stabilizing + investor-facing assurance.
- Primary outcome Peter cares about: investor confidence backed by reproducible evidence.
- Main constraints:
  - hackathon-speed repo with real capital-risk logic.
  - BNB Chain integrations are optional in local tests and only partially available on forks.
  - immutable-parameter design means behavior changes require code changes, not ops overrides.

## 2) Working Commands

- Build: `forge build`
- Test: `forge test`
- Invariants: `forge test --match-path test/Invariant.t.sol`
- Formal: `python scripts/run_formal.py`
- Static analysis: `slither . --exclude-dependencies --exclude incorrect-equality,timestamp,low-level-calls,naming-convention,cyclomatic-complexity`
- Research backtest: `python scripts/backtest.py --days 90 --tvl 100000 --cycles-per-day 4 --gas-gwei 50 --compare-scenarios --json-out cache/backtest-report.json`
- Format: `forge fmt`
- Optional fork checks:
  - `set BSC_RPC_URL=https://bsc-dataseed.binance.org/`
  - `forge test --match-path test/ForkSuite.t.sol`
- Key environment notes:
  - `BSC_RPC_URL` is optional; fork tests safely no-op when unset.
  - `PRIVATE_KEY` is only needed for `script/Deploy.s.sol`.
  - Do not write temporary Slither output into `/out/`; Slither rebuilds that directory.

## 3) Repo Map

- Main entrypoints:
  - `contracts/core/EngineVault.sol`
  - `contracts/core/VolatilityOracle.sol`
  - `contracts/core/WithdrawalQueue.sol`
  - `scripts/backtest.py`
- Important directories:
  - `contracts/` core vault, adapters, libraries, interfaces.
  - `test/` unit, invariant, fork, and adversarial tests.
  - `script/` deploy and chain-check scripts.
  - `docs/` investor, release, threat, assurance, and analysis docs.
- Critical paths:
  - vault share pricing and `totalAssets()` accounting.
  - `cycle()` state machine, risk-mode transitions, and bounty calculation.
  - hedge rebalance and flash swap accounting.
- Test locations:
  - unit/regression: `test/*.t.sol`
  - invariants: `test/Invariant.t.sol`
  - optional fork checks: `test/ForkSuite.t.sol`
- Deployment/runtime:
  - local Foundry repo.
  - optional GitHub Actions CI in `.github/workflows/ci.yml`.

## 4) Project Rules

- Follow existing Foundry + Solidity style before adding structure.
- Prefer mocks and deterministic unit tests over adding new integration dependencies.
- Keep public interfaces stable unless a user request requires API changes.
- When testing failures, prefer proving either safe revert or safe degradation to `ONLY_UNWIND`.
- Reuse existing investor docs instead of creating parallel narratives.
- Repo-specific rules:
  - Naming: test names should describe the safety property, not just the code path.
  - File organization: shared Solidity test doubles belong in `test/helpers/`.
  - Dependency preference: stick to Foundry, Python stdlib, and existing analyzer tooling.
  - Extra caution: anything touching NAV, share pricing, risk mode, flash accounting, or bounty math is `H` risk.

## 5) Validation Playbook

- Risk Tier defaults:
  - `L` = docs, copy, tiny refactor -> smoke checks.
  - `M` = normal behavior change -> targeted tests + key-path regression.
  - `H` = vault accounting, risk controls, external-call safety -> full test suite + static analysis + backtest smoke.
- Minimum checks for this project:
  - Smoke: `forge build`
  - Unit/regression: `forge test`
  - Invariants: `forge test --match-path test/Invariant.t.sol`
  - Research/tooling: `python -m py_compile scripts/backtest.py`
  - Formal: `python scripts/run_formal.py`
  - Static analysis: Slither command above.
  - Optional manual critical path: `forge test --match-path test/ForkSuite.t.sol` with `BSC_RPC_URL`.
- If validation is blocked:
  - say exactly what blocked it.
  - run the nearest local substitute.
  - leave exact follow-up commands.

## 6) Reusable Lessons

- `flashPair` must differ from `v2Pair` or Pancake/Uniswap pair locking will break flash rebalance.
- Fork tests are intentionally optional; they should not block local work when no RPC is configured.
- `ONLY_UNWIND` is a safety boundary: tests should prove it does not add fresh risk.
- Investor-facing claims should point to reproducible docs and commands, not just README badges.
- Slither notes must stay aligned with the latest actual run, not an older “0 findings after exclusions” snapshot.
