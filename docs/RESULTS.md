# RESULTS — measured threshold dynamics

Bench: `dart run bin/threshold_test.dart` (deterministic, no randomness, no
external dependencies). Parameters are the frozen §6 values; nothing was tuned.
Exit code is non-zero if any scored criterion fails. This run: **11/11 scored
criteria PASS**, exit 0.

## Design summary

Each synapse carries the two thresholds and computes every time-decay **lazily**
on touch (no per-`dt` sweep; idle costs nothing).

- **Threshold ① (signal-pass / firing).** `input(t,x)` leaky-integrates
  `a = a·exp(-(t-tLast)/tauA) + x` and passes iff `a ≥ thetaFire`. Sub-threshold
  input updates state but neither propagates nor drives plasticity.
- **Threshold ② (connection strength).** `teach(t,m)` acts only on a synapse that
  passed threshold ① and whose firing **persisted** (eligibility `e =
  exp(-(t-tLast)/tauE) ≥ thetaE` **and** `firedCount ≥ sMin`). The increment is
  sub-unity and damped by consolidation: `etaEff = etaBase/(1+c)`,
  `w ← clamp(w + etaEff·e·m, 0, wMax)`, with slow `c` (tauC ≫ tauE).
- **Structural** formation: a silent synapse realizes when co-activation within
  `tauForm` drives `formAcc ≥ thetaForm`. Pruning (`maybePrune`) eliminates an
  active synapse once stimulation has ceased ≥`3·tauE` and effective strength has
  stayed below `thetaPrune`.
- **Propagation** is gated by the same strength threshold (`effective ≥
  thetaPrune`), the dual meaning of the connection-strength threshold.

Two derived (non-tuned) constants are documented in `lib/params.dart`:
`fCons(z)=z`, and `firingWindow = tauE·ln(1/thetaE) ≈ 0.898` (the window within
which two firings count as consecutive — derived so a firing counts as recent
exactly while its eligibility is above `thetaE`; it is not a free parameter).

## REG — independence & soundness

| ID | Result | Evidence |
|----|--------|----------|
| REG-1 | PASS | Separation documented (README/HERITAGE); git history has exactly **1 root commit** → no `neuram_companion` ancestry/SHA. |
| REG-2 | PASS | No external dependencies; SDK `^3.8.1`; `dart analyze` clean; build/test executed. |

## A — threshold ① (signal-pass)

| ID | Result | Measured |
|----|--------|----------|
| A1 (sub-threshold blocked) | PASS | input 0.3 spaced 1.0 (>3·tauA): fires=0, w=0, `a` saturates at **0.3111 < 0.5**, propagation 0. |
| A2 (accumulated pass) | PASS | single 0.3 is sub-threshold; spaced 0.1 (<tauA) `a` accumulates `[0.3000, 0.5150, …]` and **fires on the 2nd input**. |
| A3 (leak resets) | PASS | spaced 0.9 (≥3·tauA): pre-input residual `a ≈ 0.0157 ≈ 0` each time → **never fires**. |

Leaky-integration curves (A2 vs A3) show the temporal-summation/leak contrast
directly: identical pulse magnitude (0.3), opposite outcome decided purely by
inter-pulse interval.

## B — threshold ② (connection strength)

| ID | Result | Measured |
|----|--------|----------|
| B1 (gradual, non-one-step) | PASS | w after 1 presentation = **0.1270 < 0.30·asymptote (0.30)**; 95% of asymptote needs **264 presentations (≥4)**; largest single step **0.1270 < 0.60·asymptote**; asymptote = wMax = 1.0. |
| B2 (persistence gate) | PASS | sporadic firings (gap > firingWindow, firedCount<sMin) → **w = 0**; sustained presentations → **w = 0.3324 > 0**. |
| B3 (unstimulated decay + prune) | PASS | after 3·tauE silence `eff/w = 0.04979 = exp(-3)` (within ±10%); `eff = 0.0249 < thetaPrune` → **active = false**. |
| B4 (strength-gated propagation) | PASS | weak (w=0.08<thetaPrune) → **0 (blocked)**; strong (w=0.50) → **0.50 (passes)**; non-fired (w=0.50) → **0 (threshold ① not passed)**. |

### B1 formation curve (stepwise `w`)

```
presentation: 1       2       3       4       5       6       7       8
w:            0.1270  0.1957  0.2429  0.2789  0.3080  0.3324  0.3534  0.3719
```

The curve is strongly **decelerating** (concave): metaplasticity (`c` growing,
`etaEff = etaBase/(1+c)` shrinking) makes each step smaller. No single step
dominates, and substantial formation requires many reinforcements — the direct,
faithful answer to single-variable saturation (Fusi 2005). The asymptote equals
`wMax` and is approached over hundreds of presentations.

## C — metaplasticity

| ID | Result | Measured |
|----|--------|----------|
| C1 (high-c changes less) | PASS | identical teacher: `dw(c=0)=0.12697` vs `dw(c=16.40)=0.00730`; `etaEff` falls **0.1500 → 0.0086** (monotone decreasing). |

## OBS — observation only (not scored)

**OBS-1.** Population of 12 synapses. With **heterogeneous** (staggered) onsets the
population-average strength curve is markedly smoother (max single-step jump
**0.0358**) than a **uniform** population (max jump **0.0688**). A uniform population
behaves identically to a single synapse — averaging produces a graded/multi-step
curve **only when the population is heterogeneous**. This is the direct
confirmation that population averaging is meaningful only under heterogeneity.

## Persistence (design requirement)

`PERSIST` (reported, not a §7 score): after 5 presentations, serialize → restore.
`w`, `c`, `tLast`, `active` restored **exactly** (e.g. w=0.3080, c=4.2043),
demonstrating Stage-A file persistence (reboot restores synaptic state).

## Honesty note

No criterion was missed, so no shortfall hypotheses are required. All values above
are produced by the unmodified §6 parameters; the bench would `exit 1` on any
failure.
