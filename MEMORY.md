# 项目记忆 (Project Memory)

## 2026-02-22
- OpenCode 外部资料核对: PancakeSwap V2 core/periphery + UniswapV2OracleLibrary; 记录 V2 fee 可能为 0.20% (需链上确认)。
- 更新 `技术方案2.txt`: VolatilityOracle 改为 cumulative TWAP；FlashRebalancer 偿还改用 `PancakeLibrary.getAmountsIn`；MEV 增加 ALP minOut；经济模型与附录补充 fee 需确认；标注 Aster 1001x ABI 需 Louper 导出。
- 完成项目根目录检视: 当前仅包含 `MEMORY.md` 与 `技术方案2.txt`，并完成技术方案初步审阅（至第 6 部分）。
- 完成 `技术方案2.txt` 全文审阅与深度分析: 认可 ALP 双重引擎与原子再平衡方向；指出关键风险在波动率/收益假设、bounty 的 gasprice 可操纵、TWAP 采样间隔与初始化、赎回队列激励不足、无管理员下的熔断策略需从“revert”改为“只减仓”。
- 更新 `技术方案2.txt`: 增加 bounty 安全护栏、TWAP 冷启动与采样间隔、ONLY_UNWIND 熔断模式、赎回激励、敏感性/压力测试要求；更新施工任务与附录差异矩阵。
- 新增 `施工计划.MD`: 按 Part1-12 细化验收标准，覆盖 OpenCode 补充项。
- 初始化 Foundry 项目: 生成 `foundry.toml` 并切换 `src = "contracts"`；移除默认 Counter 示例；新增接口 `IAsterDiamond.sol` / `IPancakeRouterV2.sol` / `IPancakePairV2.sol` / `IPancakeFactoryV2.sol` / `IERC20.sol`。
- 拆分文档: 新增 `README.md` / `ARCHITECTURE.md` / `ECONOMICS.md`，并保留 `技术方案2.txt` 原文件。
- 创建 GitHub Issues (Task 0-9): #2-#11 已生成，对应施工任务拆分。
