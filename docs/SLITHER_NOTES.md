# Slither Notes

This file records the latest Slither findings and the current triage.


## Latest Run

- Command: `slither . --exclude-dependencies --exclude incorrect-equality,timestamp,low-level-calls,naming-convention,cyclomatic-complexity`
- Date: 2026-03-08
- Result: `1` result across `1` detector family.


## Current Findings

### `reentrancy-events`

- Scope: `contracts/core/EngineVault.sol:308`
- Function: `pancakeCall(address,uint256,uint256,bytes)`
- Why flagged: the flash callback emits events after a chain of external calls.
- Current rationale:
  - callback access is pinned to `flashPair`.
  - `sender` must equal `address(this)`.
  - the callback no longer depends on persistent flash state such as `inFlashRebalance` or `flashBorrowedAmount`.
  - flash accounting is now passed as local context into `_rebalanceAssetsWithContext(...)` instead of storage.
- Residual risk: low-medium by itself. The remaining issue is about event ordering around a callback-heavy path, not an obvious state-corruption vector.


## What Was Reduced

This session reduced Slither noise in three steps:

- `7 -> 4`: removed `unused-return`, `reentrancy-benign`, and `uninitialized-local` findings.
- `4 -> 2`: removed `reentrancy-no-eth` by taking flash callback context out of storage and into local parameters.
- `2 -> 1`: split the callback rebalance path so only `FlashRepaid` remains as an event emitted after external calls.
- Remaining finding is now a single event-order warning around `pancakeCall()`.


## Excluded Detectors (CLI)

The following detectors are excluded because they are noisy for this design and already understood:

- `incorrect-equality`: zero checks are intentional guard clauses.
- `timestamp`: time-based controls are required for TWAP windows and cooldowns.
- `low-level-calls`: `staticcall` is required for ABI optionality.
- `naming-convention`: `IAsterDiamond.ALP()` follows upstream ABI naming.
- `cyclomatic-complexity`: rebalance flow is branching-heavy by design.


## Inline Suppressions

- `divide-before-multiply`: used in math-heavy sections where order is deliberate.
- Remaining flash-callback review burden is documented here rather than hidden behind stale “0 findings” wording.


## Action

- Treat `pancakeCall()` as the main remaining manual-review surface.
- Keep running Slither on every material vault-flow change.
- If the team wants to go further, the next step is a more opinionated flash callback decomposition, not more documentation-only suppression.
