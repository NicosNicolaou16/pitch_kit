import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_kit/pitch_kit.dart';
import 'package:pitch_kit/pitch_kit_platform_interface.dart';
import 'package:pitch_kit/pitch_kit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPitchKitPlatform
    with MockPlatformInterfaceMixin
    implements PitchKitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PitchKitPlatform initialPlatform = PitchKitPlatform.instance;

  test('$MethodChannelPitchKit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPitchKit>());
  });

  test('getPlatformVersion', () async {
    PitchKit pitchKitPlugin = PitchKit();
    MockPitchKitPlatform fakePlatform = MockPitchKitPlatform();
    PitchKitPlatform.instance = fakePlatform;

    expect(await pitchKitPlugin.getPlatformVersion(), '42');
  });
}
