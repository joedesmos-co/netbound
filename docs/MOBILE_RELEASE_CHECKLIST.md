# Netbound Mobile Release Checklist

This checklist tracks what must be true before the vertical slice is mobile-ready.

## Current Status Through Phase 5

- Godot 4.7 stable is available and verified.
- Project imports in headless mode.
- Configured main scene starts in headless mode.
- Mobile renderer is selected.
- Touch input is handled directly with `InputEventScreenTouch` and `InputEventScreenDrag`.
- Offline progression, star ratings, app shell menus, level select, pause, result overlays, and basic settings now exist.
- Cosmetics has a clean Phase 5 placeholder only; real cosmetic selection remains Phase 6.
- Export presets and platform packaging are not configured yet.

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
- Safe-area handling uses conservative margins in the Phase 5 UI, but physical notch/home-indicator validation is still required.
- Export presets are absent.
- App focus loss requests pause through the app shell, but physical mobile suspend/resume still requires testing.

## Input And UX

Required:

- Touch targets should be large enough for phones.
- Swipe area should remain sufficient at narrow and wide aspect ratios.
- Ball selection radius should feel fair on touch screens.
- Mouse input should remain available for desktop testing.
- Back/Escape should have sensible behavior in menus.

Current gaps:

- Controller navigation is only basic Godot focus support.
- Physical touch testing is still required for Level Select scrolling and gameplay finger occlusion.

## Gameplay Readability

Required:

- Ground, obstacles, goal openings, and routes must read clearly on small screens.
- High lobs must remain visible or be quickly reacquired.
- Curve path should be understandable before and after launch.
- Moving hazards must reset deterministically.
- Effects must not obscure gameplay.

Current gaps:

- Final Phase 7 art polish is still pending.
- Physical small-screen readability checks are still required.

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

- Cloud sync is intentionally absent.
- Physical persistence checks across app kill/relaunch remain required.

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
- Phase 5 settings persist volume and haptics values; Phase 7 will connect real feedback.

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
