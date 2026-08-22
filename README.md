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



