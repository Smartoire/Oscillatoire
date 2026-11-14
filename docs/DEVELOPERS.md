# Developer guide

For people who want to build, change or extend Brainwave. For what the app does for users, see the
[README](../README.md). For file formats, see [CAPTURE_FORMAT.md](CAPTURE_FORMAT.md).

## 1. The Muse SDK

Brainwave talks to a Muse headband through Interaxon's Muse SDK. **This project does not distribute
the SDK.** It isn't in the repository or its history, and you must not add it to a commit.

- **Get access:** request the SDK at https://choosemuse.com/pages/developers. Access is for testing,
  prototyping and personal use. Read Interaxon's terms before using it in anything beyond that.
- **Place it on your machine:** unzip the SDK into a folder outside the repo, then run
  `tools/setup_muse_sdk.sh "<that folder>"`. The script writes `Vendor/Muse.xcframework`, which is
  git-ignored.
- **Check it's not tracked:** `git status` should never show `Vendor/`, `Muse SDK*` or any `.framework`
  or `.xcframework`. The `.gitignore` covers them, but check before you commit.
- **Use it only through the bridging header:** `Config/Brainwave-Bridging-Header.h` imports `<Muse.h>`.
  Don't import SDK types anywhere else in the kit. The kit (`Packages/BrainwaveKit`) has no SDK dependency.

### Which SDK features Brainwave uses

| SDK call | Used for |
|---|---|
| `IXNMuseManager` / `IXNMuseManagerIos` / `IXNMuseManagerMac` | Scanning for headbands, `getMuses()`, `startListening()`. |
| `IXNMuse` `register`, `runAsynchronously`, `setPreset`, `disconnect` | Connecting, streaming and choosing the preset. Athena uses `preset1021`; other models use `preset21`. |
| Data packets: `.eeg`, `.hsiPrecision`, `.battery`, `.accelerometer`, `.deltaAbsolute` … `.gammaAbsolute` | Raw EEG per sensor, contact quality, battery, movement and band power. |
| `getEegChannelValue(IXNEeg)` | Per-sensor values for EEG-shaped packets. The SDK aborts if you ask for channels from any other packet type. |
| `getAccelerometerValue(X/Y/Z)` | Movement: the distance of the acceleration from 1 g. |

Packets arrive on the SDK's thread. `MuseListener` (App/MuseListener.swift) converts them to plain values
and hands them to `Session` on the main actor. Keep that boundary: no SDK types past `MuseListener`.

### Muse S Athena

Athena has its own preset family. The app picks it when `getModel() == .ms03`. Athena also reports
optical and fNIRS signals, which Brainwave doesn't use yet.

## 2. Code structure

| Path | What it does |
|---|---|
| `App/` | SwiftUI app: screens, `Session` (state and the 10 Hz / 3 Hz display tick), `MuseListener` (SDK bridge), `CaptureStore` (saved captures), `CalmSoundscape` (generated audio: drone, waves, single tone), `StartCheckView` (the Before you start check), `AppSettings` (appearance, language, dynamic type), `SettingsTab` (Settings, and the iPhone Advanced tab), `Localizable.xcstrings` (app translations). |
| `Packages/BrainwaveKit/` | Pure Swift, no SDK: electrode geometry, bands, metrics, baselines, the topomap renderer, regions, comparisons, captures and CSV/JSON export, the synthetic headband for the demo, and `AppLocale` (the language the package's text uses). Its `Localizable.xcstrings` holds the translated labels. |
| `Packages/BrainwaveKit/Tests/` | Unit tests. Run with `swift test` in that folder. |
| `tools/make_icon.swift` | Renders the app icon and the in-app logo from the brain image. |
| `tools/bake_brain.py` | Blender script that renders the top-view brain image. Needs a model you download yourself. |
| `project.yml` | XcodeGen project spec. Run `xcodegen` after editing it. |

### Data flow

1. The SDK delivers EEG, band power, contact and movement packets.
2. `MuseListener` converts them to values and calls `Session`.
3. `Session` keeps buffers at full rate, and publishes to the UI at 10 Hz (band power) and about 3 Hz
   (maps and movement). It also computes the scores once a second, and appends a capture sample and
   an activity frame once a second.
4. Views read published values. Maps show `Session.visibleActivation`: the overall activity, or the
   chosen band in advanced view, at sensors that touch the skin.

### Localisation

- All user-facing text is a string key in `App/Localizable.xcstrings` (the app) or `Packages/BrainwaveKit/Sources/BrainwaveKit/Localizable.xcstrings` (the kit). Both have the same ten languages: `fa, fr, nl, ar, zh-Hans, hi, es, ru, de, ja`, plus English.
- Use `String(localized: LocalizedStringResource("…", locale: AppLocale.current))` for text built in code, so the in-app language applies. A plain `Text("…")` follows the environment locale, which the app sets from Settings.
- Sentences with numbers or names use `%@` or `%lld` placeholders. The translation must keep the same placeholders in the same meaning.
- The window is rebuilt when the language changes (`.id(language)` in `AppLook`), because text built in code is read once when a view is drawn.
- Keep the names that must stay technical in English: band names, electrode names, the CSV column names, the Muse model names and "Brainwave".

### Demo mode

`-demo YES` as a launch argument starts `DemoHeadband`, a simulated headband. Use it for screenshots and
UI work without hardware. It uses the same code paths as a real headband, except the SDK.

## 3. Definitions

### Bands

| Band | Frequency | Typical meaning (plain, not diagnostic) |
|---|---|---|
| Delta | 1–4 Hz | Deep sleep, drowsiness |
| Theta | 4–8 Hz | Daydreaming, memory |
| Alpha | 7.5–13 Hz | Relaxed, eyes closed |
| Beta | 13–30 Hz | Focus, active thinking |
| Gamma | 30–44 Hz | Intense processing |

These come from the SDK's absolute band power, reported as log10 µV².

### Activation

The z-score of a band's power at one sensor against that person's own running baseline (about one
minute of memory, after a 50-reading warm-up). `+1` means one standard deviation above their usual.
Brainwave clamps it to ±3 when it draws it.

### Overall activity

The average of activation over the five bands at each sensor. This is what the everyday maps show.

### Scores (the everyday "states")

Each score is a ratio of band powers, turned into a z-score against your baseline, then mapped to 0–100
with `100 / (1 + e^(−1.2 z))`. So 50 is your usual level.

| Score | Formula | Sensors | High / low words |
|---|---|---|---|
| Focus | β ÷ (α + θ), in log terms | AF7, AF8 (forehead) | Focused / Distracted |
| Calm | α ÷ β | all good sensors | Calm / Stressed |
| Sleepiness | θ ÷ α | all good sensors | Sleepy / Alert |

**Calm and Stressed are one scale.** The calm score is high when alpha dominates and falls when beta
dominates. "Stressed" is the low end of that scale, not a separate measurement. Muse doesn't measure
stress on its own.

A score at or above 65 counts as "in the state". Between 35 and 65 is "Steady". At or below 35 is the low word.

### Contact quality

From the SDK's horseshoe indicator (HSI precision): `1` → good, `2` → ok, `4` or more → bad. Bad sensors
are left out of maps, scores and captures' activity.

### Movement

The distance of the accelerometer's magnitude from gravity (1 g), in g. Above `Capture.movementLimit`
(0.15 g) the app shows "Hold still", because blinks, head turns and walking distort the readings.

### Regions

Brainwave uses four regions. A point belongs to the side it sits on (x below 0 is left) and to frontal
(y at or above 0, towards the nose) or temporal (below it, towards the ears).

| Region | Centre (x, y) | Nearest sensor |
|---|---|---|
| Left frontal | (−0.4, 0.5) | AF7 |
| Right frontal | (0.4, 0.5) | AF8 |
| Left temporal | (−0.7, −0.4) | TP9 |
| Right temporal | (0.7, −0.4) | TP10 |

Comparisons group regions into areas: *left side* (left frontal and left temporal), *right side*, *frontal*,
*temporal*, or one region on one side.

### Coverage

How much to trust a point on the map, from its distance to the nearest sensor: measured by a sensor, estimated
from nearby sensors, or not covered by the sensors (rough estimate).

## 4. Sensors and positions

Muse 2, Muse S and Athena have four EEG sensors and one reference. They use the standard 10-20 positions.

| SDK channel | Sensor | Position (10-20) | Side | Lobe | Map position (x, y) |
|---|---|---|---|---|---|
| EEG1 | TP9 | Left mastoid area, behind the ear | Left | Temporal | (−1.14, −0.37) |
| EEG2 | AF7 | Left forehead | Left | Frontal | (−0.59, 0.81) |
| EEG3 | AF8 | Right forehead | Right | Frontal | (0.59, 0.81) |
| EEG4 | TP10 | Right mastoid area, behind the ear | Right | Temporal | (1.14, −0.37) |
| — | Fpz | Forehead midline (reference) | Midline | Frontal | (0, 1) |

**Map position:** x is to the subject's right, y is towards the nose. The head's edge is at radius 1.
The coordinates use an azimuthal-equidistant projection of the 10-20 angles (polar and azimuth from the
top of the head). The sensors' angles are: TP9 (108°, −108°), AF7 (90°, −36°), AF8 (90°, 36°), TP10 (108°, 108°).
Those values live in `Electrode.swift`, so use them rather than these rounded numbers if you change anything.

The reference (Fpz) is not measured. The SDK uses it internally.

Sensors that aren't touching the skin are reported with `bad` contact and excluded from the maps.

## 5. Adding things

- **A new screen:** add a view under `App/`, and a tab in `RootView` (`App/BrainwaveApp.swift`). Tab values are
  listed in `visibleTabs` and `content(for:)` in that file. The menu bar opens tabs by number. On iPhone the tab bar
  holds five tabs, so Brain and Signals share one Advanced tab (value 6) and any new tab needs the same care.
- **A new derived value:** put the maths in `BrainwaveKit` with a test. Only the SDK bridge and `Session` know about
  the headband.
- **A new export column:** change `Capture.csv()` and `Capture`'s JSON together, then update
  [CAPTURE_FORMAT.md](CAPTURE_FORMAT.md) and the test that counts columns.
- **Wording:** user-facing text is plain language. Don't put medical claims in it. Keep the not-medical,
  not-for-research note in the About screen and the README.
- **Text size:** the app sets Dynamic Type to xLarge in `AppLook`. Keep labels short enough to wrap or shrink, and
  test on a phone-width screen.

## 6. Checks before you commit

- `cd Packages/BrainwaveKit && swift test` passes.
- `xcodebuild -scheme Brainwave -destination 'platform=macOS' build` passes (run `xcodegen` first if you changed `project.yml`).
- `git status` shows no `Vendor/`, SDK, model, image, recording or signing file.
- Nothing you add mentions Muse trademarks in product names, or makes performance or medical claims.

## 7. Android app

Folder: `android/`. Kotlin, Jetpack Compose, Material 3, min SDK 26. Files:

- `MainActivity.kt`: the app shell. Top bar (Record, Calm, Headband), the menu fan, the start screen, and page routing. The Connect page returns to the page the user came from.
- `muse/MuseConnection.kt`: scans for headbands, connects, and publishes readings. `startDemo()` runs the demo headband.
- `kit/`: pure Kotlin maths, the same definitions as `Packages/BrainwaveKit`.
- `ui/`: one file per screen, plus `Theme.kt` (cards, backdrop, gradient button, segmented control), `NavFan.kt` (menu), `Splash.kt` (start screen), `Gauge.kt`, `CalmSound.kt` (breath-timed scale).

The Muse Android SDK is a local, git-ignored dependency (`app/libs/` and `app/src/main/jniLibs/`). See `android/README.md` for how to add it.

Settings use `Prefs` (SharedPreferences), with the same keys as the iPhone where they match: `appearance`, `language`, `calmSound`, `calmVolume`, `calmPace`, `advanced`.

