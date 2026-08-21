import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pitch_kit_platform_interface.dart';

/// An implementation of [PitchKitPlatform] that uses method channels.
class MethodChannelPitchKit extends PitchKitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pitch_kit');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
