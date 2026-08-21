import 'dart:math' as math;

/// In-place iterative radix-2 Cooley–Tukey FFT and magnitude-spectrum helpers.
class FFT {
  /// In-place iterative radix-2 Cooley–Tukey FFT.
  /// Converts a signal from the TIME domain to the FREQUENCY domain.
  /// [re] = real parts (your samples), [im] = imaginary parts (start at 0).
  /// Both lists are overwritten with the result. Length must be a power of 2.
  static void transform(List<double> re, List<double> im) {
    final n = re.length;
    if (n == 1) return;
    if (n & (n - 1) != 0) {
      throw ArgumentError('length must be power of 2');
    }

    // ---- Bit-reversal permutation ----
    // The FFT emits outputs in bit-reversed index order, so we pre-shuffle the
    // inputs to compensate (e.g. index 001 swaps with 100).
    var j = 0;
    for (var i = 1; i < n; i++) {
      var bit = n >> 1;
      while (j & bit != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j |= bit;
      if (i < j) {
        // Swap re[i]/re[j] and im[i]/im[j].
        final tmpRe = re[i];
        re[i] = re[j];
        re[j] = tmpRe;
        final tmpIm = im[i];
        im[i] = im[j];
        im[j] = tmpIm;
      }
    }

    // ---- Butterfly computation ----
    // Merge sub-transforms of size 2, 4, 8, ... n, each stage combining pairs
    // via a rotating "twiddle factor" (a point on the complex unit circle).
    var len = 2;
    while (len <= n) {
      final ang = -2.0 * math.pi / len;
      final wRe = math.cos(ang);
      final wIm = math.sin(ang);
      var i = 0;
      while (i < n) {
        var curRe = 1.0;
        var curIm = 0.0;
        for (var k = 0; k < len ~/ 2; k++) {
          final aRe = re[i + k];
          final aIm = im[i + k];
          // second value * twiddle (complex multiply)
          final bRe =
              re[i + k + len ~/ 2] * curRe - im[i + k + len ~/ 2] * curIm;
          final bIm =
              re[i + k + len ~/ 2] * curIm + im[i + k + len ~/ 2] * curRe;
          re[i + k] = aRe + bRe;
          im[i + k] = aIm + bIm;
          re[i + k + len ~/ 2] = aRe - bRe;
          im[i + k + len ~/ 2] = aIm - bIm;
          // rotate twiddle by the base angle
          final nRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = nRe;
        }
        i += len;
      }
      len <<= 1;
    }
  }

  /// Plain magnitude spectrum (no padding). Kept for callers that don't need
  /// the finer resolution. Uses the largest power of 2 that fits the input.
  static List<double> magnitude(List<double> samples) {
    return magnitudePadded(samples, padFactor: 1);
  }

  /// Zero-padded magnitude spectrum.
  /// Zero-padding does NOT add real information, but it INTERPOLATES the
  /// spectrum onto a finer frequency grid, which helps resolve closely-spaced
  /// LOW notes (e.g. E2 vs F2, where FFT bins are naturally coarse).
  ///
  /// [padFactor] 1 = no padding; 2 = double the FFT size; etc. Higher = finer
  /// grid but more CPU. Must keep the result a power of 2.
  static List<double> magnitudePadded(List<double> samples,
      {int padFactor = 2}) {
    final base = _highestOneBit(samples.length); // largest pow2 that fits
    final n = base * padFactor; // padded size (still pow2)
    final re = List<double>.filled(n, 0.0); // entries past `base` stay 0 = padding
    final im = List<double>.filled(n, 0.0);

    // Apply a Hann window to the REAL samples only (the padded tail stays zero).
    // Windowing tapers the buffer edges to reduce spectral leakage.
    for (var i = 0; i < base; i++) {
      final w = 0.5 * (1 - math.cos(2 * math.pi * i / (base - 1)));
      re[i] = samples[i] * w;
    }

    transform(re, im);

    // Magnitude of each bin = sqrt(real² + imag²) = strength of that frequency.
    final mags = List<double>.filled(n ~/ 2, 0.0);
    for (var i = 0; i < n ~/ 2; i++) {
      mags[i] = _hypot(re[i], im[i]);
    }
    return mags;
  }

  /// Refines a peak's true position using its two neighboring bins.
  /// An FFT bin covers a RANGE of frequencies, so a real note usually falls
  /// BETWEEN bin centers. Fitting a parabola through (bin-1, bin, bin+1)
  /// recovers the true peak to sub-bin accuracy, so its energy maps to the
  /// right pitch class.
  ///
  /// Returns a fractional bin offset, roughly in -0.5..+0.5, to ADD to [bin].
  static double interpolatePeak(List<double> mags, int bin) {
    if (bin <= 0 || bin >= mags.length - 1) return 0.0;
    final a = mags[bin - 1];
    final b = mags[bin];
    final g = mags[bin + 1];
    final denom = a - 2 * b + g;
    if (denom == 0.0) return 0.0;
    // Vertex of the parabola through the three sample points.
    return 0.5 * (a - g) / denom;
  }

  /// Largest power of 2 that is <= x (mirrors Java's Integer.highestOneBit).
  static int _highestOneBit(int x) {
    if (x <= 0) return 0;
    var result = 1;
    while (result <= x) {
      result <<= 1;
    }
    return result >> 1;
  }

  /// Euclidean distance sqrt(a² + b²), used for bin magnitude.
  static double _hypot(double a, double b) => math.sqrt(a * a + b * b);
}