# Assurance Packet

## Main Point

Self-Driving Yield Engine is not claiming “fully formally verified production software”.

It is claiming something more credible for this stage:

- reproducible research,
- strong contract regression coverage,
- machine-checked invariants,
- DeFi adversarial failure-path tests,
- static-analysis triage,
- and optional BNB Chain fork checks.

That is the right evidence stack for an investor conversation today.


## Why It Matters

```text
Interesting strategy
        |
        v
Needs proof of discipline
        |
        v
Research + invariants + adversarial tests + Slither + CI
        |
        v
Faster investor diligence
```

- The repo now shows that safety work is becoming systematic, not anecdotal.
- The strongest evidence is around capital accounting, risk-mode behavior, and dependency failure handling.


## Proof Points

| Layer | What it proves | Where it lives |
|---|---|---|
| Research model | strategy story is reproducible under multiple assumptions | `scripts/backtest.py` |
| Economic framing | formulas and caveats are explicit | `ECONOMICS.md` |
| Regression tests | main contract behavior stays intact | `forge test` |
| Invariants | key capital-safety properties hold across randomized sequences | `test/Invariant.t.sol` |
| Formal verification | nine core internal properties hold under symbolic execution | `test/FormalEngineVault.t.sol` |
| Adversarial tests | bad dependencies end in safe revert or safe degradation | `test/AssuranceAdversarial.t.sol` |
| Static analysis | flash callback and external-call hotspots stay visible | `docs/SLITHER_NOTES.md` |
| Manual audit focus | remaining callback hotspot has a written human review | `docs/PANCAKECALL_AUDIT.md` |
| Optional fork checks | live upstream contracts still look readable on BNB Chain | `test/ForkSuite.t.sol` |


## Scenario Menu

The backtest supports five investor-usable scenarios:

- `baseline`
- `stress`
- `funding_adverse`
- `liquidity_crunch`
- `gas_spike`

These are useful for diligence because they stress different failure modes without pretending to be realized live PnL.


## Reproduce It

```bash
forge build
forge test
forge test --match-path test/Invariant.t.sol
python -m py_compile scripts/backtest.py
python scripts/backtest.py --days 90 --tvl 100000 --cycles-per-day 4 --gas-gwei 50 --compare-scenarios --json-out cache/backtest-report.json
slither . --exclude-dependencies --exclude incorrect-equality,timestamp,low-level-calls,naming-convention,cyclomatic-complexity
```

Optional fork check:

```bash
export BSC_RPC_URL="https://bsc-dataseed.binance.org/"
forge test --match-path test/ForkSuite.t.sol
```


## Boundaries

- This is still a model-driven assurance stack, not an external audit.
- Static analysis findings still require human judgment.
- If the project moves toward real capital deployment, the next step is a tighter spec around a very small set of core formal properties.


## Next Steps

1. Keep `docs/SLITHER_NOTES.md` synced to the latest real run.
2. Extend invariants around `ONLY_UNWIND` and flash-callback safety before adding heavier formal tooling.
3. Use this file as the investor-facing proof index and route deeper readers to the underlying commands.
