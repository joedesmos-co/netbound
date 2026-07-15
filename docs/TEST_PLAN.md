# Netbound Test Plan

Phase 0 documents the current baseline. Later phases should turn this into an automated regression suite that validates the real production scene and input path.

## Content Expansion Cosmetic Quality Contract

`res://scripts/debug/verify_cosmetic_quality_external.gd` asserts:

- all `38` cosmetics retain unique, valid registry definitions
- acquisition counts remain `10` gameplay, `12` Coin, `8` Token, `3` supporter, `2` achievement, and `3` default
- all `18` balls expose a named concept layer and bounded `0.66` visual footprint
- every non-starter Rare/Epic/Legendary ball uses a concept beyond the intentional early soccer variants
- every skin preserves ball mass `0.43`, collision radius `0.49`, collision scale, base mesh resource, and global launch speed
- every goal effect creates `1-3` bounded roots, respects Low-quality node caps, and cleans itself completely

This contract supplements the Phase 6 and economy RC suites; it does not replace their ownership, persistence, shop, or lifecycle checks.

## Gameplay Clarity And 20-Level Expansion Contract

Current production scope is exactly `20` levels and a maximum of `60` best stars. Historical Phase 3-9 sections below retain the ten-level outcomes that were true when those phases shipped; the current acceptance suite supersedes those counts.

Focused scripts:

- `verify_goal_detection_external.gd`: swept front/left/right scoring, fast side entry, rear/outside rejection, post bounce rejection, duplicate prevention, and final-shot side-goal priority.
- `verify_gameplay_clarity_external.gd`: one normal-player aim line, lifecycle clearing, recognizable starter/menu soccer ball, white goals, continuous deterministic moving hazards, and UI contrast/copy constraints.
- `verify_cosmetic_quality_external.gd`: 38-item visual/acquisition/physics contract and bounded goal effects.
- `verify_content_expansion_external.gd`: exactly 20 sequential definitions, Level 17 moving goal detector sync, mechanic visual language, legacy version-2 normalization, Level 11 unlock, and wallet/cosmetic ledger preservation.
- `verify_phase3_levels_external.gd`: production mouse-swipe completion for all 20 levels, including explicit right-side enclosure entry for Levels 11 and 20.
- `verify_environment_art_external.gd`: all 20 collision signatures, exact visual/base
  alignment, six reusable equipment archetypes, moving-parent synchronization,
  Low-quality identity, bounded resources, and cleanup.

Focused command:

```sh
for script in \
  verify_goal_detection_external.gd \
  verify_gameplay_clarity_external.gd \
  verify_cosmetic_quality_external.gd \
  verify_content_expansion_external.gd \
  verify_phase3_levels_external.gd; do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless --path /Users/ryland/Documents/NetBound/game \
    --script "res://scripts/debug/${script}"
done
```

## Player-Feel Closeout - 2026-07-15

The targeted player-feel phase completed a `71/71` strict GDScript parser sweep,
`29/29` retained external verification scripts, configured startup, all 20
production swipe routes, and clean Android APK/AAB exports. New focused coverage:

- `verify_player_feel_external.gd`: retry terminology/behavior, reward removal,
  success audio order and peaks, semantic colors, curve gestures, and invariants
- `verify_environment_art_external.gd`: all-level collision signatures, exact
  visual alignment, archetype coverage, quality bounds, and cleanup

Visible evidence and command outcomes are indexed in
`docs/PLAYER_FEEL_AUDIT.md`.

The complete audit also runs every retained `verify_*.gd` script, direct startup of Levels 01-20, configured app startup, parser sweep, responsive captures, and Android APK/AAB exports. Visual evidence is indexed in `docs/CONTENT_EXPANSION.md`.

Content-expansion checkpoint outcome: `68/68` parsers, `20/20` production scene
startups, and `27/27` retained external regressions passed. The later player-feel
closeout above supersedes those totals with `71/71` and `29/29`. Android debug
APK/AAB exports passed at both checkpoints; current hashes are recorded in
`docs/PLAYER_FEEL_AUDIT.md`.

## Baseline Environment

- Godot: `/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot`
- Required version: `4.7.stable.official.5b4e0cb0f`
- Project path: `/Users/ryland/Documents/NetBound/game`
- Current main scene: `res://app/netbound_app.tscn`

## Phase 0 Commands And Outcomes

Version:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --version
```

Outcome: passed, `4.7.stable.official.5b4e0cb0f`.

Import:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
```

Outcome: passed.

Configured scene startup:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 5
```

Outcome: passed. Phase 0 startup emitted debug logs but no errors. Phase 1 later moved normal gameplay logs behind debug toggles.

Parser check:

```sh
for f in $(find scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    --check-only \
    --script "res://${f}"
done
```

Outcome: all `.gd` files passed.

External debug scripts:

```sh
for f in $(find scripts/debug -type f -name '*.gd' | sort); do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    --script "res://${f}"
done
```

Outcome: all scripts exited with code `0`.

Phase 0 caveat: these scripts were not all production-path tests. Several called private methods, manually mutated physics state, or used older impulse assumptions. Their pass criteria allowed unacceptable lob peaks around `47` to `51` world units. Phase 1 updated the relevant launch/trajectory scripts and added production-path coverage.

## Existing Debug Scripts

- `verify_airborne_external.gd`
- `verify_arcade_redesign_external.gd`
- `verify_goal_detection_external.gd`
- `verify_goal_scale_external.gd`
- `verify_level01_external.gd`
- `verify_loft_external.gd`
- `verify_phase1_shooting_external.gd`
- `verify_phase2_level_architecture_external.gd`
- `verify_phase3_levels_external.gd`
- `verify_phase4_progression_external.gd`
- `verify_release_path_external.gd`
- `verify_release_shot_external.gd`
- `verify_reset_external.gd`
- `verify_shot_order_external.gd`
- `verify_trajectory_external.gd`

Keep these as historical probes until Phase 1 replaces or supplements them with production-path regression tests.

## Phase 1 Required Regression Coverage

Automated coverage should validate:

- Initial launch.
- Launch after manual Reset Ball.
- Launch after Retry Level.
- Launch after goal.
- Launch after auto-reset.
- Ground shot.
- Driven shot.
- Air shot.
- Full lob.
- Straight shot.
- Mild curve.
- Extreme curve.
- Final-shot goal.
- Final-shot miss.
- Stale timer after goal.
- Ball never remaining frozen in READY state.
- One valid shot consumes exactly one attempt.
- Invalid gestures consume no attempts.
- Manual Reset Ball does not refund a shot.
- Retry Level restores all attempts.

## Phase 1 Verification Results

Phase 1 added and updated regression coverage around the production scene and launch path.

Commands:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 10
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --path /Users/ryland/Documents/NetBound/game --quit-after 30
```

Outcomes:

- Headless import passed.
- Headless startup passed.
- Normal configured-scene launch passed with Metal/mobile renderer.
- Startup produced no gameplay debug spam.

Strict parser check:

```sh
for f in $(find scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    --check-only \
    --script "res://${f}"
done
```

Outcome: all scripts passed with no `SCRIPT ERROR`, parse errors, or Godot `ERROR` output.

Strict external regression scripts:

- `verify_airborne_external.gd`: passed.
- `verify_arcade_redesign_external.gd`: passed.
- `verify_goal_detection_external.gd`: passed.
- `verify_goal_scale_external.gd`: passed.
- `verify_level01_external.gd`: passed.
- `verify_loft_external.gd`: passed.
- `verify_phase1_shooting_external.gd`: passed.
- `verify_release_path_external.gd`: passed.
- `verify_release_shot_external.gd`: passed.
- `verify_reset_external.gd`: passed.
- `verify_shot_order_external.gd`: passed.
- `verify_trajectory_external.gd`: passed.

Measured Phase 1 peak heights:

- Ground: about `0.53`
- Driven: about `1.05`
- Air: about `4.04`
- Lob: about `10.49`

Measured Phase 1 curve caps:

- Mild: about `19.5` degrees.
- Strong: about `39.0` degrees.
- Extreme: `78.0` degrees.

`verify_phase1_shooting_external.gd` covers:

- fresh launch to shoot
- Reset Ball to shoot
- Retry Level to shoot
- score to Retry to shoot
- auto-reset after miss to shoot
- invalid swipe consumes no shot
- ground, driven, air, and maximum lob peak bands
- mild, strong, and extreme curve
- curve plus lob
- camera follow and return
- final-shot goal
- final-shot miss
- side-net goal
- five Reset/shoot cycles
- five Retry/shoot cycles

## Phase 2 Verification Results

Phase 2 adds reusable level architecture without changing global shooting tuning.

Commands:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 3
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game res://levels/debug/level_architecture_test.tscn --quit-after 3
```

Outcomes:

- Headless import passed.
- Configured main-scene startup passed.
- Proof-scene startup passed.

Strict parser check:

```sh
for f in $(find scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    --check-only \
    --script "res://${f}"
done
```

Outcome: all scripts passed.

Strict external regression scripts:

- All Phase 1 scripts still pass.
- `verify_phase2_level_architecture_external.gd`: passed.

`verify_phase2_level_architecture_external.gd` covers:

- Level 01 definition loads correctly.
- Level 01 still launches, scores, resets, and retries.
- Goal visual/scoring dimensions stay synchronized through `GoalTarget`.
- Proof scene loads with a second `LevelDefinition`.
- Moving obstacle resets deterministically.
- Rotating obstacle resets deterministically.
- Timed gate resets deterministically.
- Multiple retries produce identical initial resettable-element signatures.
- Stale tween/timer-style drift is avoided by deterministic component state.
- Proof-scene shot limit is respected.
- Global shooting values are unchanged across Level 01 and the proof scene.
- Side-net goal detection remains valid.
- Final-shot goal still beats fail state.

## Phase 3 Verification Results

Phase 3 adds exactly 10 authored production levels without changing global shooting tuning.

Commands:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import

for f in $(find scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    --check-only \
    --script "res://${f}"
done

for scene in \
  res://levels/level_01.tscn \
  res://levels/level_02.tscn \
  res://levels/level_03.tscn \
  res://levels/level_04.tscn \
  res://levels/level_05.tscn \
  res://levels/level_06.tscn \
  res://levels/level_07.tscn \
  res://levels/level_08.tscn \
  res://levels/level_09.tscn \
  res://levels/level_10.tscn; do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    "$scene" \
    --quit-after 3
done

/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase1_shooting_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase2_level_architecture_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase3_levels_external.gd
```

Outcomes:

- Headless import passed.
- Strict parser check passed.
- Startup passed for all 10 production scenes.
- Phase 1 shooting regression still passed.
- Phase 2 architecture regression still passed.
- Phase 3 level-content regression passed.

`verify_phase3_levels_external.gd` covers:

- exactly 10 production level specs
- all scenes load and start through the production controller
- all definitions load with unique sequential IDs
- expected shot limits, par values, and next-level IDs
- unchanged global shooting tuning
- unchanged ball radius, mass, damping, and bounce tuning
- no debug scripts attached to production scene nodes
- one production level controller per level
- `GoalTarget` visual/scoring sync, including Level 10's off-center goal
- READY ball state after restart
- deterministic Retry reset signatures for resettable elements
- scripted production-input completion routes for all 10 levels

Scripted Phase 3 routes:

| Level | Offset | Curve px | Wait |
| --- | --- | ---: | ---: |
| 01 | `(0, -220)` | `0` | `0.0` |
| 02 | `(0, -230)` | `0` | `0.25` |
| 03 | `(18, -235)` | `0` | `0.0` |
| 04 | `(-145, -245)` | `-12` | `0.0` |
| 05 | `(0, -235)` | `0` | `0.0` |
| 06 | `(0, -135)` | `0` | `0.0` |
| 07 | `(0, -230)` | `0` | `0.45` |
| 08 | `(135, -185)` | `0` | `0.0` |
| 09 | `(0, -230)` | `0` | `0.45` |
| 10 | `(-4, -305)` | `-4` | `0.5` |

Phase 3 also updates `verify_goal_detection_external.gd` with off-center goal scoring coverage.

## Phase 4 Verification Results

Phase 4 adds offline progression, star ratings, an explicit level registry, and versioned local save data.

Command:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/ryland/Documents/NetBound/game \
  --script res://scripts/debug/verify_phase4_progression_external.gd
```

Outcome: passed.

`verify_phase4_progression_external.gd` covers:

- missing save creates defaults
- Level 01 unlocked and Levels 02-10 locked by default
- zero default stars
- default cosmetic selections and settings
- exactly 10 registered production levels
- unique, sequential registry IDs
- valid scene and definition paths
- star boundaries for par, par + 1, worse completion, failure, and malformed par/shot-limit data
- completing Level 01 unlocks Level 02
- completing Level 10 does not invent a next level
- completion is monotonic
- best stars never decrease
- fewest shots never worsen
- total stars sums best stars
- failure does not modify progression
- locked level completion does not modify progression
- save/load round trip
- settings, cosmetic, and tutorial round trips
- malformed JSON recovery with corrupt-file preservation
- missing/malformed field normalization
- invalid stars and volumes clamping
- invalid selected cosmetic fallback
- unknown level IDs ignored
- Level 01 forced unlocked
- temp-file atomic write path and backup preservation
- simulated write failure leaves a reloadable primary save
- real Level 01 completion records progression through the production controller and Autoload

Phase 4 tests use isolated `user://phase4_*` save paths so development progress is not destroyed.

## Phase 5 Verification Results

Phase 5 added the production app shell, main menu, level select, pause menu, settings screen, placeholder cosmetics entry point, and save-driven result overlays.

Command:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/ryland/Documents/NetBound/game \
  --script res://scripts/debug/verify_phase5_navigation_external.gd
```

Outcome: passed.

`verify_phase5_navigation_external.gd` covers:

- configured main scene is `res://app/netbound_app.tscn`
- app starts on Main Menu
- Play/Continue resolves Level 01 on a fresh save
- completing Level 01 resolves Level 02
- all-complete state resolves to Level Select
- double navigation is blocked
- invalid or locked level launch fails without loading
- Level Select creates exactly 10 cards in registry order
- locked cards are disabled
- unlocked cards can launch production level scenes
- total stars displays from `SaveService`
- production gameplay hides debug labels and the old Retry Level HUD button
- Pause sets the tree paused and Resume restores gameplay
- Restart uses the level retry path
- success result displays saved progression data
- final-shot-style goal enters success, not failure
- Next Level is enabled only after the next level unlocks
- failure result does not change total stars
- Level 10 result disables Next Level
- settings persist through `SaveService`
- basic touch target minimums are preserved
- cosmetics screen opens from navigation

Phase 5 tests use isolated `user://phase5_*` save paths.

## Phase 6 Verification Results

Phase 6 adds the offline cosmetic registry, unlockable ball skins, trails, goal effects, cosmetics screen, gameplay visual application, save migration, and result unlock announcements.

Command:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/ryland/Documents/NetBound/game \
  --script res://scripts/debug/verify_phase6_cosmetics_external.gd
```

Outcome: passed.

`verify_phase6_cosmetics_external.gd` covers:

- expected 14 cosmetics across balls, trails, and goal effects
- unique stable IDs
- valid categories and defaults
- valid unlock requirement text
- default selections and unlocked cosmetics
- locked cosmetics cannot be equipped
- unlocked cosmetics can be equipped
- selection persists after reload
- invalid saved selection falls back to defaults
- Phase 4 legacy cosmetic IDs migrate safely into stable IDs
- save version remains `1`
- Level 2 completion unlocks Neon Ball
- total-star thresholds unlock Fire, Flame, Confetti, Rainbow, Gold, and Shockwave
- Level 10 completion unlocks Galaxy Ball
- failures do not unlock cosmetics
- repeated evaluation does not duplicate unlocks
- all-unlocked development fixture unlocks exactly 14 cosmetics
- selected ball skin appears without changing mass, collision radius, or global shot speed tuning
- selected trail appears while moving and resets
- selected goal effect creates and clears a transient visual node
- Cosmetics screen has all three categories
- locked preview does not save selection
- Back navigation exits the Cosmetics screen
- result screen displays actual newly unlocked cosmetic IDs
- repeat completion does not announce old unlocks again
- all 10 production levels start with selected cosmetics applied

Phase 6 tests use isolated `user://phase6_*` save paths.

## Phase 7 Verification Results

Phase 7 adds the presentation service layer, generated original audio assets, audio buses, haptics abstraction, aim/shot/goal/near-miss feedback, level visual polish, UI motion, and reduced-motion/camera-effects settings.

Command:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/ryland/Documents/NetBound/game \
  --script res://scripts/debug/verify_phase7_presentation_external.gd
```

Coverage:

- generated audio assets resolve
- `Music`, `SFX`, and `UI` buses exist
- audio player pools are bounded
- zero Music/SFX settings silence the right buses
- music transitions reuse the AudioService music player
- impact cooldown prevents spam
- haptics setting disables requests
- repeated haptics are rate-limited
- reduced-motion and camera-effects settings normalize safely
- aim preview derives from the current canonical launch velocity
- preview clears on release and release feedback does not alter launch velocity
- camera feedback is deterministic, intensity-controlled, and clearable
- near-miss feedback is generation-guarded and does not set `GOAL`
- every production level creates bounded visual-only polish nodes
- visual polish nodes contain no collision objects
- goal target geometry remains synced after visual polish
- ball physics values remain unchanged after visual polish
- repeated cosmetic refresh reuses ball/trail resources
- Reduced Motion suppresses UI tweens in the app shell
- Level Select and Cosmetics remain navigable through the app shell
- all 10 production levels start

Final Phase 7 audit commands and outcomes:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 3
for f in $(find /Users/ryland/Documents/NetBound/game/scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    --check-only \
    --script "res://${f#/Users/ryland/Documents/NetBound/game/}"
done
for f in $(find /Users/ryland/Documents/NetBound/game/scripts/debug -type f -name '*.gd' | sort); do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    --script "res://${f#/Users/ryland/Documents/NetBound/game/}"
done
for scene in res://levels/level_01.tscn res://levels/level_02.tscn res://levels/level_03.tscn res://levels/level_04.tscn res://levels/level_05.tscn res://levels/level_06.tscn res://levels/level_07.tscn res://levels/level_08.tscn res://levels/level_09.tscn res://levels/level_10.tscn; do
  /Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    "$scene" \
    --quit-after 3
done
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --path /Users/ryland/Documents/NetBound/game --quit-after 4
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --path /Users/ryland/Documents/NetBound/game res://levels/level_01.tscn --quit-after 4
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --path /Users/ryland/Documents/NetBound/game res://levels/level_05.tscn --quit-after 4
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --path /Users/ryland/Documents/NetBound/game res://levels/level_07.tscn --quit-after 4
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --path /Users/ryland/Documents/NetBound/game res://levels/level_10.tscn --quit-after 4
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase7_presentation_external.gd
git diff --check
```

Outcomes:

- Headless import passed.
- Configured app startup passed.
- Strict parser sweep passed for every GDScript file.
- Every external debug script passed, including Phase 1-7 suites and historical release/reset/trajectory probes.
- All 10 production level scenes started headlessly.
- Visible configured app launch passed on `Metal 4.0 - Forward Mobile`.
- Visible Level 01, Level 05, Level 07, and Level 10 launches passed on `Metal 4.0 - Forward Mobile`.
- Visible Phase 7 app/menu/cosmetics smoke script passed.
- `git diff --check` passed.

## Phase 8 Verification Results

Phase 8 added simulated monetization architecture, local entitlements, interstitial policy, Store UI, offline-provider behavior, and supporter cosmetics. The later player-feel pass retired rewarded extra shots while preserving rewarded Tokens.

New regression script:

- `verify_phase8_monetization_external.gd`

Coverage:

- simulated ad and purchase providers initialize
- unavailable providers block safely
- duplicate rewarded requests are blocked
- duplicate provider callbacks grant only once
- Remove Ads and Starter Pack purchases persist
- Starter Pack grants all supporter cosmetics
- restore is idempotent
- invalid entitlement data normalizes
- Phase 7 saves without a `monetization` block load safely
- failure exposes free `Try Again` and no rewarded extra-shot action
- `Reset Ball` preserves shots used while `Restart Level` resets to zero
- legacy rewarded-continue result flags no longer cap stars
- rewarded Token ads remain functional and duplicate-safe
- interstitial policy requires completed-level thresholds and is disabled by Remove Ads
- Store UI shows owned, unavailable, pending, and restore states
- supporter cosmetics link from Cosmetics to Store
- offline/unavailable providers do not block level play
- all 10 production levels still start

Commands run for Phase 8:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase1_shooting_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase2_level_architecture_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase3_levels_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase4_progression_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase5_navigation_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase6_cosmetics_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase7_presentation_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase8_monetization_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 3
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --path /Users/ryland/Documents/NetBound/game --quit-after 3
```

Outcomes:

- Phase 1 through Phase 8 regression scripts passed.
- Configured app startup passed headlessly.
- Visible configured app launch passed on `Metal 4.0 - Forward Mobile`.
- Strict parser checks passed for touched production and test scripts.

## Phase 9 Mobile Hardening Regression

Primary Phase 9 script:

- `verify_phase9_mobile_external.gd`

Coverage:

- mobile project settings and export preset sanity
- `MobileRuntimeService` safe-area, lifecycle, quality, and release-mode behavior
- dirty save write failure and lifecycle flush behavior
- simulated release mode disables development monetization providers
- safe-area layout across Main Menu, Level Select, Settings, Cosmetics, Store, Gameplay HUD, Pause, and Results where applicable
- touch UI-guarding, canceled touches, multi-touch ownership, and background gesture clearing
- audio background/foreground pause/resume without duplicate music players
- quality tiers affect only presentation budgets and preserve gameplay signatures
- all 10 production levels still start

Commands run for Phase 9 regression:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase1_shooting_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase2_level_architecture_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase3_levels_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase4_progression_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase5_navigation_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase6_cosmetics_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase7_presentation_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase8_monetization_external.gd
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase9_mobile_external.gd
```

Outcome: all Phase 1 through Phase 9 regression scripts passed after the mobile runtime changes.

Export/toolchain checks run for Phase 9:

```sh
java -version
adb version
xcodebuild -version
xcrun --find xcodebuild
which sdkmanager
which apksigner
which jarsigner
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --export-debug "Android Debug" /tmp/netbound-phase9/android/netbound-debug.apk
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --export-debug "iOS Debug" /tmp/netbound-phase9/ios/netbound-debug
```

Export/toolchain outcomes:

- Java exists: `25.0.2`.
- `adb`, `sdkmanager`, and `apksigner` are not installed/on `PATH`.
- `jarsigner` exists at `/usr/bin/jarsigner`.
- `xcodebuild` is unavailable because only Command Line Tools are selected, not full Xcode.
- Android export preset is visible to Godot but cannot export because Android templates, Android SDK platform-tools/build-tools, adb, apksigner, and configured Java SDK path are missing.
- iOS export preset is visible to Godot but cannot export because Godot `4.7.stable` `ios.zip` template is missing.

## Trajectory Acceptance Targets

Approximate peak height above field:

- Ground skim: `0.5` to `0.8`.
- Driven shot: `1.0` to `2.0`.
- Normal air shot: `3` to `7`.
- Full lob: `10` to `18`.

Phase 0 baseline failure evidence:

- Full lob peaks around `47` to `51`.
- Phase 0 debug tests still passed those values, so their expectations had to be tightened.

Phase 1 status:

- Height expectations have been tightened.
- Current measured full lob peak is about `10.49`, within the `10` to `18` target band.

## Curve Acceptance Targets

The suite should measure and categorize total heading change:

- Straight: negligible.
- Bend: `10` to `20` degrees.
- Wild: `25` to `45` degrees.
- Extreme: `50` to `75` degrees.

No shot should turn more than about `80` degrees from its original heading.

Player-feel gesture classification also verifies:

- straight gestures and small alternating hand wobble remain negligible
- mild left/right bends are obvious and symmetric
- strong left/right bends reach a clearly stronger signed value
- hooks at either the start or end of a gesture do not cancel out
- sparse three-sample swipes still classify consistently
- proportionally identical short and long gestures remain close
- mouse and touch sample paths produce the same curve value
- the one normal-player aim line receives the exact canonical curve value

Current deterministic classifier measurements from
`verify_player_feel_external.gd`:

- straight and wobble: `0.000`
- mild left/right: approximately `-0.279` / `+0.279`
- strong left/right: approximately `-0.709` / `+0.709`
- start/end hooks: approximately `0.504`
- sparse curve: approximately `0.354`
- proportional short/long gestures: approximately `0.481` / `0.485`

## Manual Gameplay Checklist

Until touch automation exists, manually verify:

- Swipe starts only on or near the ball.
- The ball broadly travels where the swipe points.
- Short and long swipes have readable power difference.
- Upward swipes produce distinct but controlled height.
- Downward/flat swipes stay low.
- Curve gestures bend clearly without reversing unpredictably; verify straight,
  mild left/right, strong left/right, start/end hooks, and curve-plus-lob.
- Manual Reset Ball works during and after a shot.
- Retry Level restores all attempts.
- Goal has priority over final-shot failure.
- Miss auto-reset is understandable.
- Camera keeps representative high and curved shots readable.
- Debug labels and logs are disabled in normal player mode after Phase 1 cleanup.

Still required on physical iOS/Android hardware:

- touch feel and finger occlusion
- safe-area behavior
- haptic behavior on physical iOS/Android devices
- app pause/resume
- device performance and thermal behavior

## Runtime Output Policy

Unexpected parser errors, runtime errors, warnings, or console spam should fail the phase being worked on. Expected gameplay conditions should not use `push_error()`.

## Final Release-Candidate Regression - July 14, 2026

The final candidate adds `res://scripts/debug/verify_final_rc_flow_external.gd`. It uses isolated save paths and verifies:

- fresh-save main-menu state
- Level 01 production launch
- three real swipe/miss cycles and failure
- one free failure restart through `Try Again`
- a production swipe and swept goal
- three-star efficient completion and Level 02 unlock
- cosmetic preview/equip persistence
- settings persistence
- Level 02 pause/resume
- app teardown, disk reload, and persisted state

Final matrix outcome:

- headless import: passed
- configured app startup: passed
- GDScript parser sweep: 52/52
- direct level startup: 10/10
- debug regression scripts: 21/21
- unexpected error/warning/leak matches: zero
- three-run final-flow soak: passed, stable at approximately 163-164 MB peak resident memory

Run the focused integration check with:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless --path game \
  --script res://scripts/debug/verify_final_rc_flow_external.gd
```

The physical-device items in the manual checklist remain mandatory and are not implied by these local results.

## Production UI Art-Direction Verification - July 14, 2026

Focused design-invariant check:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless --path /Users/ryland/Documents/NetBound/game \
  --script res://scripts/debug/verify_ui_art_direction_external.gd
```

Coverage:

- shared theme tokens and bundled display/body fonts resolve;
- Main Menu and the ten-marker trajectory Level Select build through production navigation;
- Locker, Store, and Settings retain their real save/monetization bindings;
- the goal-effect preview keeps the goal material white;
- preview celebration geometry is bounded to 12 reusable pieces and one reusable ring;
- all ten level markers remain within the viewport and preserve minimum touch size at `1280x720`, `1600x720`, `1920x864`, `2340x1080`, `1024x768`, and `1366x1024`.

Visible audit assets:

- canonical production-canvas captures: `docs/ui_art_direction/final/`
- exact native-canvas responsive stress captures: `docs/ui_art_direction/responsive/`
- initial and iterative review captures: `docs/ui_art_direction/before/`, `vertical_slice/`, and `secondary_review/`

The audit capture script uses isolated save paths and fixture states. It is external-only and is never connected to a production scene.

## Cosmetic Economy And Shop Verification - July 14, 2026

Primary focused verifier:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless --path /Users/ryland/Documents/NetBound/game \
  --script res://scripts/debug/verify_economy_external.gd
```

Coverage:

- 38-item registry counts, IDs, categories, rarity, acquisition rules, prices, defaults, and procedural resource references;
- fresh wallet defaults, integer grants/spends, insufficient funds, malformed balance normalization, reload persistence, and bounded transaction history;
- completion, first-clear, new-star, and personal-best Coin rewards with no failure/reopened-result duplication;
- v1 migration, existing-progression reward seeding, corrupt-save recovery, and v2 reload;
- rewarded Token completion/cancel/failure/duplicate handling, five-ad/ten-Token daily limit, date rollover, rollback guard, and Remove Ads compatibility;
- Coin/Token cosmetic purchase, atomic ownership/deduction, duplicate purchase rejection, equip persistence, and non-purchasable progression items;
- all five consumable Token products, invalid products, delayed/duplicate callbacks, and non-restoration;
- Starter Pack permanent ownership, one-time 2,500 Coin/300 Token fulfillment, and restore without repeated currency;
- Store/Locker/result bindings and visual-only gameplay invariance.

Final gate outcome:

- Godot import and configured startup: passed.
- Strict parser sweep: `64/64`.
- Production level startup: `10/10`.
- External regression scripts: `23/23`.
- Output audit: no parser errors, runtime errors, warnings, or unexpected logs.
- Android debug APK export: passed.
- Android debug AAB export from a temporary build-template project: passed.
- APK archive/signature validation: passed with v2/v3 debug signing.
- AAB archive integrity: passed; local Gradle AAB remains unsigned as documented for future upload signing.

Visible isolated-save captures are stored in `docs/economy_review/`, including empty/affordable/insufficient/purchased Locker states, Token confirmation, daily limit, simulated purchase success/failure, Starter Pack ownership, and result reward breakdown.

## Economy And Shop Release-Candidate Audit - July 14, 2026

Dedicated verifier:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot \
  --headless --path /Users/ryland/Documents/NetBound/game \
  --script res://scripts/debug/verify_economy_rc_external.gd
```

Additional coverage beyond `verify_economy_external.gd`:

- production swipe, Reset Ball, Retry, auto-reset, failure, swept goal, progression, wallet, and result-label flow;
- failed completion-write rollback across progression, wallet, cosmetic unlocks, reward history, and result presentation;
- actual cosmetic card, filter, purchase, confirmation, equip, touch-drag, and release-mode Store controls;
- delayed duplicated product callback after navigation and simulated background/foreground;
- malformed v2 arrays/IDs/balances, valid-backup recovery, failed cosmetic purchase, and v1 anti-retroactive migration;
- all 38 preview/gameplay cosmetics under Low quality;
- bounded goal effects and stable preview/Store-gameplay-result node and resource counts.

Result: passed. Preview remained at 150 nodes/65 resources; five navigation cycles remained at 83 nodes/108 resources. The complete matrix passed 65/65 parsers, 10/10 levels, and 24/24 external scripts with zero unexpected output matches. See `docs/ECONOMY_SHOP_RC_AUDIT.md`.
