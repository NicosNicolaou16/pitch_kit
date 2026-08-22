import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures mic audio via the `record` package and emits fixed-size frames of
/// normalized floats (-1.0..1.0).
///
/// `record` streams raw PCM 16-bit little-endian bytes in platform-chosen
/// chunk sizes, so this class does two jobs the Android AudioRecord version
/// got for free:
///   1. Converts 16-bit ints (-32768..32767) to floats (-1.0..1.0).
///   2. Re-blocks the arbitrary-sized chunks into exact [frameSize] frames via
///      a ring buffer, so the FFT always gets a stable power-of-2 length.
class AudioCapture {
  /// 44.1 kHz — standard, captures up to ~22 kHz (Nyquist).
  final int sampleRate;

  /// Samples per emitted frame. MUST be a power of 2 for the FFT. 8192 ≈ 186ms
  /// at 44.1 kHz — big enough to resolve low E (82 Hz), the same value the
  /// Kotlin version used.
  final int frameSize;

  AudioCapture({this.sampleRate = 44100, this.frameSize = 8192});

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;

  /// Rolling accumulator: leftover samples that didn't fill a frame last chunk.
  final List<double> _ring = <double>[];

  bool _running = false;

  /// Whether the app currently holds microphone permission. `record` exposes
  /// its own check, so you can use this instead of a separate permission plugin
  /// if you prefer.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts capture. [onFrame] fires once per full [frameSize] frame of
  /// normalized floats. The caller must already hold microphone permission.
  Future<void> start(void Function(List<double>) onFrame) async {
    if (_running) return;
    _running = true;

    // Ask for a raw PCM 16-bit stream at our sample rate, single channel.
    // pcm16bits is the only encoder that gives us the untouched waveform the
    // DSP needs (no AAC/opus compression in the path).
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        // Disable OS-level processing so we get the raw signal, mirroring the
        // Android choice of VOICE_RECOGNITION-style untouched audio. These are
        // best-effort per platform.
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );

    _sub = stream.listen((Uint8List chunk) {
      // Interpret the byte buffer as little-endian 16-bit signed samples.
      final bytes = ByteData.sublistView(chunk);
      final sampleCount = chunk.lengthInBytes ~/ 2;

      for (var i = 0; i < sampleCount; i++) {
        final s = bytes.getInt16(i * 2, Endian.little);
        // 16-bit int range → -1.0..1.0 float.
        _ring.add(s / 32768.0);
      }

      // Emit as many complete frames as the ring now holds.
      while (_ring.length >= frameSize) {
        final frame = _ring.sublist(0, frameSize);
        _ring.removeRange(0, frameSize);
        onFrame(frame);
      }
    });
  }

  /// Stops capture and releases the mic. Safe to call when already stopped.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await _sub?.cancel();
    _sub = null;
    _ring.clear();
    await _recorder.stop();
  }

  /// Release native resources. Call when you're done with the recorder for good.
  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
