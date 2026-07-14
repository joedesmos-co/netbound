# Netbound Mobile Release Checklist

This checklist tracks what must be true before the vertical slice is mobile-ready.

## Current Status Through Phase 9

- Godot 4.7 stable is available and verified.
- Project imports in headless mode.
- Configured main scene starts in headless mode.
- Mobile renderer is selected.
- Touch input is handled directly with `InputEventScreenTouch` and `InputEventScreenDrag`.
- Offline progression, star ratings, app shell menus, level select, pause, result overlays, basic settings, and earnable cosmetics now exist.
- Cosmetics are offline-only, gameplay-earned, and persisted locally through `SaveService`.
- Cosmetic visuals are material overrides, bounded trail points, and transient goal effects; they do not alter physics or scoring.
- Original generated audio assets, runtime audio buses, bounded AudioService players, and HapticsService now exist.
- Reduced Motion and Camera Effects settings exist and persist.
- Gameplay aim preview, launch/impact/goal feedback, near-miss presentation, level visual polish, contact shadows, and UI motion now exist.
- Phase 7 presentation nodes are bounded, visual-only, and covered by headless regression checks.
- Phase 8 simulated monetization architecture now exists with rewarded continue, restrained interstitial policy, Remove Ads, Starter Pack, Store UI, local entitlements, and offline/unavailable-provider handling.
- Phase 9 mobile runtime now handles lifecycle, safe-area margins, dirty save flush, quality tiers, release/development feature tags, and audio pause/resume.
- Android and iOS export presets exist with placeholder package/bundle ID `com.netbound.game`.
- Phase 9.5 installed matching Godot 4.7 export templates locally.
- Phase 9.5 configured a local Android SDK/JDK toolchain and produced Android debug APK/AAB artifacts under `/tmp/netbound-phase95`.
- Landscape viewport defaults and Forward Mobile renderer settings are configured in `project.godot`.
- ETC2/ASTC texture compression import is enabled for Android export compatibility.
- Automated safe-area/responsive checks cover representative landscape phone/tablet shapes with simulated safe margins.
- No real ad SDK, purchase SDK, analytics SDK, online account, cloud save, or consent SDK is integrated.

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

- Physical notch/home-indicator validation is still required on real devices.
- App suspend/resume still requires physical iOS/Android testing.
- Android debug APK export now succeeds locally with debug signing.
- Android debug AAB export now succeeds locally from a temporary project copy with Godot's Android build template installed during export.
- Android AAB output still needs final store signing/review before public distribution.
- iOS export is still blocked locally by missing full Xcode selection and missing Apple Team ID/signing configuration.
- Export presets are not signed with production credentials.

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
- Physical touch testing is still required for Cosmetics, Store, and Settings scrolling/selection comfort.

## Gameplay Readability

Required:

- Ground, obstacles, goal openings, and routes must read clearly on small screens.
- High lobs must remain visible or be quickly reacquired.
- Curve path should be understandable before and after launch.
- Moving hazards must reset deterministically.
- Effects must not obscure gameplay.

Current gaps:

- Physical small-screen readability checks are still required.
- Cosmetic trails and goal effects require physical-device readability checks to confirm they do not hide tight gaps or goals.

## Performance

Audit and optimize:

- Physics body count.
- Collision shapes.
- Moving obstacle scripts.
- Per-frame allocations.
- Swipe sample arrays.
- Curve calculations.
- Particles.
- Cosmetic trail point count and goal effect node cleanup.
- Audio player pool counts and impact cooldowns.
- Transparent net materials.
- Draw calls.
- Console logging.

Current gaps:

- Swipe samples are now bounded by an explicit maximum.
- Desktop/headless budget checks cover audio pools, trail points, visual polish node counts, quality tiers, safe-area layout, and presentation cleanup.
- Device GPU/thermal checks remain open.

## Offline Requirements

Required:

- No network requirement.
- No accounts.
- No analytics.
- No real ads or purchase SDKs.
- Simulated ads/purchases are local and optional; all 10 levels remain playable offline without payment or ads.
- Versioned local save.
- Corrupted-save fallback.
- Settings persistence.
- Purchased/owned simulated entitlements remain usable offline.

Current gaps:

- Cloud sync is intentionally absent.
- Physical persistence checks across app kill/relaunch remain required.
- SaveService dirty flush is covered by scripted background/quit checks, but real mobile process-kill timing still requires device validation.
- No local Android or iOS runtime smoke test was completed in Phase 9.5 because no Android device/emulator was connected and iOS lacked full Xcode/signing.

## Monetization Readiness

Phase 8 is architecture-only for monetization providers.

Ready:

- Provider interfaces and simulated providers.
- Rewarded extra-shot continue guarded by request IDs and level instance IDs.
- One-star cap for ad-continued completions.
- Central interstitial policy, disabled by Remove Ads/Starter Pack.
- Local entitlements and restore simulation.
- Store UI with unavailable/offline handling.

Deferred:

- Real App Store / Google Play product setup.
- Real ad network SDK integration.
- Platform purchase receipt validation.
- Legal consent/privacy SDKs or dialogs.
- Analytics and attribution.
- Country/storefront localization.

## Audio And Haptics

Required:

- Master volume.
- Music volume.
- Sound effects volume.
- Haptics toggle.
- Mobile-friendly feedback events.
- No uncontrolled audio overlap.

Current gaps:

- Physical mobile audio focus and haptic feel still require device testing.

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
- Cosmetic unlocks, selection persistence, and selected visuals in gameplay.
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

## Local Build Status

Phase 9.5 local build status is documented in `docs/LOCAL_BUILD_STATUS.md`.

Current local capabilities:

- Export Android debug APK.
- Export Android debug AAB from a temporary project copy using `--install-android-build-template`.
- Inspect APK metadata and signing.
- Enumerate Android devices with `adb`.

Current local blockers:

- No connected Android device/emulator for install/run.
- No full Xcode installation/selection.
- No Apple Team ID, signing identity, or provisioning profile.
- No iOS simulator tooling through `xcrun simctl`.
