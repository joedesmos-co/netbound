# Netbound Test Plan

Phase 0 documents the current baseline. Later phases should turn this into an automated regression suite that validates the real production scene and input path.

## Baseline Environment

- Godot: `/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot`
- Required version: `4.7.stable.official.5b4e0cb0f`
- Project path: `/Users/ryland/Documents/NetBound/game`
- Current main scene: `res://app/netbound_app.tscn`

## Phase 0 Commands And Outcomes

Version:

```sh
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --version
```

Outcome: passed, `4.7.stable.official.5b4e0cb0f`.

Import:

```sh
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
```

Outcome: passed.

Configured scene startup:

```sh
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 5
```

Outcome: passed. Phase 0 startup emitted debug logs but no errors. Phase 1 later moved normal gameplay logs behind debug toggles.

Parser check:

```sh
for f in $(find scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
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
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
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
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 10
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --path /Users/ryland/Documents/NetBound/game --quit-after 30
```

Outcomes:

- Headless import passed.
- Headless startup passed.
- Normal configured-scene launch passed with Metal/mobile renderer.
- Startup produced no gameplay debug spam.

Strict parser check:

```sh
for f in $(find scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
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
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 3
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game res://levels/debug/level_architecture_test.tscn --quit-after 3
```

Outcomes:

- Headless import passed.
- Configured main-scene startup passed.
- Proof-scene startup passed.

Strict parser check:

```sh
for f in $(find scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
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
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import

for f in $(find scripts -type f -name '*.gd' | sort); do
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
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
  /Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path /Users/ryland/Documents/NetBound/game \
    "$scene" \
    --quit-after 3
done

/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase1_shooting_external.gd
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase2_level_architecture_external.gd
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --script res://scripts/debug/verify_phase3_levels_external.gd
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
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
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
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
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
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
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

Phase 7 adds the presentation service layer, generated original audio assets, audio buses, haptics abstraction, and reduced-motion/camera-effects settings.

Command:

```sh
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/ryland/Documents/NetBound/game \
  --script res://scripts/debug/verify_phase7_presentation_external.gd
```

Current coverage:

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
- all 10 production levels start

Additional Phase 7 UI motion, world polish, and performance checks will be added as those subsystems land.

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

## Manual Gameplay Checklist

Until touch automation exists, manually verify:

- Swipe starts only on or near the ball.
- The ball broadly travels where the swipe points.
- Short and long swipes have readable power difference.
- Upward swipes produce distinct but controlled height.
- Downward/flat swipes stay low.
- Curve gestures bend clearly without reversing unpredictably.
- Manual Reset Ball works during and after a shot.
- Retry Level restores all attempts.
- Goal has priority over final-shot failure.
- Miss auto-reset is understandable.
- Camera keeps representative high and curved shots readable.
- Debug labels and logs are disabled in normal player mode after Phase 1 cleanup.

Still required on physical iOS/Android hardware:

- touch feel and finger occlusion
- safe-area behavior
- haptic behavior after it exists
- app pause/resume
- device performance and thermal behavior

## Runtime Output Policy

Unexpected parser errors, runtime errors, warnings, or console spam should fail the phase being worked on. Expected gameplay conditions should not use `push_error()`.
