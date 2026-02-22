# Economics

本文件总结收益来源、成本、场景模拟与敏感性分析要求。


## 1. 收益来源 (Yield Sources)

```
收益来源          | 预估 APY | 说明
------------------|----------|--------------------------------
ALP 做市 PnL      | 5-15%    | 交易者统计亏损 = ALP 盈利
ALP 交易手续费    | 3-8%     | 0.08% * 交易量
ALP 资金费率      | 1-5%     | 永续合约 funding
ALP 清算收益      | 1-3%     | 爆仓保证金归入池
V2 LP 交易费      | 5-20%    | 0.17% * 交易量 (BTCB/USDT)
```


## 2. 成本来源 (Costs)

```
成本项            | 预估影响 | 说明
------------------|----------|--------------------------------
1001x 开平仓费     | -0.16%  | 0.08% * 2
1001x 执行费       | -$0.50  | 每次开仓
1001x 资金费率     | -1~-5%  | 做空通常付 funding
V2 LP IL          | -2~-10% | 取决于波动率
ALP mint/burn fee | -0.5~-2%| 动态费率
```


## 2.1 关键输入 (Model Inputs)

- TVL: 总资产规模 (USDT)

- 交易量: ALP 与 V2 LP 的日均成交量

- 手续费: Pancake V2 fee (0.20%~0.25%) / ALP fee (动态)

- Funding: 1001x 资金费率区间 (-5% ~ +2%)

- Gas: 50 / 200 / 500 gwei

- Rebalance 频率: cycle() 次数 / 天


## 2.2 公式 (Formulas)

```
LP Fee Yield (daily) = volumeLP * feeLP
ALP Fee Yield (daily) = volumeALP * feeALP

Funding Cost (daily) = notionalShort * fundingRate
Trading Fee Cost (daily) = openCloseFee * notionalShort

Gas Cost (daily) = cycleCount * gasUsed * gasPrice * bnbPrice

Net Yield (daily) = ALP收益 + LP收益 - Funding - TradingFee - Gas - IL
Net APY = Net Yield (daily) * 365 / TVL
```

说明:

- notionalShort 与 LP base exposure 成正比

- cycleCount = 86400 / minCycleInterval

- IL 以波动率 proxy 估算


## 3. 三种 Regime 模拟

### CALM (vol < 1%)

```
配比: ALP 40% / LP 57% / Buffer 3%
假设: $100,000 TVL, 波动率 0.5%
净收益: ~9.9% APY
```

### NORMAL (1%-3%)

```
配比: ALP 60% / LP 37% / Buffer 3%
假设: $100,000 TVL, 波动率 2%
净收益: ~11.6% APY
```

### STORM (>= 3%)

```
配比: ALP 80% / LP 17% / Buffer 3%
假设: $100,000 TVL, 波动率 5%
净收益: ~16.8% APY
```


## 4. 风险调整收益 (Sharpe)

```
我们(动态)  E[Return] 12%  Std 4%   Sharpe 1.75
固定80/20  E[Return] 9%   Std 6%   Sharpe 0.67
纯 ALP     E[Return] 15%  Std 10%  Sharpe 1.00
纯 V2 LP   E[Return] 12%  Std 12%  Sharpe 0.58
```


## 5. 敏感性与压力测试 (Required)

必须补充以下区间分析，并给出 min/avg/max 净收益区间:

1) Pancake V2 fee: 0.20% 与 0.25%

2) Funding: -5% ~ +2%

3) Gas spike: 50 / 200 / 500 gwei

4) 单边行情: BTC 单边 30% 变动

5) 低流动性: Flash Swap 成本上升

输出要求:

- 标注触发 ONLY_UNWIND 的条件

- 给出再平衡频率与收益变化


## 6. 敏感性输出模板 (Template)

```
Scenario: Gas 200 gwei, Funding -3%, Fee 0.25%
- Net APY (min / avg / max): __ / __ / __
- Cycle / day: __
- ONLY_UNWIND Trigger: yes / no

Scenario: 30% 单边行情 (BTC)
- Net APY (min / avg / max): __ / __ / __
- LP IL impact: __
- Hedge effectiveness: __
```
