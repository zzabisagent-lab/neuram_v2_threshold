# HERITAGE — what is inherited (concept) vs. excluded (code & twin)

This document records, in prose only, what `neuram_v2_threshold` inherits from the
NeuRAM line. **It inherits ideas, not code.** No legacy source file is quoted,
copied, branched, merged, cherry-picked, or imported. Where a mechanism is needed
it is *rewritten* from first principles.

## Inherited concepts

### The six principles
1. **Event-driven** — state changes only on stimulus/teacher events, never on a tick.
2. **Zero energy at idle** — no computation happens while nothing arrives.
3. **Local computation** — each synapse updates from its own state and the local
   event; there is no global pass.
4. **Persistent storage** — `w`, `c`, `tLast`, `a`, `active` survive a reboot
   (Stage A: file serialization).
5. **Graded potentials** — activation and strength are continuous, not binary.
6. **Embodiment** — dynamics are expressed as physical accumulation/decay, not as
   an abstract optimizer.

### Nature-first discipline
Mathematics is introduced only after the natural fact it models is fixed. The two
thresholds here are chosen because they are the natural facts: a membrane that
leaky-integrates to a firing threshold, and a synapse whose structural strength
only consolidates under sustained, repeated co-activation.

### The problem statement (Fusi 2005)
A single-variable synapse necessarily **saturates**: with one scalar weight and a
bounded range, repeated potentiation runs into the ceiling and forgets the past.
This is the motivation for a *second*, slow variable. In this model that second
variable is the consolidation state `c`, which implements **metaplasticity**:
the more a connection has been reinforced, the smaller each further step
(`etaEff = etaBase / (1 + c)`). This is why formation is *gradual and decelerating*
rather than one-shot — the direct, faithful answer to single-variable saturation.

### Why two thresholds (the natural basis of the design)
- **Threshold ① (signal-pass / firing).** Real neurons do not propagate every
  input; sub-threshold drive dies out. Leaky integration with a firing threshold
  reproduces both temporal summation (rapid repeats add up and pass) and leak
  (widely spaced inputs never accumulate).
- **Threshold ② (connection strength).** Real synaptic strengthening requires
  *sustained, repeated* activity, not a single coincidence. A strength that forms
  only when firing persists within a window — and that decays and is pruned when
  stimulation stops — reproduces formation, maintenance, and elimination.

## Explicitly excluded (not inherited)

- **No legacy code.** No file from `neuram_companion` (or any prior engine) is
  reused. The git history shares zero commit SHAs with it.
- **No digital-twin reconciliation.** Regimes R1–R7, `netA`/`netB`/`probeA`/
  `avoidIndex`, weekly simulations, the 5-week campaign, opponent plasticity, and
  the unattended scheduler are not referenced, reproduced, or reconciled. A twin
  for this new model, if any, is built separately *after* this engine is complete.
- **No backprop / global error / clock / per-`dt` full sweep.** All time decay is
  lazy (computed on touch from `tLast`); idle costs zero computation.
- **No binary-compatibility flag.** Graded-threshold is the only model here.
