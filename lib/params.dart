import 'dart:math' as math;

/// Fixed model parameters (§6). These are frozen before execution and are **not**
/// tuned. If a pre-registered criterion is not met with these values, the result
/// is reported honestly — the parameters are not retuned.
class Params {
  /// Strength upper bound.
  final double wMax;

  /// Threshold ① — firing threshold.
  final double thetaFire;

  /// Leaky-integration time constant of the activation accumulator `a`.
  final double tauA;

  /// Eligibility-trace time constant.
  final double tauE;

  /// Eligibility cutoff: contributions with eligibility below this are ignored.
  final double thetaE;

  /// Minimum number of recent consecutive firings required before strength can
  /// change (the temporal-persistence gate of the strength threshold).
  final int sMin;

  /// Base learning rate (sub-unity increment).
  final double etaBase;

  /// Consolidation time constant (slow; >> tauE).
  final double tauC;

  /// Structural-formation threshold for a silent synapse.
  final double thetaForm;

  /// Structural-formation critical window.
  final double tauForm;

  /// Effective-strength pruning threshold.
  final double thetaPrune;

  const Params({
    this.wMax = 1.0,
    this.thetaFire = 0.5,
    this.tauA = 0.3,
    this.tauE = 0.3,
    this.thetaE = 0.05,
    this.sMin = 2,
    this.etaBase = 0.15,
    this.tauC = 15.0,
    this.thetaForm = 0.6,
    this.tauForm = 0.5,
    this.thetaPrune = 0.1,
  });

  /// Consolidation accumulation function. Identity by design (documented choice;
  /// not one of the frozen §6 parameters): each reinforcement contributes its own
  /// eligibility-weighted teacher magnitude to the slow consolidation variable.
  double fCons(double z) => z;

  /// Temporal window (derived, not a free parameter) within which two firings
  /// count as "consecutive" for the sMin gate. Derived from tauE/thetaE so that a
  /// firing counts as recent exactly while its eligibility trace is still above
  /// the eligibility cutoff: exp(-dt/tauE) >= thetaE  <=>  dt <= tauE*ln(1/thetaE).
  double get firingWindow => tauE * math.log(1.0 / thetaE);
}
