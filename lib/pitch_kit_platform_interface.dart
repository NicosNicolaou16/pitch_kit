import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'pitch_kit_method_channel.dart';

abstract class PitchKitPlatform extends PlatformInterface {
  /// Constructs a PitchKitPlatform.
  PitchKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static PitchKitPlatform _instance = MethodChannelPitchKit();

  /// The default instance of [PitchKitPlatform] to use.
  ///
  /// Defaults to [MethodChannelPitchKit].
  static PitchKitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PitchKitPlatform] when
  /// they register themselves.
  static set instance(PitchKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
