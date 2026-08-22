import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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

  /// The subtree rendered underneath the listener.
  final Widget child;

  const GuitarTunerListener({
    super.key,
    this.profile = InstrumentProfile.guitar,
    this.titleText = 'Microphone needed',
    this.permanentlyDeniedText = 'Microphone access is blocked. Please enable it in Settings to tune your guitar.',
    this.rationaleText = 'This app needs microphone access to detect notes and chords from your guitar.',
    this.openSettingsText = 'Open Settings',
    this.allowText = 'Allow',
    this.dismissText = 'Not now',
    required this.onResult,
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
    // Re-check on resume so returning from Settings (where the user may have
    // granted it) picks the permission up automatically.
    if (state == AppLifecycleState.resumed) {
      _refreshPermission();
    }
  }

  /// Checks current status and, if needed, fires the system permission prompt.
  Future<void> _checkAndRequest() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      _onGranted();
    } else {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        _onGranted();
      } else if (mounted) {
        // Denied → explain why, and route to Settings if it's permanent.
        _showPermissionDialog(permanentlyDenied: result.isPermanentlyDenied);
      }
    }
  }

  /// Called on resume; picks up a permission granted from the Settings screen.
  Future<void> _refreshPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted && !_granted) {
      if (_dialogShowing && mounted) Navigator.of(context).pop();
      _onGranted();
    }
  }

  /// Spins up the engine and starts streaming results once permission is held.
  void _onGranted() {
    if (_granted) return; // already running
    setState(() => _granted = true);
    final engine = TunerEngine(profile: widget.profile);
    _engine = engine;
    _sub = engine.start().listen((result) {
      // Convert the internal result to the public type before handing it out.
      widget.onResult(result.toPublic());
    });
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
                await openAppSettings();
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
    _sub?.cancel();
    _engine?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
