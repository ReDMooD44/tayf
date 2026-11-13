# TAYF

**Flutter · Dart 3.14+ · Android & Web · Spectral Optics Puzzle Game**

**TAYF** is a minimalist optical physics and puzzle game built around the principles of light refraction, reflection, and wavelength dispersion. Guide white light using mirrors, lenses, prisms, and gravity wells—or split it into its spectral components—to illuminate the target sensors.

---

## Features

* **Realistic Spectral Physics Engine (`engine.dart`):** Simulates light across 12 distinct wavelength bands (412.5 nm – 687.5 nm), calculating prism and lens refraction in real time via Cauchy's equation ($n(\lambda) = a + b/\lambda^2$).
* **Optical Elements:** Mirrors (reflection), Prisms (dispersing white light into a rainbow spectrum), Biconvex Lenses (focusing), Glass Blocks, and light-bending Gravity Wells.
* **Hand-Crafted & Procedural Levels:** Features 6 hand-crafted introductory levels teaching core mechanics (*First Light, Spectrum, Focal Point, Gravity Well, Color Sorting, Light Labyrinth*), followed by a `mulberry32` PRNG-based **Infinite Procedural Mode** (Level 7+) and a unique **Daily Challenge**.
* **100% Code-Synthesized Audio (`audio_synth.dart`):** Zero external audio files; 44.1 kHz 16-bit PCM WAV buffers are synthesized at runtime. Illuminating each target color triggers distinct harmonic frequencies (A major triad chord and spectral notes).
* **Progression, Energy & Shop (`progress.dart`):** Par score rewards, an offline-regenerating 5-lives system, and an in-game coin shop (*Hint, Extra Time, Extra Piece, Skip Level*).

---

## Gameplay

| Element | Function |
| :--- | :--- |
| **Emitter** | Emits a steady beam of white or spectral light at a fixed angle |
| **Mirror** | Reflects incoming light rays according to the angle of incidence |
| **Prism** | Refracts and disperses white light by wavelength into red, amber, green, and blue spectra |
| **Lens** | Bends and focuses diverging or parallel light rays toward a focal point |
| **Gravity Well** | Warps the trajectory of passing light rays with its gravitational mass |
| **Target Sensor** | Fills up when illuminated by light matching its required wavelength purity (white or pure color) |

---

## Quick Start

### Prerequisites
* Flutter SDK (Dart `^3.14.0`)

### Run & Build

```bash
# Install dependencies
flutter pub get

# Run in development mode (Mobile / Desktop / Web)
flutter run

# Build release Android APK
flutter build apk --release

# Build release Web bundle
flutter build web --release
```

### Tests

```bash
flutter test
```

---

## Project Structure (`lib/`)

* **`main.dart`** — Application entry point, portrait orientation lock, and immersive dark theme setup.
* **`engine.dart`** — 12-wavelength raytracing, Cauchy dispersion math, and gravitational light bending.
* **`render.dart`** — `CustomPainter`-based real-time wavelength-to-RGB conversion (`wlRGB`), laser glow, and sensor animations.
* **`levels.dart` & `generator.dart`** — 6 hand-crafted core levels and a procedural level generator with guaranteed solvability.
* **`audio_synth.dart` & `audio.dart`** — Custom PCM waveform synthesizer, cosmic ambient drone, and harmonic target tones.
* **`game.dart`, `progress.dart`, `storage.dart` & `ui.dart`** — Game loop, timer/lives/economy management, `SharedPreferences` persistence, and cyber-terminal UI.
