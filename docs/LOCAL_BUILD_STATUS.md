# Netbound Local Build Status

Final release-candidate validation was run on July 14, 2026.

## Host

- macOS `26.5.2` build `25F84`
- Apple Silicon `arm64`
- Godot `/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot`
- Godot `4.7.stable.official.5b4e0cb0f`

Matching export templates are installed under `/Users/ryland/Library/Application Support/Godot/export_templates/4.7.stable`, including `android_debug.apk`, `android_release.apk`, `android_source.zip`, and `ios.zip`. Templates and exported binaries are local only.

## Android toolchain

- SDK: `/Users/ryland/Library/Android/sdk`
- Platform tools: installed, including `adb`
- Build tools: `36.0.0` and `36.1.0`
- Platform/target: Android 36
- Godot JDK: OpenJDK 17 at `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- Debug keystore: `/Users/ryland/Library/Application Support/Godot/keystores/debug.keystore`
- Debug certificate SHA-256: `5cfc82efe8ebc6c48e703a9a426961834e720eef408e3ac0e925b892f63a3a90`

The AAB build template is installed only in a temporary project copy. `game/android` is ignored and is not committed.

## Final Android artifacts

Temporary output directory: `/tmp/netbound-final-rc-exports.UlHG8p`

| Artifact | Result | Size | SHA-256 |
| --- | --- | --- | --- |
| `netbound-debug.apk` | exported and verified | 27 MB | `18db3c1bf5f95253dd4a8766aa198dbde028ce3dc02ca0bab85f4f0a5707de7d` |
| `netbound-debug.aab` | exported and Bundletool-validated | 27 MB | `068d420a0fdf6c95b4ee6275e66531a174b78eeac25b9585bc691e22c50186ff` |
| `netbound-debug-signed.aab` | debug-signed copy verified by `jarsigner` | 27 MB | `849ca5697e0e2361a91f0b0cded10a8e70b78ac92b01a1ba9bc2fb0288d21c5e` |

Shared metadata:

- package `com.netbound.game`
- version name `0.9.0`
- version code `9`
- target SDK `36`
- native ABI `arm64-v8a` only
- permission `android.permission.VIBRATE`
- Internet permission absent

The prebuilt APK declares minimum SDK 24. The Gradle/AAB distribution path declares minimum SDK 29. The APK debug certificate verifies with APK Signature Scheme v2/v3. Bundletool 1.18.3 validates the AAB and generated a universal APK whose debug signature verifies with v3.

Godot's Gradle task reports `perform_signing=true` but its debug AAB output is JAR-unsigned. The separately signed copy uses the local self-signed debug certificate. A real release/upload key remains required.

Exact archive inspection confirms that final APK/AAB artifacts do not contain regression scripts, debug levels, the architecture test, or the legacy prototype scene.

`aapt2` emits a non-fatal missing `themed_icon.xml` resource-table warning for the prebuilt APK. The actual adaptive launcher icon referenced by the manifest resolves, and the Gradle/AAB bundle contains the themed icon resource.

## Xcode and iOS

- Xcode: `/Applications/Xcode.app`
- Selected developer directory: `/Applications/Xcode.app/Contents/Developer`
- Xcode version: `26.6` build `17F113`
- First-launch status: complete
- iOS/iOS Simulator SDK and runtime: `26.5`
- Available simulator devices: iPhone 17 family, iPhone Air, and current iPads
- Code-signing identities: none
- Preset bundle ID: `com.netbound.game`
- Preset minimum iOS: `16.0`

The iOS Debug export reaches Godot preset validation and stops at `App Store Team ID not specified.` No project is generated because the Team ID field is intentionally empty and no signing identity/provisioning profile exists.

This does not require paid membership for initial local setup. The user can sign into Xcode and use a valid Personal Team for a connected-device build. TestFlight/App Store distribution requires the appropriate Apple Developer Program membership and production signing assets.

## Key commands

```sh
GODOT=/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot

$GODOT --headless --path game --editor --quit
$GODOT --headless --path game --quit-after 30
$GODOT --headless --path game --export-debug "Android Debug" /tmp/netbound-final-rc-exports.UlHG8p/netbound-debug.apk

# Run in a temporary project copy so game/android is not added to the repository.
$GODOT --headless --path /tmp/netbound-android-project.DkAipz/game \
  --install-android-build-template \
  --export-debug "Android Debug AAB" \
  /tmp/netbound-final-rc-exports.UlHG8p/netbound-debug.aab

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  $GODOT --headless --path game --export-debug "iOS Debug" \
  /tmp/netbound-final-rc-exports.UlHG8p/ios/netbound-debug.zip
```

The template-install flag must be paired with an export operation. Used alone, it starts the editor and waits rather than performing a one-shot CLI install.

## Verification outcome

- Headless import and configured startup: passed.
- Parser sweep: 52/52.
- All production level startups: 10/10.
- Regression scripts: 21/21.
- Android debug APK and AAB export: passed.
- Android package, SDK, ABI, permissions, archive contents, and debug signatures: validated.
- iOS toolchain: installed and healthy.
- iOS export: signing-blocked on the deliberately absent Team ID.
- Android/iOS physical-device run: not performed.

See `docs/FINAL_RC_AUDIT.md` for the complete result and remaining device checklist.
