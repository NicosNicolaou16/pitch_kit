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

Version Minimum Flutter SDK: 3.22.0

Tested Versioning:  
Flutter SDK version: 3.44.8  
Dart Version: 3.12.2

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


