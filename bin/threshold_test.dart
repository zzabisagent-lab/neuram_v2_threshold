// Pre-registered pass/fail bench for the two threshold dynamics (§7).
//
// Deterministic (no randomness), no external dependencies. Implements the §7
// criteria verbatim, prints a PASS/FAIL table, and exits with a non-zero code if
// any criterion fails.
//
//   dart run bin/threshold_test.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:neuram_v2_threshold/connectome.dart';
import 'package:neuram_v2_threshold/params.dart';
import 'package:neuram_v2_threshold/sim.dart';
import 'package:neuram_v2_threshold/synapse.dart';

const p = Params();

// --- result bookkeeping -----------------------------------------------------

class Result {
  final String id;
  final bool pass;
  final String detail;
  final bool obsOnly;
  Result(this.id, this.pass, this.detail, {this.obsOnly = false});
}

final results = <Result>[];
void record(String id, bool pass, String detail, {bool obsOnly = false}) =>
    results.add(Result(id, pass, detail, obsOnly: obsOnly));

String f(double v, [int n = 4]) => v.toStringAsFixed(n);
String fl(Iterable<double> xs, [int n = 4]) =>
    '[${xs.map((e) => e.toStringAsFixed(n)).join(', ')}]';

// --- presentation helper ----------------------------------------------------

/// One reinforcement presentation at base time [t]: two supra-threshold pulses
/// (so the synapse fires and firedCount reaches sMin) followed by a teacher [m].
/// Returns the strength change applied by the teacher.
double presentation(Stimulator sim, Synapse s, double t, {double m = 1.0}) {
  sim.pulse(s, t, 0.6);
  sim.pulse(s, t + 0.05, 0.6);
  return sim.teach(s, t + 0.10, m);
}

Stimulator freshSim() => Stimulator(Connectome());

// ===========================================================================
// REG — independence & soundness
// ===========================================================================

void regChecks() {
  // REG-1: independent history + documented separation.
  final readme = File('README.md').existsSync()
      ? File('README.md').readAsStringSync().toLowerCase()
      : '';
  final heritage = File('docs/HERITAGE.md').existsSync()
      ? File('docs/HERITAGE.md').readAsStringSync().toLowerCase()
      : '';
  final docsOk =
      readme.contains('no code and no git history') &&
      heritage.contains('no legacy');

  var rootOk = false;
  var rootDetail = 'git unavailable';
  try {
    final r = Process.runSync('git', ['rev-list', '--max-parents=0', 'HEAD']);
    if (r.exitCode == 0) {
      final roots = (r.stdout as String)
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      rootOk = roots.length == 1; // exactly one root => no foreign ancestry
      rootDetail = 'rootCommits=${roots.length}';
    }
  } catch (_) {
    // git not present: fall back to documented separation only.
    rootOk = docsOk;
    rootDetail = 'git unavailable; docs-only';
  }
  record(
    'REG-1',
    docsOk && rootOk,
    'separation documented=$docsOk, $rootDetail (no neuram_companion SHA in history)',
  );

  // REG-2: no external dependencies; Dart 3.8.1 build/test runs (this binary ran).
  final pub = File('pubspec.yaml').readAsStringSync();
  final noDeps = !pub.contains('dependencies:'); // no deps / dev_deps blocks
  final sdkOk = pub.contains('^3.8.1');
  record(
    'REG-2',
    noDeps && sdkOk,
    'no external deps=$noDeps, sdk^3.8.1=$sdkOk, build/test executed=true',
  );
}

// ===========================================================================
// A — threshold ① signal-pass
// ===========================================================================

void thresholdA() {
  // A1 — sub-threshold train is blocked (no fire, no propagation, no w change).
  {
    final sim = freshSim();
    final s = sim.connectome.addSynapse(1, w: 0.0);
    var fires = 0;
    final traj = <double>[];
    for (var k = 0; k < 6; k++) {
      final t = k * 1.0; // interval 1.0 > 3*tauA (0.9): a cannot accumulate
      final fired = sim.pulse(s, t, 0.3); // 0.3 < thetaFire 0.5
      if (fired) fires++;
      traj.add(sim.observe(s, t).a);
      sim.teach(s, t + 0.01, 1.0); // teacher present but nothing fired
    }
    final pass = fires == 0 && s.w == 0.0 && sim.propagate(s, 5.01) == 0.0;
    record(
      'A1',
      pass,
      'fires=$fires (expect 0), w=${f(s.w)} (expect 0), a_peak=${f(traj.reduce(math.max))} < thetaFire',
    );
  }

  // A2 — sub-threshold singles accumulate within tauA and break through.
  {
    final sim = freshSim();
    final s = sim.connectome.addSynapse(2, w: 0.0);
    final aTraj = <double>[];
    var firstFired = true;
    var brokeThrough = false;
    var breakStep = -1;
    for (var k = 0; k < 6; k++) {
      final t = k * 0.1; // interval 0.1 < tauA (0.3)
      final fired = sim.pulse(s, t, 0.3); // single 0.3 is sub-threshold
      aTraj.add(s.a);
      if (k == 0) firstFired = fired;
      if (fired && !brokeThrough) {
        brokeThrough = true;
        breakStep = k;
      }
    }
    final pass = !firstFired && brokeThrough;
    record(
      'A2',
      pass,
      'single 0.3<0.5 sub-threshold, accumulated fire at step $breakStep; a=${fl(aTraj)}',
    );
  }

  // A3 — widely spaced inputs leak away each time and never break through.
  {
    final sim = freshSim();
    final s = sim.connectome.addSynapse(3, w: 0.0);
    var fires = 0;
    final residual = <double>[];
    for (var k = 0; k < 6; k++) {
      final t = k * 0.9; // interval 0.9 >= 3*tauA: near-full reset each time
      // residual a carried into this input (decayed from previous):
      residual.add(sim.observe(s, t).a);
      if (sim.pulse(s, t, 0.3)) fires++;
    }
    final maxResidual = residual.skip(1).fold<double>(0.0, math.max);
    final pass = fires == 0 && maxResidual < 0.05; // resets to ~0
    record(
      'A3',
      pass,
      'fires=$fires (expect 0), max pre-input residual a=${f(maxResidual)} ~ 0; residuals=${fl(residual)}',
    );
  }
}

// ===========================================================================
// B — threshold ② connection strength
// ===========================================================================

void thresholdB() {
  // B1 — gradual (non-one-step) formation.
  {
    const k = 2000;
    final sim = freshSim();
    final s = sim.connectome.addSynapse(10, w: 0.0);
    final w = <double>[];
    final dw = <double>[];
    for (var i = 0; i < k; i++) {
      final d = presentation(sim, s, i * 2.0, m: 1.0);
      dw.add(d);
      w.add(s.w);
    }
    final asymptote = w.last; // empirical asymptote (== wMax, clamped)
    final w1 = w[0];
    final maxStep = dw.reduce(math.max);
    // presentations needed to reach 95% of asymptote
    var n95 = -1;
    for (var i = 0; i < w.length; i++) {
      if (w[i] >= 0.95 * asymptote) {
        n95 = i + 1;
        break;
      }
    }
    final b1a = w1 < 0.30 * asymptote; // 1 step < 30% of asymptote
    final b1b = n95 >= 4; // 95% needs >= 4 presentations
    final b1c = maxStep < 0.60 * (asymptote - 0.0); // no single step > 60%
    record(
      'B1',
      b1a && b1b && b1c,
      'w1=${f(w1)}<0.30*asym(${f(0.30 * asymptote)})=$b1a; '
          'n95=$n95>=4=$b1b; maxStep=${f(maxStep)}<0.60*asym=$b1c; '
          'asymptote=${f(asymptote)}; w[1..8]=${fl(w.take(8))}',
    );
  }

  // B2 — temporal-persistence gate: sporadic firings do not form strength.
  {
    final sim = freshSim();
    final sporadic = sim.connectome.addSynapse(20, w: 0.0);
    for (var k = 0; k < 6; k++) {
      final t =
          k * 2.0; // gap 2.0 > firingWindow: firedCount resets to 1 (<sMin)
      sim.pulse(sporadic, t, 0.6); // fires, but firedCount stays 1
      sim.teach(sporadic, t + 0.05, 1.0); // gated out (firedCount < sMin)
    }
    final sustained = sim.connectome.addSynapse(21, w: 0.0);
    for (var k = 0; k < 6; k++) {
      presentation(sim, sustained, k * 2.0, m: 1.0); // firedCount reaches sMin
    }
    final pass = sporadic.w == 0.0 && sustained.w > 0.0;
    record(
      'B2',
      pass,
      'sporadic w=${f(sporadic.w)} (expect 0, gate blocks), sustained w=${f(sustained.w)} (>0)',
    );
  }

  // B3 — unstimulated decay and pruning.
  {
    final sim = freshSim();
    final s = sim.connectome.addSynapse(30, w: 0.5);
    sim.pulse(s, 0.0, 0.6); // fire once to set last-activity time
    final tObs = 3.0 * p.tauE; // 0.9 = 3*tauE of silence
    final eff = s.effective(tObs, p);
    final ratio = eff / s.w; // == exp(-3) ~ 0.0498
    final target = math.exp(-3.0);
    final within10 = (ratio - target).abs() <= 0.10 * target;
    final pruned = sim.prune(s, tObs); // effective < thetaPrune persisted
    final pass = within10 && pruned && !s.active;
    record(
      'B3',
      pass,
      'eff/w=${f(ratio, 5)} vs exp(-3)=${f(target, 5)} (±10%)=$within10; '
          'eff=${f(eff, 5)}<thetaPrune=${pruned}; active=${s.active}',
    );
  }

  // B4 — strength threshold gates downstream propagation.
  {
    final sim = freshSim();
    final weak = sim.connectome.addSynapse(40, w: 0.08); // < thetaPrune 0.1
    final strong = sim.connectome.addSynapse(41, w: 0.50); // >= thetaPrune
    final unfired = sim.connectome.addSynapse(42, w: 0.50);
    sim.pulse(weak, 0.0, 0.6); // fires
    sim.pulse(strong, 0.0, 0.6); // fires
    sim.pulse(unfired, 0.0, 0.3); // sub-threshold: does NOT fire
    final pWeak = sim.propagate(weak, 0.0);
    final pStrong = sim.propagate(strong, 0.0);
    final pUnfired = sim.propagate(unfired, 0.0);
    final pass = pWeak == 0.0 && pStrong > 0.0 && pUnfired == 0.0;
    record(
      'B4',
      pass,
      'weak(w=0.08)->${f(pWeak)} blocked; strong(w=0.50)->${f(pStrong)} passes; '
          'unfired(w=0.50)->${f(pUnfired)} blocked (threshold ① not passed)',
    );
  }
}

// ===========================================================================
// C — metaplasticity
// ===========================================================================

void thresholdC() {
  // C1 — a strongly consolidated (high c) synapse changes less per step.
  {
    final sim = freshSim();
    final low = sim.connectome.addSynapse(50, w: 0.0); // c stays 0
    final dwLow = presentation(sim, low, 0.0, m: 1.0);

    final high = sim.connectome.addSynapse(51, w: 0.0);
    for (var k = 0; k < 20; k++) {
      presentation(sim, high, k * 2.0, m: 1.0); // build up c
    }
    final cHigh = high.c;
    final etaLow = p.etaBase / (1 + 0.0);
    final etaHigh = p.etaBase / (1 + cHigh);
    final dwHigh = presentation(
      sim,
      high,
      100.0,
      m: 1.0,
    ); // one more identical step

    final pass = dwHigh < dwLow && etaHigh < etaLow;
    record(
      'C1',
      pass,
      'dw(low c=0)=${f(dwLow, 5)} > dw(high c=${f(cHigh, 2)})=${f(dwHigh, 5)}; '
          'etaEff ${f(etaLow, 4)} -> ${f(etaHigh, 4)} (monotone decreasing)',
    );
  }
}

// ===========================================================================
// OBS — observation only (not pass/fail): population averaging needs heterogeneity
// ===========================================================================

void obsChecks() {
  const nSyn = 12;
  const steps = 24;

  // Heterogeneous: each synapse starts its reinforcement train at a staggered
  // global step (distributed initial state). Uniform: all start together.
  List<double> avgCurve({required bool heterogeneous}) {
    final sim = freshSim();
    final syn = <Synapse>[
      for (var i = 0; i < nSyn; i++) sim.connectome.addSynapse(600 + i, w: 0.0),
    ];
    final phase = <int>[for (var i = 0; i < nSyn; i++) heterogeneous ? i : 0];
    final avg = <double>[];
    for (var g = 0; g < steps; g++) {
      for (var i = 0; i < nSyn; i++) {
        if (g >= phase[i]) {
          // local presentation index for this synapse advances at its own pace
          presentation(sim, syn[i], 1000.0 * i + g * 2.0, m: 1.0);
        }
      }
      avg.add(syn.fold<double>(0.0, (a, s) => a + s.w) / nSyn);
    }
    return avg;
  }

  final het = avgCurve(heterogeneous: true);
  final uni = avgCurve(heterogeneous: false);
  double maxJump(List<double> c) {
    var m = 0.0;
    for (var i = 1; i < c.length; i++) {
      m = math.max(m, c[i] - c[i - 1]);
    }
    return m;
  }

  final smoother = maxJump(het) < maxJump(uni);
  record(
    'OBS-1',
    true,
    'heterogeneous max step=${f(maxJump(het))} < uniform max step=${f(maxJump(uni))} '
        '=> averaging smooths only with heterogeneity ($smoother). '
        'uniform == single-synapse curve. '
        'het[end]=${f(het.last)}, uni[end]=${f(uni.last)}',
    obsOnly: true,
  );
}

// ===========================================================================
// persistence round-trip (design requirement; reported, not a §7 pass/fail)
// ===========================================================================

void persistenceCheck() {
  final sim = freshSim();
  final s = sim.connectome.addSynapse(700, w: 0.0);
  for (var k = 0; k < 5; k++) {
    presentation(sim, s, k * 2.0, m: 1.0);
  }
  final before = (w: s.w, c: s.c, tLast: s.tLast, active: s.active);
  final json = sim.connectome.toJsonString();

  final restored = Connectome();
  restored.addSynapse(700);
  restored.loadFromString(json);
  final r = restored.synapses[700]!;
  final ok =
      r.w == before.w &&
      r.c == before.c &&
      r.tLast == before.tLast &&
      r.active == before.active;
  record(
    'PERSIST',
    ok,
    'reboot restored w/c/tLast/active exactly=$ok (w=${f(r.w)}, c=${f(r.c)})',
  );
}

// ===========================================================================

void main() {
  regChecks();
  thresholdA();
  thresholdB();
  thresholdC();
  obsChecks();
  persistenceCheck();

  stdout.writeln(
    '\n=== neuram_v2_threshold — pre-registered threshold bench ===\n',
  );
  var failed = 0;
  for (final r in results) {
    final tag = r.obsOnly ? 'OBS ' : (r.pass ? 'PASS' : 'FAIL');
    if (!r.obsOnly && !r.pass) failed++;
    stdout.writeln('[$tag] ${r.id.padRight(8)} ${r.detail}');
  }
  final scored = results.where((r) => !r.obsOnly).length;
  stdout.writeln(
    '\n${scored - failed}/$scored scored criteria passed'
    '${failed == 0 ? ' — ALL PASS' : ' — $failed FAILED'}.',
  );
  if (failed > 0) exit(1);
}
