export 'src/pitch_kit_listener.dart';
export 'src/models/instrument_profile.dart';
export 'src/tuning_result.dart';
import 'pitch_kit_platform_interface.dart';

class PitchKit {
  Future<String?> getPlatformVersion() {
    return PitchKitPlatform.instance.getPlatformVersion();
  }
}