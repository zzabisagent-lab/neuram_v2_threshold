// Single-synapse stimulus–response characterization probe.
//
//   dart run bin/characterize.dart   # writes characterization/*.csv + SUMMARY.md
//
// Uses ONLY the engine's public API (Stimulator.pulse/teach/observe/propagate/
// prune, Observation). The engine model (lib/) is not modified. Deterministic,
// no randomness, no external dependencies, frozen §6 parameters.
//
// Common CSV columns (all files start with these):
//   protocol,case_id,t,input,teacher,a,w,c,fired,active,firedCount,effective
// (S4 appends two derived-for-convenience columns: dw,etaEff.)

import 'dart:io';

import 'package:neuram_v2_threshold/connectome.dart';
import 'package:neuram_v2_threshold/params.dart';
import 'package:neuram_v2_threshold/sim.dart';
import 'package:neuram_v2_threshold/synapse.dart';

const outDir = 'characterization';
const commonHeader =
    'protocol,case_id,t,input,teacher,a,w,c,fired,active,firedCount,effective';

String fmt(double v) => v.toStringAsFixed(6);

/// A CSV accumulator with the common header (+ optional extra columns).
class Csv {
  final StringBuffer _b;
  Csv([String extra = ''])
    : _b = StringBuffer()..writeln('$commonHeader$extra');

  void row(
    String proto,
    String caseId,
    double t,
    String input,
    String teacher,
    Observation o, [
    String extra = '',
  ]) {
    _b.writeln(
      [
            proto,
            caseId,
            fmt(t),
            input,
            teacher,
            fmt(o.a),
            fmt(o.w),
            fmt(o.c),
            o.fired,
            o.active,
            o.firedCount,
            fmt(o.effective),
          ].join(',') +
          extra,
    );
  }

  void save(String name) =>
      File('$outDir/$name').writeAsStringSync(_b.toString());
}

/// A fresh single synapse (id 0) + its stimulator, with default (§6) params.
({Stimulator sim, Synapse s, Params p}) freshSyn({double w = 0.0}) {
  final cx = Connectome();
  final s = cx.addSynapse(0, w: w);
  final sim = Stimulator(cx);
  return (sim: sim, s: s, p: sim.params);
}

/// One reinforcement presentation: two supra-threshold pulses (so firedCount
/// reaches sMin) then a teacher. Returns the teach Δw. Times are absolute.
double presentation(
  Stimulator sim,
  Synapse s,
  double tStart,
  double m, {
  double x = 0.6,
  double dPulse = 0.05,
  double dTeach = 0.05,
}) {
  sim.pulse(s, tStart, x);
  sim.pulse(s, tStart + dPulse, x);
  return sim.teach(s, tStart + dPulse + dTeach, m);
}

// ===========================================================================

void main() {
  Directory(outDir).createSync(recursive: true);
  s1Summation();
  s2Formation();
  s3Forgetting();
  s4Metaplasticity();
  s5Relearning();
  s6Coupling();
  writeSummary();
  stdout.writeln('characterization complete -> $outDir/');
}

// --- S1: summation / leak ---------------------------------------------------
void s1Summation() {
  final csv = Csv();
  const proto = 'S1';

  // (a) magnitude fixed 0.3, sweep inter-pulse interval dt; 5 pulses each.
  for (var i = 1; i <= 20; i++) {
    final dt = i * 0.05; // 0.05 .. 1.00
    final f = freshSyn();
    final cid = 'a_dt=${dt.toStringAsFixed(2)}';
    for (var k = 0; k < 5; k++) {
      final t = k * dt;
      f.sim.pulse(f.s, t, 0.3);
      csv.row(proto, cid, t, '0.3', '', f.sim.observe(f.s, t));
    }
  }

  // (b) interval fixed 0.1, sweep pulse magnitude x; 5 pulses each.
  for (var i = 2; i <= 12; i++) {
    final x = i * 0.05; // 0.10 .. 0.60
    final f = freshSyn();
    final cid = 'b_x=${x.toStringAsFixed(2)}';
    for (var k = 0; k < 5; k++) {
      final t = k * 0.1;
      f.sim.pulse(f.s, t, x);
      csv.row(proto, cid, t, x.toStringAsFixed(2), '', f.sim.observe(f.s, t));
    }
  }

  csv.save('s1_summation.csv');
}

// --- S2: formation ----------------------------------------------------------
void s2Formation() {
  final csv = Csv();
  const proto = 'S2';
  const ipis = [0.1, 0.2, 0.3, 0.5];
  const ms = [0.5, 1.0];
  for (final ipi in ipis) {
    for (final m in ms) {
      final f = freshSyn();
      final cid = 'ipi=${ipi.toStringAsFixed(2)}_m=${m.toStringAsFixed(2)}';
      for (var k = 0; k < 60; k++) {
        final tStart = k * ipi;
        presentation(f.sim, f.s, tStart, m);
        final tTeach = tStart + 0.10;
        csv.row(
          proto,
          cid,
          tTeach,
          '',
          m.toStringAsFixed(2),
          f.sim.observe(f.s, tTeach),
        );
      }
    }
  }
  csv.save('s2_formation.csv');
}

// --- S3: forgetting ---------------------------------------------------------
void s3Forgetting() {
  final csv = Csv();
  const proto = 'S3';
  final tauE = const Params().tauE;
  const gapMults = [0.5, 1.0, 2.0, 3.0, 4.0, 5.0];

  for (final g in gapMults) {
    final f = freshSyn();
    // form toward w ~ 0.33
    var tLastPulse = 0.0;
    for (var k = 0; k < 20; k++) {
      final tStart = k * 0.2;
      presentation(f.sim, f.s, tStart, 1.0);
      tLastPulse = tStart + 0.05; // last pulse of the presentation
      if (f.s.w >= 0.33) break;
    }
    final cid = 'gap=${g.toStringAsFixed(1)}xTauE';
    final tTeach = tLastPulse + 0.05;
    csv.row(
      proto,
      '$cid|formed',
      tTeach,
      '',
      '1.0',
      f.sim.observe(f.s, tTeach),
    );

    // silence, then observe effective at tLastPulse + g*tauE
    final tGap = tLastPulse + g * tauE;
    csv.row(proto, '$cid|postgap', tGap, '', '', f.sim.observe(f.s, tGap));
    // attempt prune at that time, then re-observe (active reflects result)
    final pruned = f.sim.prune(f.s, tGap);
    csv.row(
      proto,
      '$cid|afterprune_${pruned ? 'PRUNED' : 'kept'}',
      tGap,
      '',
      '',
      f.sim.observe(f.s, tGap),
    );
  }
  csv.save('s3_forgetting.csv');
}

// --- S4: metaplasticity -----------------------------------------------------
void s4Metaplasticity() {
  final csv = Csv(',dw,etaEff'); // extra trailing columns (convenience)
  const proto = 'S4';
  final etaBase = const Params().etaBase;
  final f = freshSyn();
  const cid = 'meta';
  var prevW = f.s.w;
  for (var k = 0; k < 300; k++) {
    final cBefore = f.s.c;
    final etaEff = etaBase / (1 + cBefore);
    final tStart = k * 0.2;
    presentation(f.sim, f.s, tStart, 1.0);
    final tTeach = tStart + 0.10;
    final o = f.sim.observe(f.s, tTeach);
    final dw = o.w - prevW;
    prevW = o.w;
    csv.row(proto, cid, tTeach, '', '1.0', o, ',${fmt(dw)},${fmt(etaEff)}');
  }
  csv.save('s4_metaplasticity.csv');
}

// --- S5: relearning ---------------------------------------------------------
void s5Relearning() {
  final csv = Csv();
  const proto = 'S5';
  final tauE = const Params().tauE;
  final f = freshSyn();

  // phase 1: form (20 presentations)
  var tLastPulse = 0.0;
  for (var k = 0; k < 20; k++) {
    final tStart = k * 0.2;
    presentation(f.sim, f.s, tStart, 1.0);
    tLastPulse = tStart + 0.05;
    final tTeach = tStart + 0.10;
    csv.row(proto, 'form', tTeach, '', '1.0', f.sim.observe(f.s, tTeach));
  }

  // silence: 3*tauE (no prune call — pure quiet gap), observe at end
  final tSilenceEnd = tLastPulse + 3 * tauE;
  csv.row(
    proto,
    'silence',
    tSilenceEnd,
    '',
    '',
    f.sim.observe(f.s, tSilenceEnd),
  );

  // phase 2: re-stimulate (20 presentations), continuing time after silence
  final base = tSilenceEnd + 0.1;
  for (var k = 0; k < 20; k++) {
    final tStart = base + k * 0.2;
    presentation(f.sim, f.s, tStart, 1.0);
    final tTeach = tStart + 0.10;
    csv.row(proto, 'relearn', tTeach, '', '1.0', f.sim.observe(f.s, tTeach));
  }
  csv.save('s5_relearning.csv');
}

// --- S6: coupling boundary --------------------------------------------------
void s6Coupling() {
  final csv = Csv();
  const proto = 'S6';

  // (a) always sub-threshold input + teacher -> w must stay 0.
  {
    final f = freshSyn();
    const cid = 'a_subthreshold';
    for (var k = 0; k < 20; k++) {
      final t = k * 1.0; // interval 1.0 >> 3*tauA: a cannot accumulate
      f.sim.pulse(f.s, t, 0.3); // 0.3 < thetaFire 0.5
      final tTeach = t + 0.05;
      f.sim.teach(f.s, tTeach, 1.0); // teacher present but nothing fired
      csv.row(proto, cid, tTeach, '0.3', '1.0', f.sim.observe(f.s, tTeach));
    }
  }

  // (b) minimal firing input + teacher -> plasticity onset.
  {
    final f = freshSyn();
    const cid = 'b_suprathreshold';
    for (var k = 0; k < 20; k++) {
      final tStart = k * 0.2;
      presentation(f.sim, f.s, tStart, 1.0); // 2 supra pulses + teach
      final tTeach = tStart + 0.10;
      csv.row(proto, cid, tTeach, '0.6', '1.0', f.sim.observe(f.s, tTeach));
    }
  }
  csv.save('s6_coupling.csv');
}

// --- SUMMARY ----------------------------------------------------------------
void writeSummary() {
  final p = const Params();

  // Recompute the headline numbers from the same deterministic runs so SUMMARY
  // stays reproducible from the CSVs.

  // S1 firing-boundary cells.
  String s1aBoundary() {
    final rows = <String>[];
    for (var i = 1; i <= 20; i++) {
      final dt = i * 0.05;
      final f = freshSyn();
      var fired = false;
      for (var k = 0; k < 5; k++) {
        if (f.sim.pulse(f.s, k * dt, 0.3)) fired = true;
      }
      rows.add('${dt.toStringAsFixed(2)}:${fired ? 'fire' : 'no'}');
    }
    return rows.join(' ');
  }

  String s1bBoundary() {
    final rows = <String>[];
    for (var i = 2; i <= 12; i++) {
      final x = i * 0.05;
      final f = freshSyn();
      var fired = false;
      for (var k = 0; k < 5; k++) {
        if (f.sim.pulse(f.s, k * 0.1, x)) fired = true;
      }
      rows.add('${x.toStringAsFixed(2)}:${fired ? 'fire' : 'no'}');
    }
    return rows.join(' ');
  }

  // S2 asymptote + reps to 95% for ipi=0.2,m=1.0.
  ({double asym, int n95, double w1}) s2Curve() {
    final f = freshSyn();
    final ws = <double>[];
    for (var k = 0; k < 60; k++) {
      presentation(f.sim, f.s, k * 0.2, 1.0);
      ws.add(f.s.w);
    }
    final asym = ws.last;
    var n95 = -1;
    for (var i = 0; i < ws.length; i++) {
      if (ws[i] >= 0.95 * asym) {
        n95 = i + 1;
        break;
      }
    }
    return (asym: asym, n95: n95, w1: ws.first);
  }

  // S3 effective vs gap + prune.
  String s3Table() {
    final rows = <String>[];
    for (final g in [0.5, 1.0, 2.0, 3.0, 4.0, 5.0]) {
      final f = freshSyn();
      var tLast = 0.0;
      for (var k = 0; k < 20; k++) {
        presentation(f.sim, f.s, k * 0.2, 1.0);
        tLast = k * 0.2 + 0.05;
        if (f.s.w >= 0.33) break;
      }
      final w = f.s.w;
      final tGap = tLast + g * p.tauE;
      final eff = f.sim.observe(f.s, tGap).effective;
      final pruned = f.sim.prune(f.s, tGap);
      rows.add(
        '| ${g.toStringAsFixed(1)} | ${w.toStringAsFixed(3)} '
        '| ${eff.toStringAsFixed(4)} | $pruned |',
      );
    }
    return rows.join('\n');
  }

  // S4 etaEff/dw decay.
  ({double cEnd, double dwFirst, double dwLast, double etaEnd}) s4() {
    final f = freshSyn();
    var prev = 0.0;
    var dwFirst = 0.0, dwLast = 0.0;
    for (var k = 0; k < 300; k++) {
      presentation(f.sim, f.s, k * 0.2, 1.0);
      final dw = f.s.w - prev;
      prev = f.s.w;
      if (k == 0) dwFirst = dw;
      dwLast = dw;
    }
    return (
      cEnd: f.s.c,
      dwFirst: dwFirst,
      dwLast: dwLast,
      etaEnd: p.etaBase / (1 + f.s.c),
    );
  }

  // S5 savings.
  ({double wAfterForm, double wAfterSilence, double wRelearn1, double wFinal})
  s5() {
    final f = freshSyn();
    var tLast = 0.0;
    for (var k = 0; k < 20; k++) {
      presentation(f.sim, f.s, k * 0.2, 1.0);
      tLast = k * 0.2 + 0.05;
    }
    final wForm = f.s.w;
    final tSil = tLast + 3 * p.tauE;
    final wSil = f.sim.observe(f.s, tSil).w;
    final base = tSil + 0.1;
    presentation(f.sim, f.s, base, 1.0);
    final wRe1 = f.s.w;
    for (var k = 1; k < 20; k++) {
      presentation(f.sim, f.s, base + k * 0.2, 1.0);
    }
    return (
      wAfterForm: wForm,
      wAfterSilence: wSil,
      wRelearn1: wRe1,
      wFinal: f.s.w,
    );
  }

  // S6 boundary.
  ({double wSub, double wSupra}) s6() {
    final fa = freshSyn();
    for (var k = 0; k < 20; k++) {
      fa.sim.pulse(fa.s, k * 1.0, 0.3);
      fa.sim.teach(fa.s, k * 1.0 + 0.05, 1.0);
    }
    final fb = freshSyn();
    for (var k = 0; k < 20; k++) {
      presentation(fb.sim, fb.s, k * 0.2, 1.0);
    }
    return (wSub: fa.s.w, wSupra: fb.s.w);
  }

  final s2 = s2Curve();
  final s4r = s4();
  final s5r = s5();
  final s6r = s6();

  final b = StringBuffer()
    ..writeln('# Single-synapse characterization — SUMMARY')
    ..writeln()
    ..writeln(
      'Engine `neuram_v2_threshold` @ frozen §6 params, public API only '
      '(`lib/` unmodified). Deterministic; every number below is reproducible '
      'from the CSVs in this directory.',
    )
    ..writeln()
    ..writeln(
      'Frozen §6: wMax=${p.wMax}, thetaFire=${p.thetaFire}, '
      'tauA=${p.tauA}, tauE=${p.tauE}, thetaE=${p.thetaE}, sMin=${p.sMin}, '
      'etaBase=${p.etaBase}, tauC=${p.tauC}, thetaForm=${p.thetaForm}, '
      'tauForm=${p.tauForm}, thetaPrune=${p.thetaPrune}, '
      'firingWindow=${p.firingWindow.toStringAsFixed(4)}.',
    )
    ..writeln()
    ..writeln('## S1 — summation / leak (firing boundary)')
    ..writeln('`s1_summation.csv`. Does a 5-pulse train fire?')
    ..writeln()
    ..writeln('- (a) x=0.3 fixed, sweep interval dt (dt:fire?):')
    ..writeln('  `${s1aBoundary()}`')
    ..writeln('- (b) interval=0.1 fixed, sweep magnitude x (x:fire?):')
    ..writeln('  `${s1bBoundary()}`')
    ..writeln(
      '- Reading: rapid repeats (small dt) summate past thetaFire; widely '
      'spaced pulses leak away (3*tauA=${(3 * p.tauA).toStringAsFixed(2)}); a '
      'single sub-threshold magnitude only fires once it accumulates.',
    )
    ..writeln()
    ..writeln('## S2 — formation curve')
    ..writeln(
      '`s2_formation.csv` (ipi×m grid, 60 presentations each). For '
      'ipi=0.2, m=1.0: w after 1 = ${s2.w1.toStringAsFixed(4)}, '
      'asymptote(@60) = ${s2.asym.toStringAsFixed(4)}, reps to 95% of '
      'asymptote = ${s2.n95}. Gradual, decelerating (not one-step).',
    )
    ..writeln()
    ..writeln('## S3 — forgetting (effective decay + prune)')
    ..writeln(
      '`s3_forgetting.csv`. Formed to w≈0.33, then silence of '
      'gap×tauE; effective = w·exp(-gap). Prune requires silence ≥ 3·tauE '
      'AND effective < thetaPrune.',
    )
    ..writeln()
    ..writeln('| gap (×tauE) | w | effective | pruned |')
    ..writeln('|---:|---:|---:|:--:|')
    ..writeln(s3Table())
    ..writeln()
    ..writeln('## S4 — metaplasticity')
    ..writeln(
      '`s4_metaplasticity.csv` (300 reps, m=1.0). etaEff = etaBase/(1+c) '
      'falls as c grows: first Δw = ${s4r.dwFirst.toStringAsFixed(5)}, last Δw '
      '= ${s4r.dwLast.toStringAsFixed(6)}; c@300 = ${s4r.cEnd.toStringAsFixed(2)}, '
      'etaEff@300 = ${s4r.etaEnd.toStringAsFixed(5)} (vs etaBase ${p.etaBase}). '
      'Step size shrinks monotonically — single-variable saturation is offset by '
      'the slow second variable.',
    )
    ..writeln()
    ..writeln('## S5 — relearning (savings)')
    ..writeln(
      '`s5_relearning.csv`. w after form(20) = '
      '${s5r.wAfterForm.toStringAsFixed(4)}; after 3·tauE silence (no prune '
      'call) w retained = ${s5r.wAfterSilence.toStringAsFixed(4)}; first '
      'relearn presentation -> ${s5r.wRelearn1.toStringAsFixed(4)}; after '
      'relearn(20) -> ${s5r.wFinal.toStringAsFixed(4)}. Savings: w is retained '
      'across silence, so relearning continues from the retained value rather '
      'than from 0.',
    )
    ..writeln()
    ..writeln('## S6 — coupling boundary')
    ..writeln(
      '`s6_coupling.csv`. (a) sub-threshold input + teacher ×20 -> '
      'w = ${s6r.wSub.toStringAsFixed(4)} (stays 0: no firing -> no plasticity). '
      '(b) minimal firing input + teacher ×20 -> w = '
      '${s6r.wSupra.toStringAsFixed(4)} (> 0: plasticity onset). Firing is the '
      'gate for threshold-② coupling.',
    )
    ..writeln()
    ..writeln('## Files')
    ..writeln(
      '- s1_summation.csv, s2_formation.csv, s3_forgetting.csv, '
      's4_metaplasticity.csv (12 common cols + dw,etaEff), s5_relearning.csv, '
      's6_coupling.csv. All share the common header '
      '`$commonHeader`.',
    );
  File('$outDir/SUMMARY.md').writeAsStringSync(b.toString());
}
