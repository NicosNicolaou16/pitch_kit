# pitch_kit

## ✨ Features

A modern and easy-to-use Flutter package for real-time guitar tuning and chord detection straight from the device microphone, with a pure Dart DSP core:

- 🎸 **Note Detection** – Detect individual notes (E, A, D, G, B, …) with the YIN pitch-detection algorithm for accurate, octave-error-resistant results.
- 🎶 **Chord Detection** – Recognize chords such as `Am`, `Bb`, `C`, `Em7`, and `Asus2` using chroma analysis and template matching.
- 🎚️ **Tuning in Cents** – Every detected note reports how flat or sharp it is, ready to drive a tuner needle.
- 🎻 **Multi-Instrument Ready** – Built-in `InstrumentProfile` presets (Guitar, Ukulele, Bass), or supply your own custom tuning.
- 🔇 **Noise Handling** – DC-offset removal, a high-pass filter, an energy gate, and temporal smoothing reduce background interference.
- ⚡ **Real-Time & Efficient** – A from-scratch FFT and `Stream`-based pipeline keep detection fast and off the UI thread.
- 🚀 **Flutter Widget Support** – A single widget handles the microphone permission (including the permanently-denied → Settings flow) and streams results back to you.

## 🚀 Getting started

Version Minimum Flutter SDK: 3.3.0

Tested Versioning:  
Flutter SDK version: 3.47.1  
Dart Version: 3.13.1

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  pitch_kit: ^0.0.1
```

Or install it from the command line:

```bash
flutter pub add pitch_kit
```

This package depends on [`record`](https://pub.dev/packages/record) for microphone capture and [`permission_handler`](https://pub.dev/packages/permission_handler) for the runtime permission flow. Both are pulled in automatically.

### 📱 Platform Setup

The microphone permission must be declared in **your app** (not the package) on each platform.

#### Android

Add the microphone permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

#### iOS

**1.** Add the usage description to `ios/Runner/Info.plist`. Without it, iOS terminates the app the instant it accesses the microphone:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to detect notes and chords from your instrument.</string>
```

**2.** `permission_handler` compiles every permission unless you opt out. In `ios/Podfile`, enable **only** the microphone macro inside the `post_install` block:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_EVENTS=0',
        'PERMISSION_EVENTS_FULL_ACCESS=0',
        'PERMISSION_REMINDERS=0',
        'PERMISSION_CONTACTS=0',
        'PERMISSION_CAMERA=0',
        'PERMISSION_PHOTOS=0',
        'PERMISSION_NOTIFICATIONS=0',
        'PERMISSION_MEDIA_LIBRARY=0',
        'PERMISSION_SENSORS=0',
        'PERMISSION_BLUETOOTH=0',
        'PERMISSION_APP_TRACKING_TRANSPARENCY=0',
        'PERMISSION_CRITICAL_ALERTS=0',
        'PERMISSION_ASSISTANT=0',
        'PERMISSION_LOCATION=0',
        'PERMISSION_SPEECH_RECOGNIZER=0',
      ]
    end
  end
end
```

## 💡 Usage

[![](https://github.com/NicosNicolaou16/pitch_kit/raw/main/screenshots/example.gif)](https://github.com/NicosNicolaou16/pitch_kit/raw/main/screenshots/example.gif)

### 🎸 GuitarTunerListener

Wrap any widget with `GuitarTunerListener`. It requests the microphone permission, starts detection,
and streams a typed `TuningResult` back through the `onResult` callback. Detection stops
automatically when the widget is disposed.

| Parameters              | Description                                                                                                                                             |
|-------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `onResult`              | This parameter is required and it's the callback invoked with each detection result (`NoteTuningResult`, `ChordTuningResult`, or `SilenceTuningResult`) |
| `child`                 | This parameter is required and it's the widget rendered while the tuner runs in the background                                                          |
| `profile`               | This parameter is the `InstrumentProfile` to tune for, with default value `InstrumentProfile.guitar` (built-in: `.guitar`, `.ukulele`, `.bass`)         |
| `titleText`             | This parameter is the title text of the permission popup with default value `"Microphone needed"`                                                       |
| `rationaleText`         | This parameter is the text shown when the permission can still be requested                                                                             |
| `permanentlyDeniedText` | This parameter is the text shown when the permission is permanently denied (the button then opens Settings)                                             |
| `allowText`             | This parameter is the confirm button label when the permission can still be requested with default value `"Allow"`                                      |
| `openSettingsText`      | This parameter is the confirm button label when the permission is permanently denied with default value `"Open Settings"`                               |
| `dismissText`           | This parameter is the dismiss button label with default value `"Not now"`                                                                               |

### 🎶 TuningResult

`TuningResult` is a sealed class with three cases you can handle exhaustively:

| Type                  | Description                                                                                         |
|-----------------------|-----------------------------------------------------------------------------------------------------|
| `NoteTuningResult`    | A single detected note: `name` (e.g. `"E"`, `"A#"`), `freq` (Hz), and `cents` (deviation, -50..+50) |
| `ChordTuningResult`   | A detected chord: `name` (e.g. `"Am"`, `"Cmaj7"`)                                                   |
| `SilenceTuningResult` | No sound / below the detection threshold                                                            |

### 🎻 InstrumentProfile

| Parameters      | Description                                                                                                      |
|-----------------|------------------------------------------------------------------------------------------------------------------|
| `name`          | This parameter is required and it's the human-readable label, e.g. `"Guitar"`                                    |
| `minFreq`       | This parameter is required and it's the lowest frequency (Hz) analysis considers                                 |
| `maxFreq`       | This parameter is required and it's the highest frequency (Hz) considered for chroma                             |
| `bassCeiling`   | This parameter is required and it's the ceiling (Hz) for the chord bass-note scan                                |
| `harmonicPivot` | This parameter is required and it's the frequency (Hz) around which harmonic down-weighting is centred           |
| `openStrings`   | This parameter is required and it's the list of `OpenString` values for the instrument's standard tuning         |
| `rmsGate`       | This parameter is the loudness gate (RMS); frames quieter than this are treated as silence, default value `0.01` |
| `useFlats`      | This parameter is the option to display flats (Bb) instead of sharps (A#), default value `false`                 |

```dart
import 'package:flutter/material.dart';
import 'package:pitch_kit/pitch_kit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pitch Kit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6200EE)),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _resultNote = '-';
  double _resultFreq = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pitch Kit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      // ==========================================
      // 1. Start the tuner
      // ==========================================
      body: GuitarTunerListener(
        profile: InstrumentProfile.guitar,
        onResult: (result) {
          setState(() {
            _resultFreq = result is NoteTuningResult ? result.freq : 0.0;
            _resultNote = switch (result) {
              NoteTuningResult() => result.name,
              ChordTuningResult() => result.name,
              SilenceTuningResult() => '-',
            };
          });
        },
        // ==========================================
        // 2. Render your UI
        // ==========================================
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _resultNote,
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_resultFreq > 0)
                Text(
                  '${_resultFreq.toStringAsFixed(1)} Hz',
                  style: const TextStyle(fontSize: 20, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 🎼 Custom Tuning

You can supply your own `InstrumentProfile` for non-standard tunings:

```dart
const dropD = InstrumentProfile(
  name: 'Drop D',
  minFreq: 60.0,
  maxFreq: 5000.0,
  bassCeiling: 400.0,
  harmonicPivot: 200.0,
  openStrings: [
    OpenString('D2', 73.42),
    OpenString('A2', 110.00),
    OpenString('D3', 146.83),
    OpenString('G3', 196.00),
    OpenString('B3', 246.94),
    OpenString('E4', 329.63),
  ],
);

GuitarTunerListener(
  profile: dropD,
  onResult: (result) {
    //...your code here
  },
  child: const SizedBox(),
);
```

### 🎹 Supported Chords

Each of the 12 roots is combined with the following qualities: `major`, `minor` (`m`), `dominant 7th` (`7`), `minor 7th` (`m7`), `major 7th` (`maj7`), `sus2`, `sus4`, `diminished` (`dim`), and `augmented` (`aug`).

Examples: `C`, `Am`, `G7`, `Em7`, `Dmaj7`, `Asus2`, `Bdim`, `Faug`.

## ℹ️ Additional information

Thank you for using **pitch_kit**! Your feedback helps make this package better.
If you encounter any bugs or unexpected behavior, please open an issue on
the [GitHub repository](https://github.com/NicosNicolaou16/pitch_kit/issues).