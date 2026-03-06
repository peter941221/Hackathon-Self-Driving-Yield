# Economics

This document summarizes yield sources, costs, scenario simulations, and sensitivity requirements.


## 1. Yield Sources

```
Source              | Est. APY | Notes
--------------------|----------|----------------------------
ALP market PnL      | 5-15%    | Trader losses accrue to ALP
ALP trading fees    | 3-8%     | 0.08% * volume
ALP funding         | 1-5%     | Perp funding payments
ALP liquidations    | 1-3%     | Liquidation penalties to pool
V2 LP trading fees  | 5-20%    | 0.20% * volume (BTCB/USDT)
```


## 2. Cost Sources

```
Cost Item           | Est. Impact | Notes
--------------------|-------------|----------------------------
1001x open/close    | -0.16%      | 0.08% * 2
1001x execution     | -$0.50      | per open
1001x funding       | -1~-5%      | short usually pays funding
V2 LP IL            | -2~-10%     | depends on volatility
ALP mint/burn fee   | -0.5~-2%    | dynamic fee
```


## 2.1 Model Inputs

- TVL: total assets (USDT).

- Volume: average daily volume for ALP and V2 LP.

- Fees: Pancake V2 fee (0.20% confirmed) / ALP fee (dynamic).

- Funding: 1001x funding range (-5% ~ +2%).

- Gas: 50 / 200 / 500 gwei.

- Rebalance frequency: cycle() calls per day.


## 2.2 Formulas

```
Price Ratio                 r = P_t / P_{t-1}
LP Mark-to-Market Factor    = sqrt(r)
LP Impermanent Loss         = 2*sqrt(r)/(1+r) - 1

LP Fee Yield (daily)      = APR_lp(regime) / 365
ALP Carry Yield (daily)   = APR_alp(regime) / 365
ALP Vol Capture           = k_vol(regime) * |return|
ALP Move Drag             = k_drag(regime) * |return|

Short Hedge PnL (daily)   = -0.5 * hedgeRatio * baseReturn
Funding Cost (daily)      = 0.5 * hedgeRatio * fundingBps(regime) / 10000

Rebalance Turnover        = 0.5 * sum(|actualWeight - targetWeight|)
Rebalance Cost            = turnover * (poolFeeBps + slippageBps)
Hedge Trade Cost          = 0.5 * |targetLP - currentLP| * hedgeTradeBps
Gas Cost                  = gasUsed * gasPrice * bnbPrice * actionFactor

Portfolio NAV_t           = ALP_t + LP_t + Buffer_t - Costs_t
```

Notes:

- This upgraded backtest no longer uses random noise for yield generation.

- LP uses the constant-product full-range V2 approximation in quote terms.

- The hedge is modeled as a short against roughly half of LP notional (LP base exposure proxy).

- Costs are split into rebalance cost, hedge trade cost, funding cost, and gas cost.


## 2.3 Research Model (2026-03-06)

```text
[BTC Price Path]
      |
      v
[Daily Returns] --> [7d RMS Volatility] --> [Hysteresis Regime Engine]
                                                |
                                                v
                                  [Dynamic Target Weights CALM/NORMAL/STORM]
                                                |
                 +------------------------------+------------------------------+
                 |                              |                              |
                 v                              v                              v
           [ALP Carry + Vol Capture]      [LP sqrt(r) + Fees]        [Short Hedge - Funding]
                 |                              |                              |
                 +------------------------------+------------------------------+
                                                |
                                                v
                                      [Turnover + Cost Model]
                                                |
                                                v
                                             [NAV Path]
```

Model choices:

- Regime detection uses a 7-day RMS of log returns with hysteresis bands.

- Dynamic strategy rebalances only when target drift exceeds the configured turnover threshold.

- Benchmarks are explicit:
  - `dynamic`: regime-switching vault weights.
  - `fixed_normal`: static NORMAL allocation.
  - `pure_alp`: concentration benchmark.
  - `pure_lp`: fee-only + IL benchmark.

- This remains a research model, not a claim of realized production PnL.


## 2.4 Data Snapshot (2026-02-23)

Sources:

- BTCB/USDT pair data: Dexscreener API (`https://api.dexscreener.com/latest/dex/pairs/bsc/0x3F803EC2b816Ea7F06EC76aA2B6f2532F9892d62`).

- ALP price: on-chain `alpPrice()` from Aster Diamond.

- Aster BSC TVL: DeFiLlama protocol data (`https://api.llama.fi/protocol/aster`).


Snapshot values:

- BTCB price (USD): 64,795.77.

- 24h volume (BTCB/USDT): 26,880.57.

- LP liquidity (USD): 178,521.77.

- LP reserves: 1.3775 BTCB and 89,260 USDT.

- ALP price: 180,337,314 (1e8 scale) => 1.8034 USD.

- Aster BSC TVL: 828,912,836 USD.


## 3. Strategy Weights

### CALM (vol < 1%)

```
Allocation: ALP 40% / LP 57% / Buffer 3%
Interpretation: fee collection still matters, but ALP is not yet dominant.
```

### NORMAL (1%-3%)

```
Allocation: ALP 60% / LP 37% / Buffer 3%
Interpretation: balanced carry, LP fees, and hedge funding drag.
```

### STORM (>= 3%)

```
Allocation: ALP 80% / LP 17% / Buffer 3%
Interpretation: shift toward ALP when volatility is high and LP IL risk is largest.
```


## 4. Latest Backtest Output (90d, 2026-03-06)

Run:

```bash
python scripts/backtest.py --days 90 --tvl 100000 --cycles-per-day 4 --gas-gwei 50 --compare-scenarios
```

### 4.1 Baseline Scenario

```text
Source: coingecko
Market regime days: CALM 10 / NORMAL 65 / STORM 15

Strategy       CAGR    AnnVol  Sharpe  MaxDD   CumRet
dynamic        14.36%  1.15%   11.64   -0.06%  3.36%
fixed_normal   13.11%  0.68%   18.05    0.00%  3.08%
pure_alp       23.58%  1.48%   14.36    0.00%  5.36%
pure_lp        -1.43%  0.68%   -2.11   -0.64% -0.35%
```

Dynamic cost breakdown:

- Rebalance cost: `$264.89`

- Hedge trade cost: `$20.36`

- Funding cost: `$497.70`

- Gas cost: `$37.50`

### 4.2 Stress Scenario

```text
Source: coingecko
Market regime days: CALM 10 / NORMAL 65 / STORM 15

Strategy       CAGR    AnnVol  Sharpe  MaxDD   CumRet
dynamic        10.02%  1.52%    6.31   -0.17%  2.38%
fixed_normal    8.69%  0.92%    9.10   -0.02%  2.08%
pure_alp       22.91%  1.89%   10.91   -0.00%  5.22%
pure_lp       -11.07%  0.73%  -15.97   -2.85% -2.85%
```

Reading the output:

- `dynamic` now behaves as an explicit middle path between pure ALP concentration and pure LP drawdown.

- `pure_alp` is a concentration benchmark, not the target product shape; the vault thesis is diversified automation, not all-in ALP.

- `pure_lp` remains the cleanest demonstration of why IL + funding-aware hedging matters.

## 5. Sensitivity and Stress Tests

Suggested sensitivity axes:

1) Pancake V2 fee: 0.20% (baseline) and 0.25% (stress).

2) Funding: -5% ~ +2%.

3) Gas spike: 50 / 200 / 500 gwei.

4) One-way move: BTC +/- 30%.

5) Low liquidity: Flash Swap cost increases.

Output requirements:

- Mark the ONLY_UNWIND trigger conditions.

- Include rebalance frequency and yield deltas.


## 6. Sensitivity Output Template

```
Scenario: Gas 200 gwei, Funding -3%, Fee 0.25% (stress)
- Net APY (min / avg / max): __ / __ / __
- Cycle / day: __
- ONLY_UNWIND Trigger: yes / no

Scenario: 30% one-way BTC move
- Net APY (min / avg / max): __ / __ / __
- LP IL impact: __
- Hedge effectiveness: __
```


## 7. Notes and Caveats

- The simulator is intentionally zero-dependency and reproducible, so it favors transparency over market microstructure completeness.

- ALP return is still a parametric approximation (`carry + volatility capture - move drag`), not a replay of real Aster vault state.

- Hedge PnL uses an LP base-exposure proxy; production PnL depends on actual margin, entry price, funding path, and liquidation rules.

- Outputs are model-based. Re-run before any investor meeting or submission to refresh the market path and scenario outputs.
