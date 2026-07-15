# Changelog

## Player Feel - 2026-07-15

### Changed

- Retire the rewarded extra-shot continuation and its one-star cap while preserving rewarded Net Token ads and version-2 save compatibility.
- Present shots used beside par in the gameplay HUD.
- Use distinct `Reset Ball`, `Restart Level`, `Try Again`, and `Play Again` language throughout the run loop.
- Replace the hot, overlapping success stings with a short goal chirp, a lighter delayed result flourish, and guarded cosmetic-unlock timing.
- Make the base goal confirmation success green, keep goal-frame materials white, and suppress the full-screen pulse under Reduced Motion.
- Classify curve from dominant path-side intent plus normalized deviation, making mild
  bends and short hooks responsive without changing the 78-degree runtime cap.

## Content Expansion - 2026-07-15

### Fixed

- Count swept entries through the front, left side, or right side of the shared arcade goal enclosure while rejecting rear and fully outside passes.
- Keep timed gates and moving obstacles continuous, deterministic, and exactly resettable.
- Remove redundant normal-player trajectory guides so aiming shows one live swipe line.
- Restore a friendly white-and-black soccer identity to the default gameplay and menu ball.

### Added

- Add ten authored levels, expanding the production route to Levels 01-20 and the maximum total to 60 stars.
- Add explicit side-entry challenges, moving-goal synchronization, deterministic rhythm hazards, and a new Level 20 finale.
- Add production-input completion routes and version-2 save migration coverage for the expanded registry.

### Polished

- Give all 18 ball cosmetics distinct panel or concept treatment while preserving the reference collision sphere.
- Enlarge and differentiate all eight bounded goal celebrations.
- Improve UI contrast, shorten player-facing copy, keep goal frames white, and brighten late-level environments.

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
