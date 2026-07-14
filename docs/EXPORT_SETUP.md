# Netbound Export Setup

Phase 9 prepares export presets but does not perform store submission, real signing, SDK integration, analytics, cloud save, or app-store listing work.

## Package IDs

Placeholder identifiers:

- Android package: `com.netbound.game`
- iOS bundle identifier: `com.netbound.game`

These must be reviewed before production release.

## Presets

File: `game/export_presets.cfg`

Presets:

- `Android Debug`
- `Android Debug AAB`
- `Android Release`
- `iOS Debug`
- `iOS Release`

Feature tags:

- Debug presets: `mobile,netbound_development`
- Release presets: `mobile,netbound_release`

## Android Notes

Current Android preset intent:

- landscape/immersive orientation
- arm64 enabled
- no Internet permission
- vibration permission enabled for haptics
- no real ad or purchase SDK
- debug APK export uses Godot's local debug keystore
- debug AAB export uses a Gradle build template in a temporary project copy

Expected blockers before a real Android build:

- Release signing keystore must be created and configured.
- Final package ID, version code, icons, splash, and store metadata must be reviewed.
- Real ad, purchase, consent, analytics, and store SDKs are intentionally absent.

Phase 9.5 local Android status:

- Godot editor: `/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot`
- Godot version: `4.7.stable.official.5b4e0cb0f`
- Export templates: `/Users/ryland/Library/Application Support/Godot/export_templates/4.7.stable`
- Installed matching template files: `android_debug.apk`, `android_release.apk`, `android_source.zip`, `ios.zip`, `version.txt`
- Android SDK: `/Users/ryland/Library/Android/sdk`
- Command-line tools: `21.0`
- Platform tools: `37.0.0`
- Build tools: `36.0.0`
- Platform: `android-36`
- JDK used by Godot Android exports: `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home` (`17.0.19`)
- Local debug keystore: `/Users/ryland/Library/Application Support/Godot/keystores/debug.keystore`
- Debug APK export succeeded at `/tmp/netbound-phase95/exports/android/netbound-debug.apk` (`28M`).
- Debug AAB export succeeded from a temporary project copy at `/tmp/netbound-phase95/exports/android/netbound-debug.aab` (`27M`).
- A debug-signed AAB copy was created at `/tmp/netbound-phase95/exports/android/netbound-debug-signed.aab` (`28M`) using the local debug keystore.
- The debug AAB preset requires Gradle and a project Android build template. Phase 9.5 validates it with `--install-android-build-template` in `/tmp`; the generated `game/android` template is not committed.
- APK metadata: package `com.netbound.game`, version code `9`, version name `0.9.0`, target SDK `36`, permission `android.permission.VIBRATE`, no Internet permission, native ABI `arm64-v8a`.
- `aapt2 dump badging` reports a non-fatal Godot template themed-icon warning; icon/splash polish remains a later store-assets task.
- `adb devices -l` found no connected devices or emulators, so install/run smoke tests were not attempted.

## iOS Notes

Current iOS preset intent:

- landscape orientation
- arm64 enabled
- minimum iOS version `14.0` for the Metal renderer
- no camera/microphone/photo privacy strings because those APIs are unused
- no real ad or purchase SDK
- placeholder signing/team fields only

Expected blockers before a real iOS build:

- Apple Team ID, signing identity, and provisioning profiles must be configured.
- Final bundle ID, version, icons, launch screen, and store metadata must be reviewed.

Phase 9.5 local iOS status:

- The matching Godot `ios.zip` template is installed.
- `xcode-select -p` reports `/Library/Developer/CommandLineTools`.
- Full Xcode is not installed/selected; `xcodebuild -version` fails because Command Line Tools are active instead of Xcode.
- `xcrun simctl` is unavailable in this state.
- `iOS Debug` export now reaches preset validation and fails on `App Store Team ID not specified.`
- No Xcode project was generated because no Apple Team ID, signing identity, or provisioning profile is configured.
- A free Apple account in full Xcode may be enough for local personal-device signing after the user signs in and supplies a valid Team ID.
- Paid Apple Developer Program membership is still required for TestFlight/App Store distribution and durable production provisioning.

## Validation

Phase 9 validates that presets exist and contain the expected IDs, feature tags, and permissions. Phase 9.5 validates local Android debug exports and iOS preset blockers. Device runtime validation still requires connected/trusted hardware or a configured simulator.

Phase 9.5 verification commands and outcomes are recorded in `docs/LOCAL_BUILD_STATUS.md`.
