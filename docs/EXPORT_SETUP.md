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
- placeholder signing configuration only

Expected blockers before a real Android build:

- Godot Android export templates must be installed.
- Android SDK/JDK must be configured.
- Release signing keystore must be created and configured.
- Final package ID, version code, icons, splash, and store metadata must be reviewed.

## iOS Notes

Current iOS preset intent:

- landscape orientation
- arm64 enabled
- minimum iOS version `14.0` for the Metal renderer
- no camera/microphone/photo privacy strings because those APIs are unused
- no real ad or purchase SDK
- placeholder signing/team fields only

Expected blockers before a real iOS build:

- Xcode command line tools and iOS export templates must be installed.
- Apple Team ID, signing identity, and provisioning profiles must be configured.
- Final bundle ID, version, icons, launch screen, and store metadata must be reviewed.

## Validation

Phase 9 validates that presets exist and contain the expected IDs, feature tags, and permissions. Actual export attempts may fail in local development when platform templates, SDKs, JDK, Xcode, signing, or provisioning are absent; those failures should be reported honestly rather than treated as completed device builds.

Local Phase 9 validation found:

- Java is installed, but Godot editor Android SDK/JDK paths are not configured.
- `adb`, `sdkmanager`, and `apksigner` are not on `PATH`.
- Full Xcode is not selected; `xcodebuild` reports Command Line Tools only.
- Godot export templates for `4.7.stable` are missing from the user template directory.
- Android export reaches preset validation and fails on missing templates/SDK build-tools/platform-tools.
- iOS export reaches preset validation and fails on missing `ios.zip` template.
