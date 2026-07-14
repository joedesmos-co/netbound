# Netbound Local Build Status

Phase 9.5 local build validation was run on July 14, 2026.

## Host

- macOS: `26.5.2` build `25F84`
- Architecture: `arm64`
- Godot: `/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot`
- Godot version: `4.7.stable.official.5b4e0cb0f`

## Godot Export Templates

Installed matching Godot 4.7 stable templates under:

`/Users/ryland/Library/Application Support/Godot/export_templates/4.7.stable`

Installed files:

- `android_debug.apk`
- `android_release.apk`
- `android_source.zip`
- `ios.zip`
- `version.txt` containing `4.7.stable`

These files are local Godot templates and are not committed to the repository.

## Android Toolchain

Installed/configured locally:

- Android SDK: `/Users/ryland/Library/Android/sdk`
- Android command-line tools: `21.0`
- Platform tools / adb: `37.0.0`
- Build tools / apksigner: `36.0.0`
- Android platform: `android-36`
- JDK for Godot Android exports: `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- Java version: `17.0.19`
- Debug keystore: `/Users/ryland/Library/Application Support/Godot/keystores/debug.keystore`

JDK 25 is also installed on this Mac, but Android Gradle export failed under Java 25 with `Unsupported class file major version 69`. Godot's local editor setting now points Android exports at JDK 17.

Debug keystore certificate SHA-256:

`5cfc82efe8ebc6c48e703a9a426961834e720eef408e3ac0e925b892f63a3a90`

## Android Artifacts

Artifacts were generated under `/tmp/netbound-phase95/exports/android` and are intentionally not committed.

- Debug APK: `/tmp/netbound-phase95/exports/android/netbound-debug.apk`
- Debug APK size: `28M`
- Debug AAB: `/tmp/netbound-phase95/exports/android/netbound-debug.aab`
- Debug AAB size: `27M`
- Debug-signed AAB copy: `/tmp/netbound-phase95/exports/android/netbound-debug-signed.aab`
- Debug-signed AAB size: `28M`

APK metadata:

- Package ID: `com.netbound.game`
- Version code: `9`
- Version name: `0.9.0`
- Compile SDK: `36`
- Target SDK: `36`
- ABI: `arm64-v8a`
- Permission: `android.permission.VIBRATE`
- Internet permission: absent
- Signing: debug keystore, APK Signature Scheme v2/v3 verified

`aapt2 dump badging` reports a non-fatal themed-icon warning from the Godot template. Store icon and splash polish remain later work.

The Godot AAB export produced an unsigned `.aab`; Phase 9.5 also created a separate debug-signed copy with `jarsigner`. Strict signature verification correctly reports that the debug certificate is self-signed.

No Android device or emulator was listed by `adb devices -l`, so install, launch, and runtime log smoke tests were not attempted.

## iOS Status

Installed/configured:

- Godot iOS template: `ios.zip` is present in the matching `4.7.stable` template directory.
- Current developer directory: `/Library/Developer/CommandLineTools`

Blocked:

- Full Xcode is not installed/selected.
- `xcodebuild -version` fails because the active developer directory is Command Line Tools.
- `xcrun simctl` is unavailable.
- `iOS Debug` export fails with `App Store Team ID not specified.`
- No Xcode project was generated.
- No iPhone or simulator run was attempted.

Possible without paid membership:

- Install/select full Xcode.
- Sign into Xcode with an Apple ID.
- Use a Personal Team for local device signing when a trusted iPhone is connected.
- Supply the valid local Team ID in the iOS export preset.

Still requires paid Apple Developer Program membership:

- TestFlight distribution.
- App Store distribution.
- Production provisioning/certificates suitable for public release.
- App Store Connect submission.

## Commands Run

Key commands:

```sh
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --version
sdkmanager --install "platform-tools" "build-tools;36.0.0" "platforms;android-36"
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --editor --quit
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 3
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --export-debug "Android Debug" /tmp/netbound-phase95/exports/android/netbound-debug.apk
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /tmp/netbound-phase95/project-copy-final/game --install-android-build-template --export-debug "Android Debug AAB" /tmp/netbound-phase95/exports/android/netbound-debug.aab
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --export-debug "iOS Debug" /tmp/netbound-phase95/exports/ios/netbound-debug
/Users/ryland/Library/Android/sdk/build-tools/36.0.0/apksigner verify --verbose --print-certs /tmp/netbound-phase95/exports/android/netbound-debug.apk
/opt/homebrew/opt/openjdk@17/bin/jarsigner -verify /tmp/netbound-phase95/exports/android/netbound-debug-signed.aab
/Users/ryland/Library/Android/sdk/platform-tools/adb devices -l
xcode-select -p
xcodebuild -version
xcrun simctl list devices
```

Regression commands:

```sh
for script in game/scripts/debug/*.gd; do
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script "res://scripts/debug/$(basename "$script")"
done

find game -name "*.gd" | while read -r path; do
  rel="${path#game/}"
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --check-only --script "res://$rel"
done

for level in game/levels/level_*.tscn; do
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --scene "res://levels/$(basename "$level")" --quit-after 1
done
```

## Verification Outcomes

- Headless editor import: passed.
- Configured app startup: passed.
- Per-GDScript parser sweep: passed.
- All Phase 1-9 debug regression scripts: passed with clean logs after fixing an optional legacy prototype UI lookup.
- All 10 production levels start headlessly.
- Android Debug APK export: passed.
- Android Debug AAB export: passed from a temporary copy with the project Android build template installed during export.
- iOS Debug export: blocked on missing Apple Team ID.
- Android physical-device run: not attempted because no device/emulator is connected.
- iOS simulator/device run: not attempted because full Xcode/signing are unavailable.
