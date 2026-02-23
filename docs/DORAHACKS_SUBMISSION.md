# DoraHacks Submission Text

## Project Name
Self-Driving Yield Engine (Aster Dual-Engine Vault)

## One-Line Pitch
A fully autonomous, non-custodial yield engine that uses Aster ALP as both a primary yield source and an endogenous volatility hedge for PancakeSwap LPs.

## The Problem
DeFi yields are static and require active management. During market stress, liquidity providers suffer impermanent loss, while humans are too slow to rebalance efficiently. 

## Our Solution
We built an autonomous smart contract system ("Self-Driving Yield Engine") based on the Four Pillars:
1. **Integrate**: Uses AsterDEX ALP as the primary yield engine.
2. **Stack**: Re-deploys yield into PancakeSwap V2 LPs for automatic compounding.
3. **Automate**: Permissionless `cycle()` state machine with a bounded bounty mechanism.
4. **Protect**: 100% non-custodial, immutable parameters, and an atomic Flash Swap rebalancer.

## Design Highlights
- **ALP as a Hedge**: ALP is effectively a "short volatility" position (earns from trading volume/liquidations). It naturally offsets the impermanent loss of PancakeSwap LPs during high-volatility regimes.
- **Regime Switching**: An on-chain TWAP volatility oracle shifts allocations between CALM, NORMAL, and STORM regimes autonomously.
- **Risk Resilience**: Price deviations between TWAP and spot trigger an `ONLY_UNWIND` risk mode, preventing risky capital deployments during flash crashes.

## Technical Execution
- 100% Solidity (Foundry).
- 24/24 passing invariant and unit tests.
- 0 Slither static analysis findings (with documented intentional exclusions).
- Full on-chain verification (fork tests suite A-F).

## GitHub Repository
[Insert your GitHub Repo URL here]

## Demo Video
[Insert your Demo Video URL here]