## 0.0.3

* ✏️ Renamed `GuitarTunerListener` to `PitchKitListener`, since it works for any instrument profile. The old name still works but is deprecated and will be removed in a future version.

## 0.0.2

* 🐛 Tuner recovers after audio interruptions (calls, Siri, alarms) and when returning from the background ([#10](https://github.com/NicosNicolaou16/pitch_kit/issues/10)).
* 🎙️ The microphone is released while the app is in the background.
* 🐛 Microphone capture failures are no longer silent: new optional `onError` callback on `GuitarTunerListener` ([#9](https://github.com/NicosNicolaou16/pitch_kit/issues/9)).
* 🍎 iOS microphone permission no longer needs `PERMISSION_MICROPHONE`, Podfile macros or clearing DerivedData; only `NSMicrophoneUsageDescription` is required ([#7](https://github.com/NicosNicolaou16/pitch_kit/issues/7)).
* 📦 `InstrumentProfile` and `OpenString` are now exported, so custom tunings work from `package:pitch_kit/pitch_kit.dart` ([#8](https://github.com/NicosNicolaou16/pitch_kit/issues/8)).
* 📱 Example app: added `NSMicrophoneUsageDescription` at the top level of `Info.plist`, fixing the blocked microphone and the crash on a fresh iOS install ([#6](https://github.com/NicosNicolaou16/pitch_kit/issues/6), [#14](https://github.com/NicosNicolaou16/pitch_kit/pull/14)).
* ⬆️ Updated `record` to `^7.1.2` and `permission_handler` to `^13.0.2`.

## 0.0.1

* 🎉 Initial release!
