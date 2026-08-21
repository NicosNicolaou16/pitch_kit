/*
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:pitch_kit/pitch_kit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _pitchKitPlugin = PitchKit();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _pitchKitPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(child: Text('Running on: $_platformVersion\n')),
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:pitch_kit/pitch_kit.dart';
import 'helpers/peg_helpers.dart';

void main() {
  runApp(const PitchKitApp());
}

class PitchKitApp extends StatelessWidget {
  const PitchKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pitch Kit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
      ),
      home: const TunerScreen(),
    );
  }
}

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  String _resultNote = '-';
  double _resultFreq = 0.0;

  void _onResult(TuningResult result) {
    setState(() {
      if (result is NoteTuningResult) {
        _resultFreq = result.freq;
      }
      _resultNote = switch (result) {
      // "${result.name} ${result.freq} (${result.cents}¢)" if you want detail
        NoteTuningResult() => result.name,
        ChordTuningResult() => result.name,
        SilenceTuningResult() => '-',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    // GuitarTunerListener handles mic permission and streams results; it
    // renders [child] underneath while running in the background.
    return Scaffold(
      body: SafeArea(
        child: GuitarTunerListener(
          onResult: _onResult,
          child: ExpressiveTunerUI(
            resultNote: _resultNote,
            resultFreq: _resultFreq,
          ),
        ),
      ),
    );
  }
}

class ExpressiveTunerUI extends StatelessWidget {
  final String resultNote;
  final double resultFreq;

  const ExpressiveTunerUI({
    super.key,
    required this.resultNote,
    required this.resultFreq,
  });

  // Standard guitar tuning targets.
  static const List<String> _standardStrings = ['E', 'A', 'D', 'G', 'B', 'e'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Check if the detected note matches a standard string. isPegActive uses
    // the frequency gate to separate low E from high e.
    final isStandardNote = _standardStrings.any(
          (peg) => isPegActive(
        resultFreq: resultFreq,
        resultNote: resultNote,
        peg: peg,
      ),
    );

    // Smoothly animate the main note color to green when a target is detected.
    final animatedNoteColor = isStandardNote
        ? const Color(0xFF4CAF50)
        : colorScheme.onSurface;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            'Pitch Kit',
            style: textTheme.headlineMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Main expressive note display.
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              // Mirrors Compose's autoSize: scales the glyph to fit the circle.
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: textTheme.displayLarge!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: animatedNoteColor,
                  ),
                  child: Text(
                    resultNote,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Standard strings indicator row.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _standardStrings.map((stringNote) {
              final isCurrentTarget = isPegActive(
                resultFreq: resultFreq,
                resultNote: resultNote,
                peg: stringNote,
              );
              return _PegIndicator(
                label: stringNote,
                isActive: isCurrentTarget,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// A single tuning-peg circle that pops and turns green when it's the detected
/// target. Bundles the three Compose animations (bg color, text color, scale).
class _PegIndicator extends StatelessWidget {
  final String label;
  final bool isActive;

  const _PegIndicator({required this.label, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final backgroundColor = isActive
        ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
        : Colors.transparent;
    final textColor =
    isActive ? const Color(0xFF2E7D32) : colorScheme.onSurfaceVariant;

    // A slight pop when the string goes active (1.0 → 1.2), animated.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: isActive ? 1.2 : 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: textTheme.titleLarge!.copyWith(
            color: textColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}