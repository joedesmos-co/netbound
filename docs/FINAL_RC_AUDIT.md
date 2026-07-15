# Netbound Final Release-Candidate Audit

Date: July 14, 2026
Candidate: `0.9.0-rc`
Baseline: `3d39f96`
Godot: `4.7.stable.official.5b4e0cb0f`

## July 15 Content-Expansion Addendum

The July 14 audit below is retained as historical evidence for the original ten-level candidate. The current candidate expands the same architecture to 20 levels/60 stars and adds arcade side-enclosure scoring, continuous moving hazards, one-line aiming, a soccer-ball identity pass, improved cosmetic concepts/effects, and UI contrast/copy refinements.

Current behavior and evidence are documented in:

- `docs/CONTENT_EXPANSION.md`
- `docs/COSMETIC_VISUAL_AUDIT.md`
- the current matrix at the top of `docs/TEST_PLAN.md`

Save format remains version `2`; completed Level 10 progress unlocks Level 11 during normalization without changing wallet, cosmetic, entitlement, or reward-ledger state. Level 20 is the new finale. The original 30-star cosmetic milestones intentionally remain early/mid-route rewards.

Current expansion verification passed `68/68` parsers, `20/20` scene startups, and `27/27` retained regressions with no matched Godot warning/error/leak output. Android debug APK and isolated-template AAB exports also passed. Exact artifact hashes and commands are recorded in `docs/CONTENT_EXPANSION.md`.

## July 15 Player-Feel Addendum

The rewarded extra-shot continuation and its one-star cap were retired after direct play feedback showed that they competed with an immediate free restart without adding meaningful value. Failure now offers only `Try Again`; rewarded ads remain available for Net Tokens in the Store. The HUD reports shots used beside par, and historical version-2 data remains compatible.

## Recommendation

Ready for physical-device beta testing.

No known launch, parser, shooting, reset, goal-ordering, navigation, progression, persistence, or local export blocker remains. Public store release is not yet recommended because no physical mobile run was performed and real Apple/Google signing and store accounts are intentionally not configured.

## Scope

The audit covered the production app entry point, shooting and curve behavior, reset/retry/failure/goal state transitions, all ten levels, progression and star rules, save recovery, menus and result overlays, cosmetics, settings, simulated development monetization, lifecycle behavior, safe-area layouts, presentation/audio cleanup, quality tiers, Android exports, and the available iOS toolchain.

Normal developer save data was not mutated by the final integration test. All save/relaunch coverage used isolated `user://final_rc_flow_test.*` paths.

## Bugs found and fixed

| Severity | Issue | Root cause | Fix | Main files |
| --- | --- | --- | --- | --- |
| High | Recoverable progress could be lost when the primary save was missing or malformed. | `load_or_create()` recreated defaults without attempting the configured backup. | Read and normalize a valid backup first, preserve malformed primary data as corrupt, and rewrite the primary. | `game/scripts/services/save_service.gd`, Phase 4 regression |
| Medium | Swipe samples could exceed the declared mobile bound after release. | Drag sampling trimmed to 48, then the final release endpoint appended a 49th item. | Apply the same bounded trim after every append and keep at least two samples. | `game/scripts/prototype_controller.gd`, Phase 9 regression |
| Medium | Development harnesses and legacy prototypes were packaged in mobile exports. | All presets exported all resources without exclusions. | Exclude debug scripts/scenes and legacy prototype resources from all presets; delete an empty obsolete root scene. | `game/export_presets.cfg`, `game/main.tscn`, Phase 9 regression |
| Medium | iOS presets allowed an unsupported deployment floor. | Both presets declared iOS 14 while Godot 4.7 Mobile/Metal requires iOS 16. | Set both iOS presets to minimum iOS 16.0 and assert the value in Phase 9. | `game/export_presets.cfg`, Phase 9 regression |
| Low | A fresh save was presented as a resume state. | Every playable-level resolution forced the main action text to `Continue`. | Return explicit `Play`, `Continue`, `Replay`, or `Level Select` text from play resolution. | `game/scripts/app/netbound_app.gd`, Phase 5 regression |
| Low | Main-menu actions stretched across the available width. | Menu buttons had a minimum width but no container shrink flag. | Center actions at a consistent 360-pixel minimum width. | `game/scripts/app/netbound_app.gd` |
| Low | The visible build label still read `Vertical Slice P9`. | The label was a hard-coded milestone constant. | Derive `v0.9.0 RC` from `application/config/version`. | `game/project.godot`, `game/scripts/app/netbound_app.gd` |

## Behavior intentionally unchanged

- Shot power, height-category thresholds, curve strength/caps, goal geometry, star thresholds, and level tuning were not retuned because all existing acceptance tests passed.
- Final-shot goal processing retains priority over failure.
- Rewarded extra shots are retired; Store rewarded-Token ads and provider boundaries remain intact.
- Store products remain simulated in development and unavailable in release mode. No real store, ad, consent, analytics, account, or cloud-save SDK was added.
- Quality tiers remain presentation-only and do not alter physics or scoring.
- Android stays ARM64-only and offline except for the `VIBRATE` permission.

## Automated verification

Final clean matrix logs: `/tmp/netbound-final-doc-regression.FPBE0A`

- Headless editor import: passed.
- Configured production app startup: passed.
- Strict `--check-only` parser sweep: 52/52 GDScripts passed.
- Direct production scene startup: 10/10 levels passed.
- Regression scripts: 21/21 exited successfully.
- Phase 1 through Phase 9: all passed.
- Historical airborne, arcade, goal, loft, release, reset, shot-order, and trajectory checks: all passed.
- Final integrated flow: passed.
- Unexpected `SCRIPT ERROR`, `ERROR`, `WARNING`, parse-error, or ObjectDB-leak matches in the final matrix: zero.
- `git diff --check`: passed throughout the verified commits.

The integrated flow executes fresh save, Level 01 launch, three real swipe/miss cycles, failure result, free Try Again, a production swipe and swept goal, efficient progression, Level 02 unlock, cosmetic preview/equip, settings changes, Level 02 pause/resume, app teardown, disk reload, and persisted-state verification.

A three-run integration soak also passed. Each run completed in approximately 4.4 seconds with peak resident memory between 163 MB and 164 MB and no upward trend.

### Commands run

The final matrix used the installed Godot 4.7 executable and the production project path:

```sh
GODOT=/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot
PROJECT=/Users/ryland/Documents/NetBound/game

$GODOT --headless --path "$PROJECT" --editor --quit
$GODOT --headless --path "$PROJECT" --quit-after 30

find "$PROJECT" -name '*.gd' -type f | sort | while IFS= read -r script; do
  rel=${script#"$PROJECT/"}
  $GODOT --headless --path "$PROJECT" --check-only --script "res://$rel"
done

for level in 01 02 03 04 05 06 07 08 09 10; do
  $GODOT --headless --path "$PROJECT" "res://levels/level_$level.tscn" --quit-after 6
done

find "$PROJECT/scripts/debug" -name 'verify_*_external.gd' -type f | sort | \
while IFS= read -r script; do
  rel=${script#"$PROJECT/"}
  $GODOT --headless --path "$PROJECT" --script "res://$rel"
done

git diff --check
git status --short
```

Export commands:

```sh
$GODOT --headless --path "$PROJECT" \
  --export-debug "Android Debug" /tmp/netbound-final-rc-exports.UlHG8p/netbound-debug.apk

$GODOT --headless --path /tmp/netbound-android-project.DkAipz/game \
  --install-android-build-template \
  --export-debug "Android Debug AAB" /tmp/netbound-final-rc-exports.UlHG8p/netbound-debug.aab

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  $GODOT --headless --path "$PROJECT" \
  --export-debug "iOS Debug" /tmp/netbound-final-rc-exports.UlHG8p/ios/netbound-debug.zip
```

Package validation used Android SDK `aapt2`/`apksigner`, `jarsigner`, `unzip`, and Bundletool 1.18.3. Xcode validation used `xcode-select`, `xcodebuild`, `xcrun simctl`, and `security find-identity`.

## Visible inspection

Real Godot viewport captures were inspected at 1280x720 and representative UI shapes including 1600x720, 1920x864, 2340x1080, 1024x768, and 1366x1024. Simulated safe margins were separately checked by Phase 9.

Inspected states:

- Main Menu with fresh-save `Play`, centered actions, and RC version label.
- Level Select with fresh, partial, and complete progression.
- Cosmetics with fresh, partial, complete, and supporter-owned data.
- Store with available, unavailable, owned, pending, and failed simulated-provider states.
- Settings and Pause.
- Levels 01, 04, 05, 07, 08, and 10.
- Success, failure, cosmetic-unlock, free-restart, and Level 10 completion results.

All inspected actions remained readable and inside the viewport. Scrollable content behaved as intended. Gameplay obstacles, goal openings, tutorials, shot counter, power bar, and pause action remained readable in the representative levels.

Viewport texture readback on the local Metal-backed renderer intermittently returned incomplete tiles during capture. Discarding a readback and forcing a fresh frame produced complete evidence. This did not occur in the running viewport, headless checks, or UI-bound tests and is treated as a local screenshot-readback artifact rather than a game render defect.

## Android export results

Final artifacts are temporary and uncommitted under `/tmp/netbound-final-rc-exports.UlHG8p`.

### Debug APK

- Export: passed.
- Size: approximately 27 MB.
- SHA-256: `18db3c1bf5f95253dd4a8766aa198dbde028ce3dc02ca0bab85f4f0a5707de7d`.
- Package/version: `com.netbound.game`, `0.9.0`, code `9`.
- SDK: min 24, target 36.
- ABI: `arm64-v8a` only.
- Permissions: `android.permission.VIBRATE`; no Internet permission.
- Signature: Android debug certificate, APK v2/v3 verified.

### Debug AAB

- Gradle export from a temporary project copy: passed.
- Size: approximately 27 MB.
- SHA-256: `068d420a0fdf6c95b4ee6275e66531a174b78eeac25b9585bc691e22c50186ff`.
- Bundletool 1.18.3 validation: passed.
- Package/version: `com.netbound.game`, `0.9.0`, code `9`.
- SDK: min 29, target 36.
- ABI: `arm64-v8a` only.
- Permissions: `android.permission.VIBRATE`; no Internet permission.
- Bundletool universal APK generation and debug signing: passed; APK v3 verified.
- Development/debug resources excluded: verified by exact archive inspection.

Godot's Gradle task reports signing enabled but emits an unsigned debug AAB. A separate debug-keystore-signed AAB was created and verified at `/tmp/netbound-final-rc-exports.UlHG8p/netbound-debug-signed.aab` with SHA-256 `849ca5697e0e2361a91f0b0cded10a8e70b78ac92b01a1ba9bc2fb0288d21c5e`. This is suitable only for local validation; a real upload/release key is still required.

`aapt2` reports a non-fatal missing `themed_icon.xml` resource-table entry in the prebuilt Godot APK template. The manifest's actual adaptive `@mipmap/icon` resolves, and the Gradle/AAB resource set includes the themed icon. Launcher appearance still needs physical-device inspection.

## iOS and Xcode status

- Xcode path: `/Applications/Xcode.app/Contents/Developer`.
- `xcode-select`: correctly points to full Xcode.
- Xcode: 26.6, build `17F113`.
- First-launch status: complete.
- SDK/runtime: iOS and iOS Simulator 26.5 installed.
- Available simulators: iPhone 17 family, iPhone Air, and current iPads.
- Signing identities: zero.
- Godot iOS template: installed for 4.7 stable.
- iOS preset floor: corrected to iOS 16.0.
- Godot iOS Debug export: blocked at preset validation because App Store Team ID is empty.

No Team ID was invented and no global signing state was changed. With no identity or provisioning profile, Godot does not generate the Xcode project, so simulator/device compilation could not proceed.

## Known limitations and required physical tests

Still required on at least one representative Android phone and one iPhone:

- Install and cold launch the exported build.
- Complete all twenty current production levels using physical touch input, including side-entry goals and the moving target.
- Confirm shot aiming under finger occlusion and all four height categories.
- Confirm mild, strong, and extreme curve feel.
- Verify notch, cutout, rounded-corner, and home-indicator safe areas.
- Verify haptic timing/intensity and disabled-haptics behavior.
- Verify speaker/headphone audio, audio focus, interruptions, and volume settings.
- Background, lock, suspend, resume, and process-termination persistence.
- Repeated Retry, Reset, pause/resume, and navigation under touch.
- Thermal behavior, frame pacing, memory, and battery on low/mid-range hardware.
- Launcher icon and splash appearance.
- Android install/logcat smoke test and iOS device console smoke test.

Deferred until developer accounts/credentials exist:

- Android upload/release keystore and Play App Signing.
- Google Play internal-test upload and device catalog review.
- Apple Team ID, certificate, provisioning, and Personal Team device build.
- TestFlight/App Store submission, production entitlements, privacy forms, and store metadata.
- Any real purchase, ad, consent, analytics, or account SDK integration.

## Commits

- `203dc0e` — `fix: recover backups and bound swipe samples`
- `ac5051d` — `polish: clarify release candidate menu state`
- `59a861c` — `fix: exclude development harnesses from exports`
- `adefb0d` — `test: add final release candidate flow regression`
- `c357248` — `fix: align iOS deployment target with Metal`

The documentation commit follows these changes.

## Post-RC Economy And UI Audit

The later production UI redesign and version 2 cosmetic economy were audited separately against the real `NetboundApp`, `LevelController`, Store, Locker, result, save, simulated-provider, and Low-quality paths.

Outcome:

- `65/65` GDScripts parsed;
- `10/10` production levels started directly;
- `24/24` external regression scripts passed;
- exact 38-item catalog and five Token products passed;
- real production completion reward/result flow passed;
- malformed/migrated/backup/interrupted-write save cases passed;
- preview and repeated Store/gameplay/result node/resource counts remained flat;
- Android debug APK and AAB exports passed.

Three production issues were fixed: atomic rollback of failed completion writes, persistent insufficient-funds feedback, and completed-level cleanup on non-Pause Store entry. Full evidence and remaining physical-device/platform limitations are in `docs/ECONOMY_SHOP_RC_AUDIT.md`.
