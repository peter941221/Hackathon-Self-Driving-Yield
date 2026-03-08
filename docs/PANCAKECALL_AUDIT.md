# `pancakeCall()` Focus Review

## Scope

- Function under review: `contracts/core/EngineVault.sol:308`
- Reason: this is the remaining manual-review hotspot after tests, formal checks, and Slither cleanup.


## What The Function Does

```text
flashPair callback
    |
    v
validate caller + borrowed amount
    |
    v
remove LP
    |
    v
rebalance assets with borrowed-base context
    |
    v
rebalance hedge
    |
    v
ensure repay token
    |
    v
repay flash pair
```


## Review Outcome

- No blocking logic bug was identified in this review pass.
- The function is now materially cleaner than earlier versions because:
  - it no longer depends on persistent flash state like `inFlashRebalance` or `flashBorrowedAmount`.
  - borrowed flash context is passed as a local argument into `_rebalanceAssetsAfterFlashBorrow(...)`.
  - the remaining Slither output is limited to a single `reentrancy-events` warning.


## Why It Still Matters

This function is still the sharpest edge in the system because it combines:

- external callback entry,
- LP removal,
- internal rebalancing,
- hedge management,
- token swaps,
- and repayment.

That makes it the right place for human review even after static-analysis noise has been reduced.


## Checks Performed

- Caller authenticity:
  - requires `msg.sender == flashPair`
  - requires `sender == address(this)`
- Borrowed amount integrity:
  - callback amount must match decoded callback data
  - zero-borrow callback is rejected
- Accounting shape:
  - borrowed base is excluded from interim portfolio value via local context
  - no persistent flash-state carry remains after callback completion
- Repayment path:
  - `_ensureRepayToken(...)` runs before final transfer
  - `FLASH_REPAY` reverts if repayment cannot be completed


## Residual Risk

- Remaining static-analysis warning: event ordering around `FlashRepaid`
- Main practical risk: any future edits that reintroduce persistent flash state or widen callback side effects


## Guidance For Future Changes

1. Keep flash execution context local, not persistent.
2. Avoid adding new event or accounting side effects before repay without a very strong reason.
3. Re-run `forge test`, `python scripts/run_formal.py`, and Slither after every callback-path edit.
