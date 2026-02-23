# Hackathon Analysis

本文件补齐题目分析、竞品差异与核心创新的可验证说明。


## Part1 题目分析与评估

目标与约束:

- 四大支柱: Integrate / Stack / Automate / Protect.

- 约束: 非托管 (Non-Custodial), 无管理员, permissionless 执行.


Design Prompts -> 解决方案映射:

- Hedging: 1001x 做空对冲 LP base exposure, 使用 delta band 控制开平仓.

- Volatility: TWAP 累积价格 + MIN_SAMPLES 冷启动, Regime 切换.

- Resilience: ONLY_UNWIND 风险模式 + Flash 原子再平衡 + 提现队列.


内部评分权重 (Internal Rubric, 非官方):

- Integrate 30

- Stack 25

- Automate 25

- Protect 20


策略改进逻辑 (Iteration Loop):

```
Observe  ->  Diagnose  ->  Adjust  ->  Validate  ->  Record
  |            |            |            |            |
  |            |            |            |            └─ 更新文档/参数
  |            |            |            └─ fork/invariant tests
  |            |            └─ 调整阈值/配比/保护机制
  |            └─ 分析收益/风险/偏差
  └─ 读取链上状态/事件
```


## Part2 竞品分析 (Competitive Landscape)

Case A: GMX GLP 类收益金库 (如 GLP auto-compounder)

- 优点: 收益来源多 (交易费 + funding + 清算), 使用简单.

- 缺点: 主要依赖单一资产池, 缺少对 LP IL 的显式对冲.


Case B: Pancake V2 LP Auto-Compounder

- 优点: 复利高效, 费用透明.

- 缺点: IL 暴露明显, 缺少波动率自适应机制.


Case C: Delta-Neutral Structured Vault (Spot + Perp)

- 优点: 对冲显式, 风险可量化.

- 缺点: 需要频繁再平衡, 对 gas 与 funding 敏感.


非托管冲突点 (asUSDF):

- 若收益策略依赖 permissioned stable 或托管式资金池, 将与 Non-Custodial 目标冲突.

- 本方案避免依赖 asUSDF, 全流程保持用户资产自持与不可篡改参数.


差异化矩阵 (Summary):

```
┌───────────────────────────┬────────────────────────────┬────────────────────────────┐
│ 维度                      │ 传统 LP 金库               │ 本项目 (Self-Driving)      │
├───────────────────────────┼────────────────────────────┼────────────────────────────┤
│ 波动率响应                │ 固定配比                   │ Regime 动态配比            │
├───────────────────────────┼────────────────────────────┼────────────────────────────┤
│ 对冲                      │ 无                         │ 1001x 做空对冲             │
├───────────────────────────┼────────────────────────────┼────────────────────────────┤
│ 再平衡                    │ 多笔交易                   │ Flash 原子再平衡           │
├───────────────────────────┼────────────────────────────┼────────────────────────────┤
│ 自动化                    │ 半自动 / keeper 依赖       │ permissionless cycle()     │
└───────────────────────────┴────────────────────────────┴────────────────────────────┘
```


## Part3 核心创新 (ALP 双重引擎)

ALP 收益来源拆解 (详见 `ECONOMICS.md`):

- 交易手续费

- Funding 收益

- 清算收益


ALP 对冲 LP IL 的逻辑链:

```
市场波动上升
   │
   ├─ LP IL 风险上升
   │
   └─ 交易量与清算增加
          │
          └─ ALP 收益上升

=> ALP 收益与波动正相关, 形成天然对冲
```


数学关系与配置原则 (简化版):

- 目标配比 = f(volatility), 由 Regime 决定 ALP/LP 权重.

- 对冲缺口 = LP base exposure - Short exposure.

- 当缺口 > band: 追加做空; 当缺口 < -band: 平空降风险.


风险韧性 (Resilience):

- ONLY_UNWIND 限制加仓.

- Bounty 上限与 gasPrice cap 防止恶意调用.

- 允许 partial withdraw, 降低极端行情流动性压力.
