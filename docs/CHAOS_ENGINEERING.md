# Chaos Engineering Fit

## Main Point

This project should **not** introduce classic Kubernetes-style chaos engineering as its primary next step.

It **should** introduce a DeFi-adapted chaos layer built around:

- forked-chain experiments,
- dependency failure injection,
- RPC degradation,
- oracle and liquidity disturbance scenarios,
- and scripted steady-state checks around `cycle()` safety.


## Why Classic Chaos Engineering Is A Poor Direct Fit

The core principles of chaos engineering start with defining a measurable steady state, introducing real-world failure variables, and trying to disprove the system's resilience hypothesis.

That model fits distributed services very well.

This repo is different:

- it is not a Kubernetes microservice application,
- it does not operate a fleet of long-lived app pods in this repository,
- it does not have an API gateway + worker mesh + service-to-service network to attack,
- and its main risk sits in smart-contract logic plus external DeFi dependencies.

Tools like Chaos Mesh and LitmusChaos are built for pod, network, DNS, HTTP, CPU, memory, and similar infrastructure faults. Those are useful when your production system is a cloud-native workload, but they are not the most direct next investment for this repo.


## What Fits Better Here

```text
Traditional chaos
├─ pod delete
├─ network latency
├─ DNS failure
└─ CPU / memory stress

DeFi-adapted chaos for this repo
├─ forked BNB Chain state
├─ oracle / spot divergence
├─ flash liquidity shortfall
├─ Aster close / burn / cooldown failure
├─ RPC timeout / stale data
├─ gas spike / call delay
└─ repeated cycle() safety checks
```

The right next layer is therefore **protocol chaos** or **dependency chaos**, not cluster chaos.


## Recommended Experiments

### P0 — Add Now

- RPC degradation: slow, timeout, or partial-read behavior in forked scripts.
- Oracle divergence: widen TWAP vs spot beyond the existing guard and confirm safe behavior.
- Flash liquidity shortfall: reduce available flash reserves and verify safe revert or non-flash fallback.
- Aster failure injection: make `closeTrade`, `burnAlp`, or cooldown paths fail and verify defensive behavior.
- Gas stress: increase gas assumptions and ensure incentive logic remains bounded.

### P1 — Add Next

- Repeated-cycle stress on a fork with changing reserves and changing oracle snapshots.
- Stateful experiment sequences around `ONLY_UNWIND` entry and recovery.
- Multi-day scripted fork scenarios with real block history windows.

### P2 — Only If Runtime Architecture Grows

- If this project later adds keepers, bots, APIs, schedulers, or Kubernetes workloads, then tools like Chaos Mesh or LitmusChaos become more relevant.


## Practical Recommendation

- **Yes**, introduce chaos engineering ideas.
- **No**, do not start with Chaos Mesh / Litmus as the main investment.
- **Start with Foundry/Anvil fork-based fault injection** and scripted dependency degradation.

Foundry's Anvil already supports forked execution from a remote RPC endpoint and specific block numbers, which makes it a much better first platform for this repository's chaos-like experiments than infrastructure-oriented chaos tools.


## Sources

- Principles of Chaos Engineering: `https://principlesofchaos.org/`
- Chaos Mesh docs: `https://chaos-mesh.org/docs/simulate-network-chaos-in-physical-nodes/`
- LitmusChaos experiments: `https://litmuschaos.github.io/litmus/`
- Foundry Anvil reference: `https://getfoundry.sh/reference/anvil/anvil`
