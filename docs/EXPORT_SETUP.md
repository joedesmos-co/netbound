# Netbound Export Setup

The current presets support local release-candidate builds. They do not start store submission, real monetization integration, analytics, cloud save, or production signing.

## Identifiers and versions

- Android package: `com.netbound.game`
- iOS bundle identifier: `com.netbound.game`
- Version name/short version: `0.9.0`
- Version code/build: `9`
- In-app candidate label: `v0.9.0 RC`

Review the identifiers and increment versions before public distribution.

## Presets

`game/export_presets.cfg` defines:

- `Android Debug`
- `Android Debug AAB`
- `Android Release`
- `iOS Debug`
- `iOS Release`

Debug presets use `mobile,netbound_development`; release presets use `mobile,netbound_release`.

Every preset excludes:

- `scripts/debug/*`
- `levels/debug/*`
- `scenes/prototype.tscn`
- `levels/definitions/level_architecture_test.tres`

This keeps automated harnesses and legacy prototypes out of mobile packages.

Local exports under `game/build`, `game/builds`, `game/android`, and common Android/iOS binary extensions are ignored. Do not commit generated packages.

## Android

Current intent:

- landscape immersive mode
- ARM64 only
- target SDK 36
- Gradle/AAB minimum SDK 29
- vibration permission enabled
- Internet permission disabled
- no real ad or purchase SDK

Required local settings:

- Android SDK at `/Users/ryland/Library/Android/sdk`
- OpenJDK 17 at `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- matching Godot 4.7 Android templates
- local debug keystore for debug validation

APK export:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless --path game \
  --export-debug "Android Debug" /tmp/netbound-debug.apk
```

AAB export requires the Gradle build template. To keep the repository clean, copy the project to `/tmp` and combine template installation with export:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless --path /tmp/netbound-project/game \
  --install-android-build-template \
  --export-debug "Android Debug AAB" /tmp/netbound-debug.aab
```

The raw Godot debug AAB is valid but locally observed as JAR-unsigned. A debug-only copy can be signed with the local debug keystore for validation. Public release requires a protected release/upload key and Google Play signing configuration; never commit a keystore or password.

Validate package ID, version, min/target SDK, ARM64 libraries, permissions, archive exclusions, and signatures after each export. Bundletool validation and universal APK generation are part of the final RC process.

Before Google Play work:

- confirm the final package ID and version code
- create/protect the upload key
- configure Play App Signing
- inspect icon/splash on hardware
- run the AAB through an internal-test track
- complete privacy/data-safety forms only after final SDK selection

## iOS

Current intent:

- landscape
- ARM64
- minimum iOS 16.0 for Godot 4.7 Mobile/Metal
- no camera, microphone, or photo-library access
- no real ad or purchase SDK

Local toolchain:

- Xcode `/Applications/Xcode.app`
- developer directory `/Applications/Xcode.app/Contents/Developer`
- Xcode 26.6
- iOS/iOS Simulator 26.5
- matching Godot 4.7 `ios.zip` template

Current blocker:

- no Apple Team ID
- no signing identity
- no provisioning profile

Godot stops before project generation with `App Store Team ID not specified.` Do not insert a placeholder Team ID.

Next local steps when the user is ready:

1. Sign into Xcode with the intended Apple ID.
2. Identify the real Personal Team or organization Team ID.
3. Add that Team ID locally to the iOS preset.
4. Export an iOS Xcode project/zip.
5. Open the project in Xcode and let automatic signing create a local profile.
6. Build to a connected trusted iPhone and run the physical checklist.

A free Personal Team can support local device testing subject to Apple's limitations. TestFlight/App Store distribution and durable production provisioning require the appropriate paid program membership.

## Validation status

Android APK/AAB local exports pass. Xcode and simulator tooling are installed and enumerate correctly. iOS export is honestly signing-blocked. Device validation and store-account work remain deferred; see `docs/LOCAL_BUILD_STATUS.md` and `docs/FINAL_RC_AUDIT.md`.
