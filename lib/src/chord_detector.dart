import 'dart:collection';
import 'dart:math' as math;

import 'fft.dart';
import 'models/instrument_profile.dart';

/// One recognizable chord: a display name plus its pitch classes (0–11).
class _Template {
  final String name;
  final List<int> pitches;

  const _Template(this.name, this.pitches);
}

/// A scored chord match.
class ChordResult {
  final String name;
  final double score;

  const ChordResult(this.name, this.score);
}

class ChordDetector {
  final int sampleRate;

  /// Injected: supplies all frequency bounds.
  final InstrumentProfile profile;

  ChordDetector(this.sampleRate, this.profile) {
    _templates = _buildTemplates();
  }

  late final List<_Template> _templates;

  // Hysteresis state (prevents flicker between close chords like Am/F).
  String? _currentChord;
  double _currentScore = 0.0;

  // Temporal-averaging state: rolling buffer of recent chroma vectors.
  final Queue<List<double>> _chromaHistory = Queue<List<double>>();
  static const int _chromaWindow = 3;

  /// Builds every recognizable chord by transposing each interval pattern to
  /// all 12 roots. Chord templates are pitch-class based, so they're already
  /// instrument-independent (a C major is C-E-G on any instrument). The ONLY
  /// per-instrument bit is the sharp/flat display preference.
  List<_Template> _buildTemplates() {
    final roots = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    final flat = {'C#': 'Db', 'D#': 'Eb', 'F#': 'Gb', 'G#': 'Ab', 'A#': 'Bb'};
    final list = <_Template>[];
    final qualities = <MapEntry<String, List<int>>>[
      const MapEntry('', [0, 4, 7]), // major triad
      const MapEntry('m', [0, 3, 7]), // minor triad
      const MapEntry('7', [0, 4, 7, 10]), // dominant 7th
      const MapEntry('m7', [0, 3, 7, 10]), // minor 7th
      const MapEntry('maj7', [0, 4, 7, 11]),
      const MapEntry('sus2', [0, 2, 7]),
      const MapEntry('sus4', [0, 5, 7]),
      const MapEntry('dim', [0, 3, 6]),
      const MapEntry('aug', [0, 4, 8]),
    ];
    for (var r = 0; r < roots.length; r++) {
      for (final q in qualities) {
        // Use the profile's sharp/flat preference for the display name.
        final rootName = profile.useFlats
            ? (flat[roots[r]] ?? roots[r])
            : roots[r];
        final display = rootName + q.key;
        final pitches = q.value.map((it) => (it + r) % 12).toList();
        list.add(_Template(display, pitches));
      }
    }
    return list;
  }

  /// Builds the 12-bin chroma vector from a magnitude spectrum, using the
  /// profile's frequency window and harmonic pivot instead of hardcoded numbers.
  List<double> _chromaFrom(List<double> mags, int n) {
    final chroma = List<double>.filled(12, 0.0);
    for (var bin = 1; bin < mags.length - 1; bin++) {
      // Only consider local maxima (actual spectral peaks).
      if (mags[bin] < mags[bin - 1] || mags[bin] < mags[bin + 1]) continue;

      // Refine the peak's true frequency between bins.
      final offset = FFT.interpolatePeak(mags, bin);
      final freq = (bin + offset) * sampleRate / n;
      // Profile-driven window instead of hardcoded 70 / 5000.
      if (freq < profile.minFreq || freq > profile.maxFreq) continue;

      // Harmonic weighting centred on the instrument's pivot, not a fixed 200.
      final weight = math.sqrt(
        profile.harmonicPivot / math.max(freq, profile.harmonicPivot),
      );

      final midi = 69 + 12 * (math.log(freq / 440.0) / math.log(2.0));
      final pc = ((midi.round() % 12) + 12) % 12;
      chroma[pc] += mags[bin] * weight;
    }
    // Normalize so the loudest pitch class = 1.0 (volume-independent scoring).
    final maxVal = chroma.isEmpty ? 1.0 : chroma.reduce(math.max);
    if (maxVal > 0) {
      for (var i = 0; i < chroma.length; i++) {
        chroma[i] /= maxVal;
      }
    }
    return chroma;
  }

  /// Averages the current chroma with recent frames to suppress the strum
  /// attack.
  List<double> _smoothedChroma(List<double> current) {
    _chromaHistory.addLast(current);
    if (_chromaHistory.length > _chromaWindow) _chromaHistory.removeFirst();
    final avg = List<double>.filled(12, 0.0);
    for (final frame in _chromaHistory) {
      for (var i = 0; i < 12; i++) {
        avg[i] += frame[i];
      }
    }
    for (var i = 0; i < 12; i++) {
      avg[i] /= _chromaHistory.length;
    }
    return avg;
  }

  /// Finds the pitch class of the lowest strong frequency — the bass note —
  /// used to disambiguate chords that share most notes (Am vs F). Scans only
  /// the profile's bass region (minFreq → bassCeiling).
  int _detectBassPitchClass(List<double> mags, int n) {
    final maxMag = mags.isEmpty ? 0.0 : mags.reduce(math.max);
    if (maxMag == 0.0) return -1;
    for (var bin = 1; bin < mags.length; bin++) {
      final freq = bin * sampleRate / n;
      if (freq < profile.minFreq) continue; // profile floor
      if (freq > profile.bassCeiling) break; // profile bass ceiling
      if (mags[bin] > maxMag * 0.3) {
        // first prominent low bin
        final midi = 69 + 12 * (math.log(freq / 440.0) / math.log(2.0));
        return ((midi.round() % 12) + 12) % 12;
      }
    }
    return -1;
  }

  /// Detects the chord from a PRECOMPUTED magnitude spectrum. Prefer this when
  /// the caller already has `mags` (e.g. the engine, which computes the FFT
  /// once per frame and shares it between the chroma count and chord scoring).
  ///
  /// [mags] is the padded magnitude spectrum; [n] is the FFT size (mags.length
  /// * 2).
  ChordResult? detectFromSpectrum(
      List<double> mags,
      int n, {
        double minScore = 0.20,
      }) {
    final rawChroma = _chromaFrom(mags, n);
    final c = _smoothedChroma(rawChroma);
    if (c.reduce((a, b) => a + b) < 0.5) return null; // essentially silence

    final bass = _detectBassPitchClass(mags, n);

    // Score every template: reward chord tones, penalize non-chord tones.
    _Template? best;
    var bestScore = -1.0;
    for (final t in _templates) {
      final set = t.pitches.toSet();
      var inChord = 0.0;
      var outChord = 0.0;
      for (var pc = 0; pc < 12; pc++) {
        if (set.contains(pc)) {
          inChord += c[pc];
        } else {
          outChord += c[pc];
        }
      }
      var score =
          inChord / t.pitches.length - 0.5 * outChord / (12 - t.pitches.length);
      // Bass bonus: reward chords whose root matches the detected bass note.
      if (bass >= 0 && t.pitches.isNotEmpty && t.pitches[0] == bass) {
        score += 0.15;
      }
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }

    if (bestScore < minScore) return null; // reject weak matches
    final candidateName = best?.name;
    if (candidateName == null) return null;

    // Hysteresis: only switch chords when the challenger is clearly better.
    const switchMargin = 0.08;
    if (candidateName == _currentChord) {
      _currentScore = bestScore;
    } else if (bestScore > _currentScore + switchMargin) {
      _currentChord = candidateName;
      _currentScore = bestScore;
    }
    return _currentChord == null
        ? null
        : ChordResult(_currentChord!, _currentScore);
  }

  /// Detects the chord in the buffer.
  /// Pipeline: padded FFT (once) → interpolated + harmonic-weighted chroma →
  /// temporal averaging → bass detection → template scoring with bass bonus →
  /// hysteresis → result.
  ///
  /// Convenience wrapper that computes the FFT itself. If you already have the
  /// spectrum, call [detectFromSpectrum] to avoid recomputing it.
  ChordResult? detect(List<double> buffer, {double minScore = 0.20}) {
    final mags = FFT.magnitudePadded(buffer, padFactor: 2);
    return detectFromSpectrum(mags, mags.length * 2, minScore: minScore);
  }

  /// Builds the raw (unsmoothed) chroma from a PRECOMPUTED spectrum. Used by
  /// the engine's note-vs-chord branch when it already has `mags`.
  List<double> chromaFromSpectrum(List<double> mags, int n) {
    return _chromaFrom(mags, n);
  }

  /// Clears rolling state; call on silence so the next chord starts fresh.
  void reset() {
    _currentChord = null;
    _currentScore = 0.0;
    _chromaHistory.clear();
  }

  /// Public chroma accessor for the engine's note-vs-chord branch.
  /// Convenience wrapper that computes the FFT itself.
  List<double> chroma(List<double> buffer) {
    final mags = FFT.magnitudePadded(buffer, padFactor: 2);
    return _chromaFrom(mags, mags.length * 2);
  }
}