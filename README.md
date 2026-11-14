# Brainwave

Formerly Oscillatoire.

This app was vibe coded using Claude (Anthropic's Claude Code).

An iPhone, iPad, Mac and Android app that connects to a Muse EEG headband and shows your brain activity:

- **Mind**: live Focus (β ÷ (α + θ) at the forehead), Calm/meditation (α ÷ β) and Sleepiness (θ ÷ α) scores against your own baseline, with a graph (smoothed, last ten minutes) and session stats for each. Start a calm session from here.
- **Compare**: how two areas move over time, live or from a saved capture. Pick one of four comparisons (left vs right, front vs back, or front and back within the left or right side) and a window of 1 min, 15 min, 1 h or all.
- **Captures**: start and stop a recording window. When you stop, a sheet offers **Save**, **Cancel** or **Download** (a JSON file). Saved captures can be reviewed on a timeline, compared, shared (one share button for the CSV and JSON files), deleted or imported from a JSON file.
- **Calm session**: a breathing guide. A lotus opens on each breath in and closes on each breath out. On Android, the sound is one soft scale on each breath in and the same scale back on each breath out. Sound on or off, sound level and breathing pace are set in Settings.
- **Settings**: appearance (dark, light or system), language, the calm session options, the menu bar (Mac), the remembered headband, the Muse SDK links, and About (with links to the authors' sites). On Android, each option is a card and sound level and breathing pace are sliders.
- **Brain** and **Signals** (advanced view only): the brain map and raw EEG with the share of power in each band. On iPhone they share one **Advanced** tab. The Brain map shows overall activity, or the chosen band in advanced view.
- **Before you start**: when a headband connects, a check shows the battery, each sensor's contact and head movement. Start unlocks once all four sensors touch the skin and you are still.

Languages: English, Persian, French, Dutch, Arabic, Chinese (Simplified), Hindi, Spanish, Russian, German and Japanese. Persian and Arabic are right to left. The translations are not yet reviewed by native speakers.

Supports every headband the Muse SDK does, including Muse 2, Muse S and Muse S Athena (2025). Includes a demo headband for use without hardware.

## Scope and status

Brainwave is free and open source (MIT). It is for personal and educational use: seeing how your
attention, calm and alertness change over time. It is **not a medical device**, it is **not medical
advice**, and it is **not for research or clinical use**. It doesn't diagnose, treat or monitor any
condition. It is not a commercial product.

Brainwave keeps your data on your device. Captures and history are saved locally, and you choose when to share a file.

## Muse SDK

Brainwave uses the Muse SDK to talk to a Muse headband. **This project does not distribute the SDK.**
It is not in this repository, not in its history, and not in any release. You need your own SDK
access from Interaxon:

- Request SDK access: https://choosemuse.com/pages/developers
- Android: the Muse Android SDK (`libmuse_android`) from the same developer page. See the Android section below.
- Muse partner apps and their links: https://choosemuse.com/pages/sdk-partners

Once you have the SDK, follow the steps under Build below to place it on your machine.

For developers (SDK workflow, code structure, definitions, and sensor positions), see [docs/DEVELOPERS.md](docs/DEVELOPERS.md).

## Exporting captures

Each capture can be shared as a CSV (for spreadsheets) or a JSON file (for analysis tools and agents).
The format is described in [docs/CAPTURE_FORMAT.md](docs/CAPTURE_FORMAT.md).

## Related apps

Muse-compatible apps and similar tools, with links, are listed in [docs/SIMILAR_APPS.md](docs/SIMILAR_APPS.md).
Partner apps include Mind Monitor, Myndlift, OptiBrain, OptiTrain and Semse Aware.

## Build

What the repository contains: source code only. Binaries, the Muse SDK, the 3D model and personal recordings are never committed. You generate or add them locally, once.

You need a Mac with Xcode 26 or later, plus:

- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- [Blender](https://www.blender.org/) 4.x, to render the brain image (step 2).
- The **Muse SDK** from Interaxon, version 8.0.9 or later. Download it yourself with your Interaxon developer account. Its licence forbids redistribution, so it is not in this repo.

Steps, from the repository root:

1. **Muse SDK.** Unzip the SDK download into a folder outside the repo, for example `~/Downloads/Muse SDK 8.0.9`. That folder must contain `libmuse_ios_*.tar.gz` and `libmuse_macos_*.tar.gz`. Then run:

   ```sh
   tools/setup_muse_sdk.sh "$HOME/Downloads/Muse SDK 8.0.9"
   ```

   This writes `Vendor/Muse.xcframework`, which is git-ignored. Do not copy the SDK into the repo by hand.

2. **Brain image.** Download “Brain Areas” by Versal from Sketchfab (CC BY 4.0, link under Credits). Save it as `tools/brain-source.usdz`, then bake it:

   ```sh
   /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/bake_brain.py
   ```

   This writes `App/Assets.xcassets/BrainTop.imageset/brain-top.png`.

3. **Icons and logo.** Generate them from the baked brain image:

   ```sh
   swift tools/make_icon.swift
   ```

4. **Project.** Generate the Xcode project (git-ignored). Run this again after editing `project.yml`:

   ```sh
   xcodegen
   open Brainwave.xcodeproj
   ```

   Set your own signing team and bundle identifier in `project.yml` (`DEVELOPMENT_TEAM`, `PRODUCT_BUNDLE_IDENTIFIER`) before you build for a device.

5. **Run** on a Mac, or on an iPhone or iPad with a Muse. The Muse SDK has no arm64 simulator slice, so the iOS Simulator on Apple Silicon cannot link it. Build for a connected device instead, for example `xcodebuild -scheme Brainwave -destination 'platform=iOS,id=<device id>' -allowProvisioningUpdates build`.

Tests that need neither the SDK nor Blender:

```sh
cd Packages/BrainwaveKit && swift test
```

Not in the repository, by design: the Muse SDK, the 3D model, generated meshes and images, EEG recordings, and signing keys.

Launch arguments (for testing): `-demo YES` starts the demo, `-tab N` picks the tab (0 Brain, 1 Mind, 2 Compare, 3 Captures, 4 Signals, 5 Settings, 6 Advanced on iPhone), `-advanced YES` turns on advanced view, `-appearance dark|light|system` and `-language <code>` set the look and language for a test. Do not leave `-tab` set when you test tab switching: a launch argument overrides the value the app saves. `-lastHeadband <name>` connects to that headband when it's seen. The app reconnects to the last headband by itself.

Similar and Muse-compatible apps are listed in [docs/SIMILAR_APPS.md](docs/SIMILAR_APPS.md).

## Android

The Android app is in [`android/`](android/README.md). It has the same screens as the iPhone app (Mind, Compare, Captures, Settings, Advanced and Connect), with a Calm session and the demo headband.

Build steps, with the Muse Android SDK kept out of the repo:

1. Download the Muse Android SDK from the developer page above, with your own Interaxon account.
2. Copy `libmuse_android.jar` into `android/app/libs/` and the native `libmuse_android.so` files into `android/app/src/main/jniLibs/`. Both folders are git-ignored.
3. In `android/`, run `./gradlew :app:installDebug` with a phone connected over USB or Wi-Fi debugging, or open the folder in Android Studio.

Without the SDK the app still builds only if those files are present. Do not commit them.

## Layout

| Path | What |
|---|---|
| `App/` | SwiftUI app (synchronized folder: new files are picked up without regenerating). `Localizable.xcstrings` holds the translations. |
| `Packages/BrainwaveKit/` | Pure-Swift core with no SDK dependency: electrode geometry, brain regions, baseline z-scores, focus, topomap rendering, demo headband, comparisons and captures. Its own `Localizable.xcstrings` holds the translated labels. `swift test` runs its tests. |
| `Config/` | Bridging header for the SDK, macOS entitlements |
| `android/` | Android app in Kotlin with Jetpack Compose (min SDK 26). Its own README covers the Muse Android SDK and the build. |
| `tools/bake_brain.py` | Blender script: renders the brain's top view for the 2D map from `tools/brain-source.usdz` |
| `tools/make_icon.swift` | Renders the app icon from that top view |

## How the maps work

Muse has four scalp electrodes (TP9, AF7, AF8, TP10) plus a reference at Fpz. For each electrode and band, libmuse reports absolute band power. The app compares every reading with a running baseline of the same person (`Baseline`, about a minute of memory) and shows the z-score: red is more than usual, blue is less. Electrodes not touching the skin are left out. Between electrodes the map is interpolated, and colour fades with distance from the nearest sensor, so areas Muse can't see (central, parietal, occipital) stay neutral instead of showing guesses.

The 3D mesh's texture coordinates use the same top-down projection as the 2D map, so both views share one rendered field.

This is a consumer neurofeedback visualisation, not a medical device.

## Credits

Created by **Vahid Ghafarpour**, **Smartoire** and **BC+AI Lifescience**.

- 3D brain: [“Brain Areas”](https://sketchfab.com/3d-models/brain-areas-d64608a3978b47d8a39c5a15795ca8c4) by [Versal](https://sketchfab.com/versal), licensed [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/). Decimated and re-projected for this app (`tools/bake_brain.py`).
- Muse SDK © Interaxon Inc., proprietary and not included. Shipping an app built on it needs Interaxon's approval under the SDK licence.
- Engagement index: Pope, Bogart & Bartolome (1995), *Biological Psychology* 40, 187–195.

## License

Code: [MIT](LICENSE). The 3D model keeps its CC BY 4.0 licence; the Muse SDK keeps Interaxon's.
