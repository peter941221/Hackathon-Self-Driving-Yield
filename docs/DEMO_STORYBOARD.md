# Demo Storyboard (3 Minutes)

This is a scene-by-scene plan to record the demo video.


## Scene 1 (0:00 - 0:20) Title + Thesis

- Screen: README title + Key Ideas.

- Voice: "Autonomous yield engine on BNB Chain with on-chain volatility." 


## Scene 2 (0:20 - 0:50) Architecture

- Screen: README architecture block.

- Voice: "EngineVault orchestrates adapters, oracle, flash rebalance, withdrawal queue." 


## Scene 3 (0:50 - 1:20) Safety & Risk

- Screen: THREAT_MODEL.md (Risks + mitigations list).

- Voice: "We cap bounties, use TWAP warmup, and ONLY_UNWIND to reduce risk." 


## Scene 4 (1:20 - 2:10) Tests

- Screen: terminal.

- Command:

```bash
forge test
```

- Voice: "All tests pass, including invariants and ONLY_UNWIND negative case." 


## Scene 5 (2:10 - 2:50) Fork Cycle Demo

- Screen: terminal.

- Command:

```bash
forge script script/ForkCycleDemo.s.sol
```

- Voice: "We deposit USDT, run cycle(), see swaps and LP positions update." 


## Scene 6 (2:50 - 3:00) Wrap Up

- Screen:施工计划.MD milestone section.

- Voice: "M0-M4 done; M5/M6 focus on economics tuning and final demo." 
