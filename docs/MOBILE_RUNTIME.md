# Netbound Mobile Runtime

Phase 9 adds `MobileRuntimeService` as a lightweight mobile hardening autoload.

## Autoload

- Name: `MobileRuntimeService`
- Script: `res://scripts/services/mobile_runtime_service.gd`

## Responsibilities

- Emits semantic app lifecycle signals:
  - `app_backgrounded(reason)`
  - `app_foregrounded(reason)`
  - `app_quit_requested(reason)`
- Calculates safe-area margins with a `28px` fallback.
- Normalizes and applies presentation-only quality tiers.
- Detects development/release mode from export feature tags.
- Flushes dirty save data and pauses/resumes audio on lifecycle changes.

## Lifecycle Contract

Background/focus loss:

1. `MobileRuntimeService` receives Godot focus/pause notification.
2. `SaveService.flush_if_dirty()` runs.
3. `AudioService.handle_app_backgrounded()` stops one-shots and pauses music.
4. `NetboundApp` clears incomplete aiming and opens Pause when gameplay is active.

Foreground/resume:

1. `AudioService.handle_app_foregrounded()` resumes the existing music player.
2. `NetboundApp` reapplies safe-area layout.
3. Active level HUD and app chrome are repositioned.

## Safe Areas

`NetboundApp` uses runtime safe-area margins for:

- Main Menu
- Level Select
- Cosmetics
- Store
- Settings
- Pause
- Results
- Gameplay Pause button
- Level HUD through `prototype_controller.gd.apply_safe_area_margins()`

## Touch Safeguards

Phase 9 input hardening:

- canceled `InputEventScreenTouch` clears active aim
- only the active touch index can update/release a swipe
- UI button regions reject swipe starts
- Pause/background clears incomplete aiming
- swipe samples are capped by `maximum_swipe_samples`

## Release Mode

Export feature tags:

- Development: `netbound_development`
- Release: `netbound_release`

Release mode disables simulated ad/purchase providers and hides developer debug controls. Real SDK integration remains a later phase.
