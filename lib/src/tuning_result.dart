/// The public result of tuner detection. This is the type library consumers
/// receive — the internal engine and its own result type stay hidden.
sealed class TuningResult {
  const TuningResult();
}

/// A single detected note.
class NoteTuningResult extends TuningResult {
  /// Note name, e.g. "E" or "A#".
  final String name;

  /// Deviation from perfect pitch (-50..+50); 0 = in tune.
  final double cents;

  /// Detected frequency in Hz.
  final double freq;

  const NoteTuningResult({
    required this.name,
    required this.cents,
    required this.freq,
  });
}

/// A detected chord, e.g. "Am" or "Cmaj7".
class ChordTuningResult extends TuningResult {
  /// The chord name.
  final String name;

  const ChordTuningResult({required this.name});
}

/// No sound / below the detection threshold.
class SilenceTuningResult extends TuningResult {
  const SilenceTuningResult();
}
