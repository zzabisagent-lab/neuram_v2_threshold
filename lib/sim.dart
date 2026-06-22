import 'dart:math' as math;

import 'connectome.dart';
import 'params.dart';
import 'synapse.dart';

/// An observation snapshot of a synapse at a given time. Decayed quantities
/// (`a` and `effective`) are reported lazily at the observation time without
/// mutating state.
class Observation {
  final double t;
  final double a;
  final double w;
  final double c;
  final bool fired;
  final bool active;
  final int firedCount;
  final double effective;

  const Observation({
    required this.t,
    required this.a,
    required this.w,
    required this.c,
    required this.fired,
    required this.active,
    required this.firedCount,
    required this.effective,
  });

  @override
  String toString() =>
      't=${t.toStringAsFixed(3)} a=${a.toStringAsFixed(4)} '
      'w=${w.toStringAsFixed(4)} c=${c.toStringAsFixed(4)} '
      'fired=$fired active=$active n=$firedCount '
      'eff=${effective.toStringAsFixed(4)}';
}

/// Abstract stimulator — a pure *instrument* for the mechanism. It carries no
/// notion of a twin, behavior, or regime: it only delivers input pulses and
/// teacher signals at chosen times and reads back synapse state.
class Stimulator {
  final Connectome connectome;
  Params get params => connectome.params;

  Stimulator(this.connectome);

  /// Deliver an input pulse of magnitude [x] to [s] at time [t] (threshold ①).
  /// Returns whether the synapse fired (the signal "passed").
  bool pulse(Synapse s, double t, double x) => s.input(t, x, params);

  /// Read the synapse state at time [t] without mutating it. `a` and `effective`
  /// are the lazily-decayed values as of [t].
  Observation observe(Synapse s, double t) => Observation(
    t: t,
    a: _decayedA(s, t),
    w: s.w,
    c: s.c,
    fired: s.lastFired,
    active: s.active,
    firedCount: s.firedCount,
    effective: s.effective(t, params),
  );

  /// Lazy, read-only value of `a` as of time [t] (the leak since its last update).
  double _decayedA(Synapse s, double t) {
    final dt = t - s.tLast;
    if (dt <= 0) return s.a;
    return s.a * math.exp(-dt / params.tauA);
  }
}
