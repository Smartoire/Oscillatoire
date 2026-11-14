# Brainwave for Android

The Android version of Brainwave, written in Kotlin with Jetpack Compose. It mirrors the iPhone app's screens: Mind, Compare, Captures, Settings, Advanced (Brain and Signals), Connect, and the Calm session.

Requirements: Android 8.0 (API 26) or later, Android Studio or the Gradle wrapper in this folder, and a Muse headband or the built-in demo headband.

## The Muse Android SDK

Brainwave uses the Muse Android SDK (`libmuse_android`) from Interaxon. **This repository does not include the SDK, and it must never be committed.**

1. Request access and download the SDK from https://choosemuse.com/pages/developers, with your own developer account.
2. Copy `libmuse_android.jar` to `app/libs/`.
3. Copy the native libraries (`libmuse_android.so` for each ABI) to `app/src/main/jniLibs/<abi>/`.

Both `app/libs/` and `app/src/main/jniLibs/` are listed in `.gitignore`. Check before you commit with `git status`: no `.jar`, `.aar` or `.so` file from the SDK should appear.

## Build and run

```bash
cd android
./gradlew :app:installDebug
```

Connect the phone with USB, or pair it over Wi-Fi debugging, then run the command. Use **Try the demo headband** (or pick the Demo headband in the Connect list) to run without hardware.

## Where things are

| Path | What |
|---|---|
| `app/src/main/java/com/smartoire/brainwave/MainActivity.kt` | App shell: the menu, top bar, start screen and page routing |
| `app/src/main/java/com/smartoire/brainwave/muse/` | Muse connection and the demo headband |
| `app/src/main/java/com/smartoire/brainwave/kit/` | Maths and models: baselines, scores, captures, comparisons |
| `app/src/main/java/com/smartoire/brainwave/ui/` | Screens and shared style (`Theme.kt`, `Splash.kt`, `NavFan.kt`) |
| `app/src/main/res/` | Icons, the brain artwork, and the launcher icon |

## Licence

See the top-level README. The Muse SDK is under Interaxon's licence, not this project's.
