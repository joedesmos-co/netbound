# Netbound Mobile Release Checklist

This checklist tracks what must be true before the vertical slice is mobile-ready. Phase 0 only audits current status.

## Current Phase 0 Status

- Godot 4.7 stable is available and verified.
- Project imports in headless mode.
- Configured main scene starts in headless mode.
- Mobile renderer is selected.
- Touch input is handled directly with `InputEventScreenTouch` and `InputEventScreenDrag`.
- No offline progression, menus, settings, cosmetics, export presets, or platform packaging exists yet.

## Project Settings

Before release-ready vertical slice:

- Confirm landscape orientation for iOS and Android.
- Confirm stretch mode and aspect behavior on phone and tablet ratios.
- Confirm safe-area handling for notches and home indicators.
- Confirm application pause, resume, and focus-loss behavior.
- Confirm audio focus behavior.
- Confirm mobile-compatible renderer and shaders.
- Confirm physics tick settings.
- Confirm export presets.
- Confirm icons and splash screens.
- Confirm no desktop-only assumptions in gameplay or UI.

Current gaps:

- Orientation is not configured in `project.godot`.
- Safe-area behavior is not implemented.
- Export presets are absent.
- Pause/focus handling is absent.

## Input And UX

Required:

- Touch targets should be large enough for phones.
- Swipe area should remain sufficient at narrow and wide aspect ratios.
- Ball selection radius should feel fair on touch screens.
- Mouse input should remain available for desktop testing.
- Back/Escape should have sensible behavior in menus.

Current gaps:

- UI uses fixed offsets and prototype labels.
- No menu navigation exists.
- No pause menu exists.
- No controller or keyboard navigation policy exists.

## Gameplay Readability

Required:

- Ground, obstacles, goal openings, and routes must read clearly on small screens.
- High lobs must remain visible or be quickly reacquired.
- Curve path should be understandable before and after launch.
- Moving hazards must reset deterministically.
- Effects must not obscure gameplay.

Current gaps:

- Camera is static.
- Current max lobs peak around `47` to `51` world units.
- Debug text clutters the normal play view.

## Performance

Audit and optimize:

- Physics body count.
- Collision shapes.
- Moving obstacle scripts.
- Per-frame allocations.
- Swipe sample arrays.
- Curve calculations.
- Particles.
- Transparent net materials.
- Draw calls.
- Console logging.

Current gaps:

- No mobile profiling has been done.
- Console logging is continuous during normal actions.
- Swipe samples are not currently bounded by an explicit maximum.

## Offline Requirements

Required:

- No network requirement.
- No accounts.
- No analytics.
- No ads.
- No purchases.
- Versioned local save.
- Corrupted-save fallback.
- Settings persistence.

Current gaps:

- No save system exists yet.
- No progression exists yet.
- No settings exist yet.

## Audio And Haptics

Required:

- Master volume.
- Music volume.
- Sound effects volume.
- Haptics toggle.
- Mobile-friendly feedback events.
- No uncontrolled audio overlap.

Current gaps:

- No audio system exists.
- No haptics abstraction exists.

## Final QA Matrix

Test these representative sizes before release-ready handoff:

- Narrow phone.
- Standard phone.
- Large phone.
- Tablet.
- Desktop development window.

Flows:

- Fresh launch.
- Continue game.
- Level select.
- All 10 levels.
- Retry.
- Reset Ball.
- Pause.
- Save and reload.
- Cosmetics.
- Settings.
- Final-shot goal.
- Final-shot miss.
- Side-net legal goal.
- Moving obstacle reset.
- Ground, driven, air, and lob shots.
- Strong and extreme curve.
- Focus loss and restore.
- Corrupted save fallback.

## Hardware Still Required

The current environment can run headless import, parser, startup, and scripted checks. Final confidence still requires physical iOS and Android testing for:

- Touch feel.
- Safe areas.
- Thermal/performance behavior.
- Audio focus.
- Haptics.
- App suspend/resume.
- Device-specific aspect ratios.
