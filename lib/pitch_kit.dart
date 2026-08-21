
import 'pitch_kit_platform_interface.dart';

class PitchKit {
  Future<String?> getPlatformVersion() {
    return PitchKitPlatform.instance.getPlatformVersion();
  }
}
