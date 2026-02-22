# Self-Driving Yield Engine v2.0

面向 BNB Chain 的全自动、非托管收益引擎 (Self-Driving Yield Engine)。

核心目标: 在无需人工/多签/链下 keeper 的情况下，自动组合 AsterDEX Earn 与 PancakeSwap LP，并用 1001x 对冲实现风险调整后更优收益。


## 四大支柱 (Four Pillars)

1. Integrate: AsterDEX Earn (ALP) 作为主收益引擎

2. Stack: PancakeSwap V2 LP 作为可组合收益层

3. Automate: permissionless cycle() + on-chain 波动率 Oracle

4. Protect: 1001x Delta Hedge + 风控熔断


## 核心创新 (Key Innovations)

- ALP 双重引擎 (Dual Engine): 同时承担收益与波动率对冲

- Flash Rebalance: 单笔交易内完成再平衡，减少 MEV 面

- Regime Switching: CALM / NORMAL / STORM 自动切换

- Fully On-Chain: 无 Chainlink 依赖，无外部 keeper


## 系统概览 (Architecture at a Glance)

```
User (USDT)
   |
deposit / redeem
   |
   v
EngineVault (ERC-4626)
   |
   +-----------------------+-----------------------+
   |                       |                       |
ALP Adapter           Pancake V2 Adapter      1001x Adapter
(AsterDEX Earn)       (LP + Flash Swap)       (Delta Hedge)
   |
   v
ALP Token        V2 LP Token + Flash Rebalance    Perp Positions

Cross-Cutting:
- VolatilityOracle (TWAP)
- WithdrawalQueue (No Admin)
```


## 核心流程 (cycle)

```
PHASE 0  Pre-checks (minCycleInterval, protocol status)
PHASE 1  Read state (ALP, LP, hedge, cash)
PHASE 2  TWAP snapshot + Regime
PHASE 3  Target allocation
PHASE 4  Rebalance (Flash or incremental)
PHASE 5  Delta hedge
PHASE 6  Bounty payout + events
```


## 风控与安全 (Risk Controls)

- MEV 防护: slippage + deadline + Flash Rebalance

- Bounty 护栏: gasPrice cap + cashBuffer cap

- TWAP 冷启动: MIN_SAMPLES + minSnapshotInterval

- ONLY_UNWIND 熔断模式: 只允许减仓，不锁死资金


## 文档索引 (Docs)

- 技术方案全文: `技术方案2.txt`

- 架构文档: `ARCHITECTURE.md`

- 经济模型: `ECONOMICS.md`

- 施工计划: `施工计划.MD`


## 开发与测试 (Foundry)

```bash
forge build
forge test
forge fmt
```

Fork 测试需要 BSC RPC 与固定区块号 (见 `技术方案2.txt` / `施工计划.MD`)。
