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
LP Fee Yield (daily) = volumeLP * feeLP
ALP Fee Yield (daily) = volumeALP * feeALP

Funding Cost (daily) = notionalShort * fundingRate
Trading Fee Cost (daily) = openCloseFee * notionalShort

Gas Cost (daily) = cycleCount * gasUsed * gasPrice * bnbPrice

Net Yield (daily) = ALP + LP - Funding - TradingFee - Gas - IL
Net APY = Net Yield (daily) * 365 / TVL
```

Notes:

- notionalShort scales with LP base exposure.

- cycleCount = 86400 / minCycleInterval.

- IL is proxied by volatility.


## 3. Three Regime Scenarios

### CALM (vol < 1%)

```
Allocation: ALP 40% / LP 57% / Buffer 3%
Assume: $100,000 TVL, 0.5% volatility
Net yield: ~9.9% APY
```

### NORMAL (1%-3%)

```
Allocation: ALP 60% / LP 37% / Buffer 3%
Assume: $100,000 TVL, 2% volatility
Net yield: ~11.6% APY
```

### STORM (>= 3%)

```
Allocation: ALP 80% / LP 17% / Buffer 3%
Assume: $100,000 TVL, 5% volatility
Net yield: ~16.8% APY
```


## 4. Risk-Adjusted Return (Sharpe)

```
Dynamic mix   E[Return] 12%  Std 4%   Sharpe 1.75
Fixed 80/20   E[Return] 9%   Std 6%   Sharpe 0.67
Pure ALP      E[Return] 15%  Std 10%  Sharpe 1.00
Pure V2 LP    E[Return] 12%  Std 12%  Sharpe 0.58
```


## 5. Sensitivity and Stress Tests

Provide min / avg / max net yield ranges for:

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


## 7. Example Outputs (Illustrative)

Assumptions for illustration:

- TVL: $100,000.

- Daily volume: LP $500k, ALP $800k.

- Funding: -3%.

- Gas: 200 gwei.

- Cycle frequency: 24 per day.


Scenario: Gas 200 gwei, Funding -3%, Fee 0.25% (stress)

- Net APY (min / avg / max): 6% / 10% / 14%.

- Cycle / day: 24.

- ONLY_UNWIND Trigger: yes, if TWAP deviation > 5%.


Scenario: 30% one-way BTC move

- Net APY (min / avg / max): -3% / 5% / 12%.

- LP IL impact: -8% to -12% on LP leg.

- Hedge effectiveness: 60% to 85% offset of IL.
