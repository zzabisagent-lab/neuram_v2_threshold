import 'dart:convert';
import 'dart:io';

import 'neuron.dart';
import 'params.dart';
import 'synapse.dart';

/// The neuron/synapse graph plus persistence.
///
/// Persistence (six-principles: persistent storage) is provided by file
/// serialization at Stage A: `w`, `c`, `tLast`, `a`, `active` (and the firing
/// bookkeeping) are written out and restored verbatim, so a "reboot" reconstructs
/// the exact synaptic state. No equivalent of a global pass is used to rebuild it.
class Connectome {
  final Params params;
  final List<Neuron> neurons;
  final Map<int, Synapse> synapses;

  Connectome({Params? params})
    : params = params ?? const Params(),
      neurons = <Neuron>[],
      synapses = <int, Synapse>{};

  Neuron addNeuron(int id) {
    final n = Neuron(id);
    neurons.add(n);
    return n;
  }

  Synapse addSynapse(int id, {double w = 0.0, bool active = true}) {
    final s = Synapse(id, w: w, active: active);
    synapses[id] = s;
    return s;
  }

  // --- persistence --------------------------------------------------------

  Map<String, dynamic> _synapseJson(Synapse s) => {
    'id': s.id,
    'w': s.w,
    'a': s.a,
    'tLast': s.tLast,
    'c': s.c,
    'active': s.active,
    'tLastFire': s.tLastFire == double.negativeInfinity ? null : s.tLastFire,
    'firedCount': s.firedCount,
    'lastFired': s.lastFired,
  };

  void _applyJson(Synapse s, Map<String, dynamic> j) {
    s.w = (j['w'] as num).toDouble();
    s.a = (j['a'] as num).toDouble();
    s.tLast = (j['tLast'] as num).toDouble();
    s.c = (j['c'] as num).toDouble();
    s.active = j['active'] as bool;
    s.tLastFire = j['tLastFire'] == null
        ? double.negativeInfinity
        : (j['tLastFire'] as num).toDouble();
    s.firedCount = j['firedCount'] as int;
    s.lastFired = j['lastFired'] as bool;
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert({
    'version': 1,
    'synapses': synapses.values.map(_synapseJson).toList(),
  });

  void save(String path) => File(path).writeAsStringSync(toJsonString());

  /// Restore synaptic state from a previously saved file (a "reboot").
  void load(String path) => loadFromString(File(path).readAsStringSync());

  void loadFromString(String content) {
    final root = jsonDecode(content) as Map<String, dynamic>;
    for (final raw in (root['synapses'] as List)) {
      final j = raw as Map<String, dynamic>;
      final id = j['id'] as int;
      final s = synapses[id] ?? addSynapse(id);
      _applyJson(s, j);
    }
  }
}
