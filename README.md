# neuram_v2_threshold

A **conceptually new** NeuRAM model: a connectome engine in which every synapse
faithfully simulates **two kinds of threshold response**. This repository shares
**no code and no git history** with the legacy Half-MB / opponent campaign engine
(`neuram_companion`). It is an independent repository.

## The single goal

Implement and verify a connectome engine where each synapse honors two thresholds:

- **Threshold ① — signal-pass (firing) threshold.** At an individual
  neuron/synapse, input is *leaky-integrated*; the signal *passes* (fires) only
  when the accumulator crosses the firing threshold. Sub-threshold input is not
  propagated.
- **Threshold ② — connection-strength threshold.** A passed stimulus builds
  connection strength only when it *persists within a time window*. Strength forms
  gradually; if it falls below threshold or stimulation ceases, the connection
  decays and is eventually pruned.

Implementing and verifying the exact dynamics of these two thresholds is the whole
task. There is no other goal — no digital-twin, no regimes, no behavior model.

## Inherited *principles* (not code)

This model inherits, as *principles only*, the design discipline of the NeuRAM
line (see [docs/HERITAGE.md](docs/HERITAGE.md)):

- Nature-first: mathematics is introduced only after the natural fact is fixed.
- Six principles: event-driven, zero energy at idle, local computation, persistent
  storage, graded potentials, embodiment.
- Forbidden: backpropagation, global error, a clock, and any per-`dt` full sweep
  of all synapses. Time decay is computed **lazily** (on touch) only.

These are inherited as *ideas*. **No legacy code is reused, branched, merged,
cherry-picked, or imported.** Where a concept is needed it is rewritten from
scratch.

## Independence (separation principle)

- Brand-new `git init`. The history contains **zero** commit SHAs from
  `neuram_companion`.
- No branch/merge/cherry-pick/import from any legacy repository.
- No digital-twin reconciliation: regimes (R1–R7), netA/netB/probeA/avoidIndex,
  weekly simulations, the 5-week campaign, opponent plasticity and the unattended
  scheduler are **not** referenced, reproduced, or reconciled here.

## Layout

```
lib/
  params.dart       fixed model parameters (§6) + fCons; no tuning
  neuron.dart       minimal neuron identity + outgoing synapses
  synapse.dart      the core: threshold ① and ②, all decay computed lazily
  connectome.dart   neuron/synapse graph + file persistence + lazy pruning
  sim.dart          abstract stimulator harness (instrument only — no twin)
bin/
  threshold_test.dart   deterministic pre-registered pass/fail bench (exit != 0 on any fail)
docs/
  HERITAGE.md       what is inherited (concepts) vs. excluded (code, twin)
  RESULTS.md        measured A/B/C/OBS results
```

## Run

```bash
dart analyze
dart run bin/threshold_test.dart   # prints PASS/FAIL table; exit code != 0 on any FAIL
```

Pure Dart 3.8.1, offline, no external dependencies.
