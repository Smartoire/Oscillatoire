# Backlog

Prepared from the work so far. Priorities: **P0** blocks safe work or sharing, **P1** verify and
ship, **P2** improve, **P3** later or optional.

## Decisions needed from you

1. **Publishing and the Muse SDK.** The SDK licence covers testing, prototyping and personal use. Paid or
   revenue-linked use needs a commercial agreement, and "future monetisation" counts. You've said the app
   should not be commercial. Confirm whether a free, open-source app with no revenue may use the SDK, or
   whether you want Interaxon's written approval first. Until this is settled, do not submit to the App
   Store. Contact: SDKpartners@choosemuse.com.
2. **Muse features from the new page.** Brain Age, Smart Wakeup and sleep staging are out of scope. Alpha Peak
   (advanced view only) and a composite balance score are options. Confirm.
3. **Movement threshold.** 0.15 g is a guess. Confirm it on a real headband before we rely on it.

## P0: security and repository safety

- [ ] **Rotate the Apple signing certificates and passwords.** The two `.p12` secrets and their passwords were
  printed in this conversation. Revoke both certificates, create new ones under team `XZ8V34LM8C`, export
  each with a strong unique password, and overwrite the four Infisical secrets. Check the Infisical audit log.
- [ ] **Check the signing identity's team.** The Keychain certificate is under a personal team
  (`2EC43QXX7C`), while `project.yml` uses `XZ8V34LM8C`. Create the development certificate under the company team.
- [ ] **Confirm no SDK or binaries are in the repo or its history.** Done for `origin/main` (single code-only
  commit `f96438c`). Check again after each push. `git ls-files | grep -E "Vendor|\.framework|\.usdz|\.bin$|\.png$"` should be empty.
- [ ] **Push the local commits, after the decisions above.** Nine local commits are not pushed (from `9a7133a`
  to `a0e9642`). Each message carries the Haiku co-author line. Confirm before pushing: the repo is public.
- [ ] **Delete leftover local copies of removed material.** `App/Resources/brain.mesh`, `tools/brain-source.usdz`
  (if you no longer need the 3D model), and the scratch backups in `.../scratchpad`.

## P1: verify on the iPhone (the phone was last tested on an earlier build)

- [ ] **Start page.** Launch without demo mode: the app opens on the last tab (Mind by default; Brain only in advanced view), and Connect (top right) opens the sheet.
- [ ] **Demo capture end to end.** Start and stop capture, review on the timeline, scrub the slider, share CSV and JSON.
- [ ] **Real headband.** Connect a Muse 2 or S. Check contact, movement warning, and that scores settle after about a minute.
- [ ] **Calm session.** The breathing circle, the soundscape level, the calm-seconds count, and that audio stops on Done.
- [ ] **Compare.** Live mode and capture mode (the two lines and the gap chart), the three comparison kinds, and the within-side split.
- [ ] **Speed.** The app was slow with the 3D view. Confirm it's now responsive on the phone, and profile the Brain tab if not.
- [ ] **Audio session on iOS.** Check the calm sound plays with the ringer off, and doesn't stop other audio unexpectedly.

## P1: fixes found during the work

- [x] **Bake script still writes the 3D mesh.** `tools/bake_brain.py` still writes `App/Resources/brain.mesh`, and the
  README step 2 says so. Remove the mesh section from the script and update the README.
- [x] **Audio API deprecation.** Uses `connectNode` on macOS and iOS 27 and later. The older call remains for earlier systems, so the compiler still warns there. `CalmSoundscape` uses `AVAudioEngine.connect(_:to:format:)`, which is deprecated on
  macOS 27. Move to the current API.
- [x] **Privacy line in Info.** Say that captures and history stay on the device, as the README does.
- [ ] **Remove stale tests and docs references.** Check `docs/` for mentions of the 3D view, the band picker on everyday screens, and the removed sensor dots.
- [x] **Info credits.** The brain image is derived from the CC BY 4.0 Sketchfab model. Keep the credit, and reword
  "3D model" to match what's shipped.

## P2: product improvements

- [x] **Partner apps into the similar-apps doc.** Mind Monitor (CSV and Protocol Buffer export, iCloud, OSC), Myndlift
  (training with games, benchmarks), OptiBrain and OptiTrain (collections, compare, audio feedback), Semse Aware
  (scenes, Apple Health Mindful Minutes) are reviewed in the research but not yet in `docs/SIMILAR_APPS.md`.
- [x] **Fatigue trend in captures.** Show how the focus score changed over a session (from the Flow Tracking idea).
- [ ] **Calm streaks and goals.** Count calm sessions per week, with a short summary (Headspace and Muse ideas).
- [ ] **Apple Health Mindful Minutes.** Write completed calm sessions, as Semse Aware does. Needs the HealthKit entitlement.
- [x] **Compare: accessibility.** Give the charts VoiceOver summaries, not just the sentence.
- [x] **Session-level tests.** Recording rules moved to `CaptureRecorder` in the kit and tested (16 kit tests). The rest of `Session` still needs the SDK. `Session` (state, captures, history) has no tests. Test the logic that doesn't need the SDK.
- [ ] **Capture storage.** Each save rewrites the file and every list load reads all captures. Fine for now. Move
  to an index when there are many captures.
- [ ] **Signals tab in advanced view.** Check it stays responsive, since it publishes raw EEG at 30 Hz.

## P3: later or optional

- [ ] **Alpha Peak** in advanced view: the peak alpha frequency from the raw EEG spectrum. Needs an FFT and a stored raw buffer.
- [ ] **Balance score.** Our own overall score from focus, calm and sleepiness, shown with a clear note that it isn't a health measure.
- [x] **Remove dead kit code.** `Coverage` and the old region helpers have gone, but check `Topomap.extent` and the
  `BrainMesh`-era comments in the kit.
- [ ] **Localisation.** Plain-language strings are in code. Move them to a string catalogue.
- [ ] **Mac: menu bar polish.** Check the glyph still reads well with the four-region map.
- [ ] **Release process.** Versioning, release notes and a TestFlight build, once the licence decision is made.

## Latest round: what changed and what is still open

Done since the last status:

- Languages: eleven in Settings (English, Persian, French, Dutch, Arabic, Chinese, Hindi, Spanish, Russian, German, Japanese), with the app and kit translations in `Localizable.xcstrings`. Persian and Arabic are right to left. Changing the language rebuilds the window.
- Settings tab (replaces Info): appearance, language, calm session options (sound on or off, sound choice, level, breathing pace), menu bar, remembered headband and About. The About links open the authors' sites.
- Captures: a sheet after each recording with Save, Cancel and Download; delete from each row; import of a JSON file; one share button.
- Compare: four brain icons (with tooltips), windows of 1 min, 15 min, 1 h and all, live or a capture chosen from Captures; the chart sits at the top.
- Mind: scores drawn with the same smoothing as Compare; card titles on one line.
- Calm session: a new breathing guide, sound choices (drone, waves, single tone), and no connect message. On Android the sound is one soft scale on each breath in, and the same scale back on each breath out (see Android below).
- Before you start: a stacked checklist with the Start button in the top bar.
- Tabs: Mind, Compare, Captures, Settings, then Brain and Signals (advanced view). On iPhone these share one Advanced tab.
- iPhone: built, installed and launched on an iPhone 15 Pro Max over USB (the simulator cannot link the Muse SDK on Apple Silicon).

Still open:

- [ ] **Translation review.** The ten languages are machine-written. A native speaker should check each one, especially Arabic, Japanese and Chinese.
- [ ] **Every page in every language, on screen.** Only Brain, Mind and Settings were checked in a few languages. Check Compare, Captures, Signals, About, the calm session, the Connect sheet, the Before you start page, the capture sheet and the menu bar.
- [ ] **Window titles.** "Mind State" and "Settings" were still in English in one Japanese test. Check the titles in every language.
- [ ] **Text size and wrapping on iPhone.** Check the Mind cards, Settings, the Before you start page and the axis labels at the default and xLarge sizes.
- [ ] **iPad layout.** Not checked. The app targets iPad (`TARGETED_DEVICE_FAMILY` includes 2), so the tabs, the Compare tiles and the graphs need a look on a large screen.
- [ ] **Advanced tab on iPhone.** Check Brain and Signals switch inside the Advanced tab, and that the bar holds five tabs.
- [ ] **Calm session with a real headband and sound.** Check the breathing guide, each sound choice and the level. The calm session has no graph; decide whether it should.
- [ ] **Real headband on iPhone.** Connect a Muse, check the Connect sheet finds it, the Before you start checks pass, and the Mind scores settle.
- [ ] **Double back arrow on Settings.** Reported on iPhone. Not yet confirmed as fixed.

## Status after this round

- Done: bake script no longer writes the mesh; privacy line; model credit reworded; partner apps added to the
  similar-apps doc; focus and calm change over a capture; Compare chart labels; leftover 3D references removed.
- Not done, and why: rotating the signing keys and the Apple team change (need your Apple and Infisical access);
  checking the phone (needs it unlocked and the build installed); App Store submission (blocked until the keys are
  rotated and the licence question is answered, and the app's company credit may count as commercial); session tests
  (the `Session` class depends on the SDK, so it needs a test seam first); the audio deprecation (I don't have a verified
  replacement API); calm streaks, Apple Health, Alpha Peak and the balance score (features that need decisions).
- Added: docs/EVIDENCE.md, a summary of what the research supports and how the app should word its scores.

## Done in this work (for reference)

- Captures with timeline review, CSV and JSON export, and a start page that opens to the brain map.
- Plain-language everyday view, with an Advanced switch for bands, sensors and formulas.
- Four regions, a 2D map without sensor dots, and Compare (left/right, front/temporal, within a side), live or over a capture.
- Calm session: breathing circle, a generated soundscape, and a calm-seconds count. Android has these; the iPhone sound choices are still the older set.
- Docs: SDK workflow and definitions (`docs/DEVELOPERS.md`), export format (`docs/CAPTURE_FORMAT.md`), similar apps
  (`docs/SIMILAR_APPS.md`), and the scope, not-medical and SDK-not-distributed notes in the README.

## Android

Status, from the work on the Android app (`android/`). Verified on a Pixel 7 Pro over USB and Wi-Fi debugging.

Done:

- Screens: Mind, Compare, Captures, Settings, Advanced (Brain and Signals), Connect and the Calm session, in the same style (rounded cards, gradient buttons, backdrop).
- Navigation: a menu button that opens the screens in an arc. Press, slide to a screen, lift to go there. The button sits at the bottom centre in portrait and at the middle of the right edge in landscape.
- Top bar: Record, Calm and Headband, each with a label. The headband icon turns green when connected.
- Calm session: a lotus that opens on each breath in and closes on each breath out, with IN or OUT on top. A timer, and a bar that splits the time into calm, steady and stressed. The bar is grey and says "Collecting data" until scores arrive. The sound is one soft scale per breath, timed to the breathing pace.
- Connect: searches for headbands over Bluetooth. The demo headband is in the list. When connected, a red stop icon disconnects.
- Before you start: a head with the headband across it, and a dot on each sensor coloured by contact.
- Settings: sliders for sound level and breathing pace, cards for Soundscape and Advanced, a language dialog, Muse SDK logos and About.
- Landscape: the Calm page is split into two columns and checked on the device. The Mind and Compare splits are built but not yet checked on the device.
- Rotation no longer replays the start screen.

Open:

- Verify the Compare and Mind landscape layouts and the menu button position on the device.
- Verify the new Settings page and the "Before you start" head drawing on the device.
- Language choice does not change the text yet. The Android app has no translations.
- Captures on Android shows the list and the empty message only. Recording and import are not on that page.
- Calm soundscape: check on the device with a real headband that the scale follows the breath.
- Muse SDK on Android is local and git-ignored. See `android/README.md`.

