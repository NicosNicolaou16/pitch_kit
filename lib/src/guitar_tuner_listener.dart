import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_kit/src/utils/mic_permission/mic_permission.dart';

import 'extensions/extensions.dart';
import 'models/instrument_profile.dart';
import 'tuner_engine.dart';
import 'tuning_result.dart';

/// Runs the tuner and streams typed [TuningResult] values through [onResult].
/// Handles the microphone permission internally (including the rationale popup
/// and the permanently-denied → Settings path), so the caller only handles
/// results.
///
/// Wrap any subtree in this widget; [child] is rendered unchanged while the
/// tuner runs in the background.
class GuitarTunerListener extends StatefulWidget {
  /// The instrument to tune/detect for. Defaults to [InstrumentProfile.guitar].
  final InstrumentProfile profile;

  /// Shown in the popup title.
  final String titleText;

  /// Shown in the popup when the user has permanently denied the permission
  /// (the button then opens Settings).
  final String permanentlyDeniedText;

  /// Shown in the popup when the permission can still be requested.
  final String rationaleText;

  /// Label for the confirm button when the permission is permanently denied,
  /// and it opens Settings.
  final String openSettingsText;

  /// Label for the confirm button when the permission can still be requested.
  final String allowText;

  /// Label for the dismiss button.
  final String dismissText;

  /// Called with each detection result.
  final void Function(TuningResult) onResult;

  /// Called when the microphone can't be captured (e.g. in use by another
  /// app, audio session failure). Detection stops and restarts the next time
  /// the app returns to the foreground. If null, the error is only logged.
  final void Function(Object error)? onError;

  /// The subtree rendered underneath the listener.
  final Widget child;

  const GuitarTunerListener({
    super.key,
    this.profile = InstrumentProfile.guitar,
    this.titleText = 'Microphone needed',
    this.permanentlyDeniedText =
        'Microphone access is blocked. Please enable it in Settings to tune your guitar.',
    this.rationaleText =
        'This app needs microphone access to detect notes and chords from your guitar.',
    this.openSettingsText = 'Open Settings',
    this.allowText = 'Allow',
    this.dismissText = 'Not now',
    required this.onResult,
    this.onError,
    required this.child,
  });

  @override
  State<GuitarTunerListener> createState() => _GuitarTunerListenerState();
}

class _GuitarTunerListenerState extends State<GuitarTunerListener>
    with WidgetsBindingObserver {
  TunerEngine? _engine;
  StreamSubscription<EngineResult>? _sub;
  bool _granted = false;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Request on first appearance if not already granted.
    _checkAndRequest();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopEngine(); // release the mic in the background
    } else if (state == AppLifecycleState.resumed) {
      // Fresh engine on return; also picks up a permission granted in Settings.
      _granted ? _startEngine() : _refreshPermission();
    }
  }

  /// Checks current status and, if needed, fires the system permission prompt.
  Future<void> _checkAndRequest() async {
    final status = await MicPermission.status();
    if (status == MicStatus.granted) {
      _onGranted();
    } else {
      final result = await MicPermission.request();
      if (result == MicStatus.granted) {
        _onGranted();
      } else if (mounted) {
        // Denied → explain why, and route to Settings if it's permanent.
        _showPermissionDialog(
            permanentlyDenied: result == MicStatus.permanentlyDenied);
      }
    }
  }

  /// Called on resume; picks up a permission granted from the Settings screen.
  Future<void> _refreshPermission() async {
    final status = await MicPermission.status();
    if (status == MicStatus.granted && !_granted) {
      if (_dialogShowing && mounted) Navigator.of(context).pop();
      _onGranted();
    }
  }

  /// Spins up the engine and starts streaming results once permission is held.
  void _onGranted() {
    if (!_granted) setState(() => _granted = true);
    _startEngine();
  }

  /// Shows the rationale / permanently-denied popup.
  Future<void> _showPermissionDialog({required bool permanentlyDenied}) async {
    if (_dialogShowing) return; // avoid stacking dialogs
    _dialogShowing = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.titleText),
        content: Text(
          permanentlyDenied
              ? widget.permanentlyDeniedText
              : widget.rationaleText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(widget.dismissText),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (permanentlyDenied) {
                // Button opens the app's system settings page.
                await MicPermission.openSettings();
              } else {
                // Permission can still be asked for → prompt again.
                await _checkAndRequest();
              }
            },
            child: Text(
              permanentlyDenied ? widget.openSettingsText : widget.allowText,
            ),
          ),
        ],
      ),
    );
    _dialogShowing = false;
  }

  @override
  void dispose() {
    // Release observer, stream, and mic when the widget goes away.
    WidgetsBinding.instance.removeObserver(this);
    _stopEngine();
    super.dispose();
  }

  void _startEngine() {
    if (_engine != null) return;
    final engine = TunerEngine(profile: widget.profile);
    _engine = engine;
    _sub = engine.start().listen(
      (r) => widget.onResult(r.toPublic()),
      onError: (Object e) {
        // Release the broken recorder; the next resume starts a fresh one.
        _stopEngine();
        final onError = widget.onError;
        if (onError != null) {
          onError(e);
        } else {
          debugPrint('pitch_kit: microphone capture failed: $e');
        }
      },
    );
  }

  Future<void> _stopEngine() async {
    final sub = _sub;
    _engine = null;
    _sub = null;
    await sub?.cancel(); // onCancel → engine.stop() → recorder disposed
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
