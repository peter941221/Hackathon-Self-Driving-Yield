# Slither Notes

This file records the latest Slither findings and rationale.


## Latest Run

- Command: `slither . --exclude-dependencies`

- Date: 2026-02-23


## Findings (Summary)

1) weak-prng

- Source: `PancakeOracleLibrary.currentBlockTimestamp()`.

- Rationale: Uniswap-style oracle logic; timestamp modulo is expected.

2) divide-before-multiply

- Source: TWAP math, borrow amount math, bounty math.

- Rationale: Deterministic integer math; no unsafe overflow in current ranges.

3) incorrect-equality

- Source: zero checks for balances, LP supply, totalValue.

- Rationale: Intentional early exits; not a vulnerability.

4) reentrancy-no-eth

- Source: `EngineVault.cycle()`, `EngineVault.onFlashRebalance()`, `WithdrawalQueue.claimWithdraw()`.

- Mitigation: `nonReentrant` guards on entrypoints; external calls are expected protocol interactions.

5) reentrancy-benign

- Source: `EngineVault._updateRegime()` and `WithdrawalQueue.requestWithdraw()`.

- Rationale: State is guarded by `nonReentrant` and writes are deterministic.

6) unused-return

- Source: reserves read helpers and adapter calls.

- Rationale: values are intentionally ignored or only used for side-effects.

7) events-maths

- Source: `flashBorrowedAmount` assignments in `onFlashRebalance()`.

- Rationale: internal accounting only; event is optional for P0.

8) timestamp

- Source: cooldown, cycle interval, TWAP sampling.

- Rationale: time-based controls are required for safety.

9) cyclomatic-complexity

- Source: `_increaseLp()` branching.

- Rationale: expected for swap + addLiquidity flow; refactor later if needed.

10) low-level-calls

- Source: `AsterAlpAdapter.canBurn()` staticcall to diamond.

- Rationale: ABI optionality; `staticcall` is required for backward compatibility.

11) naming-convention

- Source: `IAsterDiamond.ALP()`.

- Rationale: upstream ABI requires this exact name.


## Action

- No code changes applied; warnings documented for audit.
