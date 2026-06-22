import 'dart:math' as math;

import 'params.dart';

/// A single synapse carrying the two threshold dynamics.
///
/// All time decay is computed **lazily** from [tLast] / [tLastFire] at the moment
/// the synapse is touched by an event. Nothing is recomputed on a tick, so an idle
/// synapse costs zero computation (six-principles: event-driven, zero-idle, local).
class Synapse {
  final int id;

  /// Connection strength, in [0, wMax].
  double w;

  /// Leaky activation accumulator (threshold ① input).
  double a;

  /// Timestamp of the last activity (last input event). Reference for lazy decay
  /// of [a], the eligibility trace and the effective strength.
  double tLast;

  /// Consolidation state (metaplasticity); slow time constant tauC.
  double c;

  /// Structural realization: false = silent/latent, true = realized connection.
  bool active;

  /// Timestamp of the last *firing* (threshold ① crossed). Used only for the
  /// consecutive-firing window of the sMin gate.
  double tLastFire;

  /// Number of recent consecutive firings (within [Params.firingWindow]).
  int firedCount;

  /// Whether the most recent input event fired. Plasticity acts only on a synapse
  /// whose last input passed threshold ①.
  bool lastFired;

  Synapse(this.id, {this.w = 0.0, this.active = true})
    : a = 0.0,
      tLast = 0.0,
      c = 0.0,
      tLastFire = double.negativeInfinity,
      firedCount = 0,
      lastFired = false;

  /// Threshold ① — signal-pass (firing).
  ///
  /// Leaky-integrates an input pulse of magnitude [x] arriving at time [t] and
  /// returns whether the accumulator crossed the firing threshold. A sub-threshold
  /// input updates state but does not "pass": it is neither propagated nor allowed
  /// to drive plasticity.
  bool input(double t, double x, Params p) {
    // Lazy leak of the activation accumulator since the last activity.
    a = a * math.exp(-(t - tLast) / p.tauA) + x;
    tLast = t;

    final fired = a >= p.thetaFire;
    lastFired = fired;

    if (fired) {
      // A firing counts as consecutive iff its eligibility from the previous
      // firing is still above the eligibility cutoff (firingWindow is derived
      // from tauE/thetaE, not an added free parameter).
      if (t - tLastFire <= p.firingWindow) {
        firedCount += 1;
      } else {
        firedCount = 1;
      }
      tLastFire = t;
    }
    return fired;
  }

  /// Effective strength at time [t]: the stored strength attenuated by the
  /// eligibility decay since the last activity (lazy). This is what downstream
  /// reads and what the pruning rule tests.
  double effective(double t, Params p) => w * math.exp(-(t - tLast) / p.tauE);
}
