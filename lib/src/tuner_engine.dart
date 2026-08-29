import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'audio_capture.dart';
import 'chord_detector.dart';
import 'fft.dart';
import 'models/instrument_profile.dart';
import 'note_result.dart';
import 'yin_pitch_detector.dart';

/// Internal engine result, mirrors TunerEngine.Result in the Kotlin source.
/// Exactly one of these per frame; the UI handles each with a switch.
sealed class EngineResult {
  const EngineResult();
}

class EngineNote extends EngineResult {
  final String name;
  final double cents;
  final double freq;

  const EngineNote(this.name, this.cents, this.freq);
}

class EngineChord extends EngineResult {
  final String name;

  const EngineChord(this.name);
}

class EngineSilence extends EngineResult {
  const EngineSilence();
}

class TunerEngine {
  /// The instrument to tune/detect for. Defaults to guitar so existing callers
  /// keep working unchanged.
  final InstrumentProfile profile;

  /// The microphone's sample rate.
  final int sampleRate;

  /// The number of samples per frame.
  final int frameSize;

  TunerEngine({
    this.profile = InstrumentProfile.guitar,
    this.sampleRate = 44100,
    this.frameSize = 8192,
  }) : _capture = AudioCapture(sampleRate: sampleRate, frameSize: frameSize),
        _yin = YinPitchDetector(sampleRate),
  // Pass the profile down so the detector uses this instrument's bounds.
        _chordDetector = ChordDetector(sampleRate, profile),
  // Loudness gate now comes from the profile rather than being hardcoded.
        _rmsGate = profile.rmsGate;

  final AudioCapture _capture;
  final YinPitchDetector _yin;
  final ChordDetector _chordDetector;
  final double _rmsGate;

  // Debounce state to suppress one-frame flickers.
  final Queue<String> _history = Queue<String>();
  EngineResult _lastStable = const EngineSilence();
  static const int _requiredAgreement = 2;

  StreamController<EngineResult>? _controller;

  /// Starts capture and returns a stream of results. Cancelling the stream
  /// subscription releases the mic.
  Stream<EngineResult> start() {
    _controller = StreamController<EngineResult>(
      onCancel: stop, // flow cancelled → release the mic
    );

    _capture.start((raw) {
      final buf = _preProcess(raw); // clean the signal first

      // Energy gate: skip frames quieter than the profile's rmsGate.
      final rms = math.sqrt(
        buf.map((it) => it * it).reduce((a, b) => a + b) / buf.length,
      );
      if (rms < _rmsGate) {
        _chordDetector.reset(); // clear hysteresis so next chord starts clean
        _controller?.add(const EngineSilence());
        return;
      }

      // Compute the padded FFT ONCE for this frame and share it between the
      // note-vs-chord decision and (if needed) chord scoring. Previously the
      // spectrum was computed twice on chord frames.
      final mags = FFT.magnitudePadded(buf, padFactor: 2);
      final n = mags.length * 2;

      // Decide single note vs chord by counting strongly-present pitch classes.
      final chroma = _chordDetector.chromaFromSpectrum(mags, n);
      final strongPitches = chroma.where((it) => it > 0.50).length;

      EngineResult result;
      if (strongPitches <= 1) {
        // Monophonic → YIN for precise pitch + cents. Bounded by the profile's
        // minFreq so the O(n²) search stays cheap. Uses the profile's
        // flat/sharp preference for the note name.
        final f = _yin.detect(buf, minFreq: profile.minFreq);
        final note = NoteMapper.frequencyToNote(f, useFlats: profile.useFlats);
        result = note != null
            ? EngineNote(note.name, note.cents, note.frequency)
            : const EngineSilence();
      } else {
        // Polyphonic → chord template matching, reusing the same spectrum.
        final chord = _chordDetector.detectFromSpectrum(mags, n);
        result = chord != null
            ? EngineChord(chord.name)
            : const EngineSilence();
      }

      _controller?.add(_smooth(result));
    });

    return _controller!.stream;
  }

  /// Stops capture and closes the stream.
  Future<void> stop() async {
    await _capture.stop();
    await _controller?.close();
    _controller = null;
  }

  /// Pre-processing: DC-offset removal + a one-pole high-pass to cut rumble.
  List<double> _preProcess(List<double> raw) {
    final out = List<double>.of(raw);
    // Remove DC bias so the waveform is centred on zero (pitch math assumes
    // this).
    final mean = out.reduce((a, b) => a + b) / out.length;
    for (var i = 0; i < out.length; i++) {
      out[i] -= mean;
    }
    // First-order high-pass: attenuates low-frequency rumble.
    var prev = 0.0;
    var prevOut = 0.0;
    const alpha = 0.95;
    for (var i = 0; i < out.length; i++) {
      final cur = out[i];
      final hp = alpha * (prevOut + cur - prev);
      prev = cur;
      prevOut = hp;
      out[i] = hp;
    }
    return out;
  }

  /// Debounces output: only updates once one result dominates the recent
  /// window.
  EngineResult _smooth(EngineResult r) {
    final key = switch (r) {
      EngineNote() => r.name,
      EngineChord() => r.name,
      EngineSilence() => '~',
    };
    _history.addLast(key);
    if (_history.length > 4) _history.removeFirst();

    // Find the most common key in the recent window.
    final counts = <String, int>{};
    for (final k in _history) {
      counts[k] = (counts[k] ?? 0) + 1;
    }
    MapEntry<String, int>? majority;
    for (final e in counts.entries) {
      if (majority == null || e.value > majority.value) majority = e;
    }
    // Only commit once the leader has enough agreement.
    if (majority != null && majority.value >= _requiredAgreement) {
      _lastStable = r;
    }
    return _lastStable;
  }
}