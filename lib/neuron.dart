import 'synapse.dart';

/// A minimal neuron: an identity plus the set of synapses leaving it.
///
/// The two threshold dynamics live on the [Synapse] (threshold ① is evaluated per
/// synapse on its own leaky-integrated input). The neuron is kept deliberately thin
/// so the model stays synapse-centric, matching the single goal of the project.
class Neuron {
  final int id;
  final List<Synapse> outgoing;

  Neuron(this.id, {List<Synapse>? outgoing})
    : outgoing = outgoing ?? <Synapse>[];

  Synapse connect(Synapse s) {
    outgoing.add(s);
    return s;
  }
}
