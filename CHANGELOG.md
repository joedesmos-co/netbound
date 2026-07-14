# Changelog

## 0.9.0 RC - 2026-07-14

### Fixed

- Recover a valid backup save when the primary save is missing or malformed, then rewrite a normalized primary.
- Keep swipe history at the configured 48-sample limit after the release endpoint is appended.
- Show `Play` rather than `Continue` on a fresh save and use state-specific main-menu action text.
- Align the iOS deployment target with Godot 4.7 Mobile/Metal support at iOS 16.0.
- Exclude regression scripts, debug levels, and legacy prototype resources from every mobile export preset.

### Polished

- Center main menu and modal actions at a consistent touch-friendly width.
- Replace the stale phase label with the configured `v0.9.0 RC` version.
- Remove the empty legacy root scene and ignore local export artifacts.

### Validation

- Added an isolated end-to-end release-candidate flow regression.
- Passed import, configured startup, 52 GDScript parser checks, all ten level startups, and 21 regression scripts without unexpected errors, warnings, or leak reports.
- Re-exported and validated Android debug APK/AAB artifacts; iOS export remains correctly blocked until a real Apple Team ID and signing identity are supplied.

### Known external requirements

- Physical Android and iOS touch, safe-area, haptic, audio-focus, suspend/resume, performance, and thermal testing.
- Android release/upload keystore and Google Play account setup.
- Apple Team ID, signing identity, provisioning, and device or TestFlight setup.
