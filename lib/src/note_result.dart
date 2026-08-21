import 'dart:math' as math;

/// Result of mapping a frequency to the nearest musical note.
class NoteResult {
  /// e.g. "E"
  final String name;

  /// e.g. "E2"
  final String nameWithOctave;

  /// How far off perfect tuning (-50..+50). 0 = in tune.
  final double cents;

  /// The detected frequency in Hz.
  final double frequency;

  const NoteResult(this.name, this.nameWithOctave, this.cents, this.frequency);
}

/// Converts frequencies to the nearest musical note (MIDI-based).
class NoteMapper {
  /// 12 semitones. Index 0 = C, matching the MIDI note numbering below.
  static const List<String> _names = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  /// If you'd rather display flats (Bb instead of A#), map sharp → flat here.
  static const Map<String, String> _flatAliases = {
    'A#': 'Bb', 'C#': 'Db', 'D#': 'Eb', 'F#': 'Gb', 'G#': 'Ab',
  };

  /// Converts a frequency to the nearest musical note.
  /// Music is logarithmic: every octave DOUBLES the frequency, and each octave
  /// has 12 equal semitones. We use the MIDI standard where A4 (440 Hz) = 69.
  /// Returns null for freq <= 0.
  static NoteResult? frequencyToNote(double freq, {bool useFlats = false}) {
    if (freq <= 0) return null;

    // Convert frequency to a fractional MIDI number.
    // log2(freq/440) tells us how many octaves above/below A4 we are;
    // ×12 converts octaves to semitones; +69 shifts to MIDI numbering.
    final midi = 69 + 12 * _log2(freq / 440.0);

    final nearest = midi.round(); // closest actual note
    // The leftover fraction, ×100, is the tuning error in cents
    // (100 cents = 1 semitone). This drives the tuner needle.
    final cents = (midi - nearest) * 100.0;

    // Map the MIDI number to a name + octave.
    final noteIdx = ((nearest % 12) + 12) % 12; // (+12)%12 guards negatives
    final octave = (nearest ~/ 12) - 1; // MIDI octave convention
    var name = _names[noteIdx];
    if (useFlats) name = _flatAliases[name] ?? name;

    return NoteResult(name, '$name$octave', cents, freq);
  }

  /// Dart's math has no log2, so make the base-change explicit.
  static double _log2(double x) => math.log(x) / math.log(2.0);
}