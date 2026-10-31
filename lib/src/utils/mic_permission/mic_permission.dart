import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:record/record.dart';

/// Microphone permission state used by [PitchKitListener].
enum MicStatus { granted, denied, permanentlyDenied }

/// Microphone permission without permission_handler's iOS build-time setup
/// (#7). On iOS, permission_handler only checks the mic when
/// PERMISSION_MICROPHONE is compiled in, and otherwise always reports denied.
/// `record` checks it directly instead. Android keeps permission_handler,
/// which needs no setup there.
class MicPermission {
  /// Current state, without showing a prompt.
  static Future<MicStatus> status() => _check(request: false);

  /// Shows the system prompt if it can still be shown.
  static Future<MicStatus> request() => _check(request: true);

  /// Opens this app's page in the system Settings (works on iOS without
  /// any permission_handler build flags).
  static Future<bool> openSettings() => ph.openAppSettings();

  static Future<MicStatus> _check({required bool request}) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final recorder = AudioRecorder();
      try {
        if (await recorder.hasPermission(request: request)) {
          return MicStatus.granted;
        }
        // iOS shows the prompt only once; after a "no", only Settings can
        // change it, so a failed request means permanently denied.
        return request ? MicStatus.permanentlyDenied : MicStatus.denied;
      } finally {
        await recorder.dispose();
      }
    }

    final s = request
        ? await ph.Permission.microphone.request()
        : await ph.Permission.microphone.status;
    if (s.isGranted) return MicStatus.granted;
    if (s.isPermanentlyDenied) return MicStatus.permanentlyDenied;
    return MicStatus.denied;
  }
}
