export 'src/guitar_tuner_listener.dart';
export 'src/tuning_result.dart';
import 'pitch_kit_platform_interface.dart';

class PitchKit {
  Future<String?> getPlatformVersion() {
    return PitchKitPlatform.instance.getPlatformVersion();
  }
}