import 'dart:math' as math;

/// Target frequency for each peg, used to separate the two E strings.
const Map<String, double> _stringFreqs = {
  'E': 82.41, // low E, 6th string
  'A': 110.00,
  'D': 146.83,
  'G': 196.00,
  'B': 246.94,
  'e': 329.63, // high e, 1st string
};

/// How far the detected freq is from a target, in cents (log scale).
double centsFrom(double resultFreq, double target) => resultFreq <= 0
    ? double.maxFinite
    : 1200.0 * (math.log(resultFreq / target) / math.log(2.0));

/// A peg is "current" when the detected note letter matches AND (for the two E
/// strings) the frequency is near THAT E's octave. Non-E strings only need the
/// letter, but checking frequency for all of them is harmless and more robust.
bool isPegActive({
  required double resultFreq,
  required String resultNote,
  required String peg,
}) {
  if (resultNote == '-') return false;
  final target = _stringFreqs[peg];
  if (target == null) return false;
  // Case-INSENSITIVE letter check ("E" matches both pegs by name); the
  // frequency gate below is what actually separates low E from high e.
  final letterMatches = resultNote.toLowerCase() == peg.toLowerCase();
  if (!letterMatches) return false;
  // ...then frequency must be within ~1 semitone of THIS peg's octave.
  return centsFrom(resultFreq, target).abs() < 100;
}