## 0.0.2

* 🐛 Tuner recovers after audio interruptions (calls, Siri, alarms) and when returning from the background ([#10](https://github.com/NicosNicolaou16/pitch_kit/issues/10)).
* 🎙️ The microphone is released while the app is in the background.
* 🐛 Microphone capture failures are no longer silent: new optional `onError` callback on `GuitarTunerListener` ([#9](https://github.com/NicosNicolaou16/pitch_kit/issues/9)).
* 🍎 iOS microphone permission no longer needs `PERMISSION_MICROPHONE`, Podfile macros or clearing DerivedData; only `NSMicrophoneUsageDescription` is required ([#7](https://github.com/NicosNicolaou16/pitch_kit/issues/7)).
* 📱 Example app: moved `NSMicrophoneUsageDescription` to the top level of `Info.plist`, fixing a crash on launch on a fresh iOS install ([#14](https://github.com/NicosNicolaou16/pitch_kit/pull/14)).

## 0.0.1

* 🎉 Initial release!
