/// Time-domain fundamental-frequency detector (the YIN algorithm).
class YinPitchDetector {
  final int sampleRate;

  /// Lower = stricter; 0.10–0.15 works well for guitar.
  final double threshold;

  YinPitchDetector(this.sampleRate, {this.threshold = 0.15});

  /// Detects the fundamental of a SINGLE note. YIN works in the time domain,
  /// finding the period at which the signal best repeats itself — this resists
  /// the octave errors that plague simple FFT peak-picking. Returns Hz, or -1.
  double detect(List<double> buffer) {
    final tau = buffer.length ~/ 2;
    final yin = List<double>.filled(tau, 0.0);

    // 1. Difference function: how different is the signal from itself shifted
    //    by t?
    for (var t = 1; t < tau; t++) {
      var sum = 0.0;
      for (var i = 0; i < tau; i++) {
        final delta = buffer[i] - buffer[i + t];
        sum += delta * delta;
      }
      yin[t] = sum;
    }

    // 2. Cumulative mean normalization: lets us use a fixed threshold and
    //    avoids the trivial t=0 dip.
    yin[0] = 1.0;
    var runningSum = 0.0;
    for (var t = 1; t < tau; t++) {
      runningSum += yin[t];
      yin[t] *= t / runningSum;
    }

    // 3. First dip below threshold = the fundamental (not a harmonic).
    var tauEstimate = -1;
    var t = 2;
    while (t < tau) {
      if (yin[t] < threshold) {
        // Walk down into the local minimum for a tighter estimate.
        while (t + 1 < tau && yin[t + 1] < yin[t]) {
          t++;
        }
        tauEstimate = t;
        break;
      }
      t++;
    }
    if (tauEstimate == -1) return -1.0;

    // 4. Parabolic interpolation around the dip for SUB-SAMPLE period accuracy.
    //    This is what makes the cents reading precise rather than quantized.
    final betterTau = _parabolicInterp(yin, tauEstimate);
    return sampleRate / betterTau;
  }

  /// Fits a parabola through 3 points around the dip to refine the minimum.
  double _parabolicInterp(List<double> yin, int tau) {
    final x0 = tau > 0 ? tau - 1 : tau; // left neighbor
    final x2 = (tau + 1 < yin.length) ? tau + 1 : tau; // right neighbor
    // Edge cases where a neighbor doesn't exist: just pick the smaller point.
    if (x0 == tau) return yin[tau] <= yin[x2] ? tau.toDouble() : x2.toDouble();
    if (x2 == tau) return yin[tau] <= yin[x0] ? tau.toDouble() : x0.toDouble();
    final s0 = yin[x0];
    final s1 = yin[tau];
    final s2 = yin[x2];
    // Standard vertex-of-parabola formula. denom==0 means flat → no shift.
    final denom = 2 * (2 * s1 - s2 - s0);
    return denom == 0.0 ? tau.toDouble() : tau + (s2 - s0) / denom;
  }
}