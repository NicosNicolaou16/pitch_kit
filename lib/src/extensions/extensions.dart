import 'package:pitch_kit/src/tuner_engine.dart';
import 'package:pitch_kit/src/tuning_result.dart';

/// Bridges the internal engine result to the public API type, keeping the
/// engine and its result type hidden from library consumers.
extension EngineResultToPublic on EngineResult {
  TuningResult toPublic() {
    final self = this;
    return switch (self) {
      EngineNote() =>
          NoteTuningResult(name: self.name, cents: self.cents, freq: self.freq),
      EngineChord() => ChordTuningResult(name: self.name),
      EngineSilence() => const SilenceTuningResult(),
    };
  }
}