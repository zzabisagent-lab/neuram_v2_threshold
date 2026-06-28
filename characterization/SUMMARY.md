# Single-synapse characterization — SUMMARY

Engine `neuram_v2_threshold` @ frozen §6 params, public API only (`lib/` unmodified). Deterministic; every number below is reproducible from the CSVs in this directory.

Frozen §6: wMax=1.0, thetaFire=0.5, tauA=0.3, tauE=0.3, thetaE=0.05, sMin=2, etaBase=0.15, tauC=15.0, thetaForm=0.6, tauForm=0.5, thetaPrune=0.1, firingWindow=0.8987.

## S1 — summation / leak (firing boundary)
`s1_summation.csv`. Does a 5-pulse train fire?

- (a) x=0.3 fixed, sweep interval dt (dt:fire?):
  `0.05:fire 0.10:fire 0.15:fire 0.20:fire 0.25:fire 0.30:no 0.35:no 0.40:no 0.45:no 0.50:no 0.55:no 0.60:no 0.65:no 0.70:no 0.75:no 0.80:no 0.85:no 0.90:no 0.95:no 1.00:no`
- (b) interval=0.1 fixed, sweep magnitude x (x:fire?):
  `0.10:no 0.15:no 0.20:fire 0.25:fire 0.30:fire 0.35:fire 0.40:fire 0.45:fire 0.50:fire 0.55:fire 0.60:fire`
- Reading: rapid repeats (small dt) summate past thetaFire; widely spaced pulses leak away (3*tauA=0.90); a single sub-threshold magnitude only fires once it accumulates.

## S2 — formation curve
`s2_formation.csv` (ipi×m grid, 60 presentations each). For ipi=0.2, m=1.0: w after 1 = 0.1270, asymptote(@60) = 0.6751, reps to 95% of asymptote = 49. Gradual, decelerating (not one-step).

## S3 — forgetting (effective decay + prune)
`s3_forgetting.csv`. Formed to w≈0.33, then silence of gap×tauE; effective = w·exp(-gap). Prune requires silence ≥ 3·tauE AND effective < thetaPrune.

| gap (×tauE) | w | effective | pruned |
|---:|---:|---:|:--:|
| 0.5 | 0.332 | 0.2016 | false |
| 1.0 | 0.332 | 0.1223 | false |
| 2.0 | 0.332 | 0.0450 | false |
| 3.0 | 0.332 | 0.0165 | true |
| 4.0 | 0.332 | 0.0061 | true |
| 5.0 | 0.332 | 0.0022 | true |

## S4 — metaplasticity
`s4_metaplasticity.csv` (300 reps, m=1.0). etaEff = etaBase/(1+c) falls as c grows: first Δw = 0.12697, last Δw = 0.000786; c@300 = 160.79, etaEff@300 = 0.00093 (vs etaBase 0.15). Step size shrinks monotonically — single-variable saturation is offset by the slow second variable.

## S5 — relearning (savings)
`s5_relearning.csv`. w after form(20) = 0.5043; after 3·tauE silence (no prune call) w retained = 0.5043; first relearn presentation -> 0.5116; after relearn(20) -> 0.6103. Savings: w is retained across silence, so relearning continues from the retained value rather than from 0.

## S6 — coupling boundary
`s6_coupling.csv`. (a) sub-threshold input + teacher ×20 -> w = 0.0000 (stays 0: no firing -> no plasticity). (b) minimal firing input + teacher ×20 -> w = 0.5043 (> 0: plasticity onset). Firing is the gate for threshold-② coupling.

## Files
- s1_summation.csv, s2_formation.csv, s3_forgetting.csv, s4_metaplasticity.csv (12 common cols + dw,etaEff), s5_relearning.csv, s6_coupling.csv. All share the common header `protocol,case_id,t,input,teacher,a,w,c,fired,active,firedCount,effective`.
