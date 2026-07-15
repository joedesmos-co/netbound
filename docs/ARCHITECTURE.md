# Netbound Architecture Audit

Phase 0 audit date: 2026-07-14  
Godot version used for baseline: 4.7.stable.official.5b4e0cb0f  
Project root: `game/`

## Phase 1 Shooting Stabilization Update

Phase 1 replaces the previous mixed impulse/velocity launch path with one canonical arcade launch velocity.

Current launch model:

- Swipe endpoint direction determines horizontal aim.
- Swipe distance determines `launch_speed`.
- Upward screen angle determines `elevation_degrees`.
- Launch direction is:
  - `horizontal_direction * cos(elevation)`
  - plus `Vector3.UP * sin(elevation)`
- `ball.linear_velocity` is assigned directly to `launch_direction * launch_speed`.
- The launch vector is no longer divided by ball mass.

Current global launch tuning:

- `minimum_launch_speed = 5.0`
- `maximum_launch_speed = 25.0`
- `power_curve_exponent = 0.72`
- `minimum_elevation_degrees = 0.0`
- `driven_elevation_degrees = 6.5`
- `normal_air_elevation_degrees = 18.0`
- `maximum_elevation_degrees = 38.0`
- `elevation_response_exponent = 1.15`

Measured Phase 1 peak heights in Level 01:

- Ground: about `0.53`
- Driven: about `1.05`
- Air: about `4.04`
- Lob: about `10.49`

Curve is now deterministic and bounded:

- Gesture intent uses the full sampled swipe path. Dominant left/right area and peak
  deviation choose the sign, while normalized chord deviation chooses strength.
- A normalized dead zone rejects tiny hand wobble without suppressing deliberate
  short hooks. The same signed curve value drives the live aim line and launch.
- Curve rotates horizontal velocity over `curve_duration = 1.35`.
- Height velocity is not modified by curve.
- Horizontal speed is preserved during curve rotation.
- `maximum_curve_heading_degrees = 78.0`.
- Regression measurements:
  - mild curve cap: about `19.5` degrees
  - strong curve cap: about `39.0` degrees
  - extreme curve cap: `78.0` degrees

Reset ownership now uses one physics-safe reset path:

- `_apply_physics_safe_reset()` repositions the ball, zeros forces/velocities, unfreezes it, and leaves it sleeping at contact height.
- READY means the ball is visible, unfrozen, stationary, and shootable.
- Manual Reset Ball invalidates the active shot and returns to READY if shots remain, without refunding the spent shot.
- Retry restores all attempts.
- Auto-reset, goal feedback, and continue callbacks use generation guards so stale callbacks cannot mutate newer shots.

Camera behavior:

- Setup framing remains goal-facing.
- During a shot, the camera smoothly follows ball x/z and rises for high lobs.
- Reset/retry disables shot follow and smoothly returns to setup framing.

Debug cleanup:

- Normal gameplay hides numeric debug labels.
- Production gameplay logs are behind `developer_debug_enabled`.
- `GoalDetector.debug_goal_detection` defaults to `false`.

## Phase 2 Reusable Level Architecture Update

Phase 2 adds a composition layer around the stable Phase 1 shooting controller. Launch math, curve tuning, camera follow, reset ball safety, and swept goal detection remain global gameplay systems.

Ownership boundaries:

- Global gameplay systems remain in `prototype_controller.gd`: input, launch velocity, curve, ball preparation/reset, camera follow, and developer debug display.
- Reusable level runtime lives in `level_controller.gd`: level definition application, shot limit, level state, bounds, win/fail, goal registration, deterministic Retry reset, and `LevelResult` data.
- Level content lives in scenes/resources: `BallSpawn`, `GoalTarget`, obstacles, resettable components, tutorial copy, bounds, par shots, and camera framing.

Level definition schema:

- Resource class: `LevelDefinition`
- Files: `res://levels/definitions/*.tres`
- Fields: `level_id`, `display_name`, `shot_limit`, `par_shots`, `tutorial_text`, `bounds_min`, `bounds_max`, `camera_position`, `camera_look_at`, `mechanic_id`, `tags`, and `next_level_id`.
- Progression and save data are intentionally not part of Phase 2.

Reusable components:

- `GoalTarget`: attached to the goal root. It owns opening width, crossbar height, depth, detector sync, debug volume sizing, and frame/net helper sizing from one exported source of truth. It wraps `GoalDetector` so multiple goals can be registered by the level runtime. Phase 3 syncs both goal line `z` and center `x`, so off-center goals keep visual and scoring geometry aligned.
- `MovingObstacle`: deterministic point-to-point motion with duration, looping/ping-pong, start phase, and exact Retry reset.
- `RotatingObstacle`: deterministic rotation with exported axis, speed, start angle, and exact Retry reset.
- `TimedGate`: deterministic open/closed cycle with exported durations, start phase, target node movement, visible state, and exact Retry reset.
- `BounceSurface`: per-surface physics material override for arcade bounce/friction without mutating global ball physics.
- `NetboundArcadeCourseArt`: visual-only runtime wrapper for collision-backed course
  obstacles. It hides the original raw box mesh, adds an exact-size framed equipment
  visual under the same body, and never owns collision or movement.

Reset contract:

- Resettable level elements join the `netbound_level_resettable` group.
- Resettable nodes implement `reset_level_element(generation: int)`.
- `_restart_level()` enters `AUTO_RESETTING`, cancels stale shot callbacks, awaits the physics-safe ball reset, immediately resets all group members, then enters `READY`.
- READY is therefore reached only after the ball and level elements have completed their reset path.
- Components use deterministic `_physics_process()` state rather than tweens/timers, so Retry cannot leave stale tweens running.

## Phase 3 Production Level Update

Phase 3 adds exactly ten production levels:

- `res://levels/level_01.tscn` through `res://levels/level_10.tscn`
- `res://levels/definitions/level_01_definition.tres` through `level_10_definition.tres`

The level set uses inherited scenes and reusable components rather than duplicating the gameplay controller. No production level overrides global launch speed, elevation, curve, ball mass, ball radius, damping, or bounce tuning.

New Phase 3 content coverage:

- Levels 02, 09, and 10 use `TimedGate`.
- Level 07 uses `RotatingObstacle`.
- Level 08 uses `BounceSurface`.
- Level 10 uses an off-center `GoalTarget`; `GoalDetector.goal_center_x` is synced from the goal root so scoring follows the moved frame.

Phase 5 replaces direct Level 01 startup with the app shell. Production levels remain loadable scenes, but the configured main scene is now `res://app/netbound_app.tscn`.

## Content Expansion Architecture Update

The 2026-07-15 content pass extends the production registry to exactly 20 levels while preserving the Phase 1 shooting model and save version `2`.

- Production content now spans `res://levels/level_01.tscn` through `res://levels/level_20.tscn` with matching definitions.
- `LevelRegistry.EXPECTED_LEVEL_COUNT` is `20`; `NetboundApp` derives the maximum star total from that registry instead of hard-coding `30`.
- Level 10 now points to Level 11; Level 20 is the only production definition with an empty `next_level_id`.
- `MovingObstacle.target_path` can move a composed `Node3D` while one elapsed phase remains authoritative. Level 17 uses it to move the whole goal target.
- `GoalTarget` synchronizes detector geometry from its current global transform before each swept query, so moving visual/scoring geometry cannot drift.
- Arcade goal scoring accepts swept inward front, left-side, or right-side enclosure entry. Rear and fully outside crossings remain invalid, and shot IDs enforce one goal per attempt.
- Level presentation keeps every goal frame neutral white; mechanic colors belong to hazards and visual-only celebrations.

Existing version-2 saves normalize against the expanded registry. Completed Level 10 progress unlocks Level 11 while preserving stars, economy ledgers, cosmetics, and entitlements. The schema itself did not change.

## Phase 4 Offline Progression Update

Phase 4 adds versioned local progression without adding menus, online systems, monetization, or final result UI.

New systems:

- Autoload `SaveService` (`res://scripts/services/save_service.gd`), class `NetboundSaveService`.
- `ProgressionUpdate` result object for future Phase 5 result screens.
- `LevelRegistry` (`res://scripts/levels/level_registry.gd`) with explicit production level IDs, scene paths, and definition paths.
- Save-format documentation in `docs/SAVE_FORMAT.md`.

Save ownership:

- All file IO is centralized in `SaveService`.
- Default path is `user://netbound_save.json`.
- Writes go through `user://netbound_save.tmp` and preserve `user://netbound_save.bak` where practical.
- Malformed JSON is preserved as `user://netbound_save.corrupt` before defaults are recreated.

Progression flow:

1. `level_controller.gd` creates a completed `LevelResult` on goal only.
2. The controller calls `/root/SaveService.record_level_result()`.
3. `SaveService` calculates stars, preserves best-ever stars/fewest shots, marks completion, unlocks the next level, evaluates earned cosmetics, saves immediately, and emits `progression_changed(update)`.
4. Failure, Retry, manual Reset Ball, and auto-reset do not call the save service.

The Autoload disables recording during `--script` debug runs by default to avoid mutating normal user progress. Phase 4 tests opt into recording with isolated save paths.

## Phase 5 Menu And Navigation Update

Phase 5 adds the production app shell without changing shooting, level layouts, monetization, or online systems.

New systems:

- `NetboundApp` (`res://scripts/app/netbound_app.gd`) owns main menu, level select, settings, cosmetics, pause, results, and scene navigation.
- `res://app/netbound_app.tscn` is the configured main scene.
- `NetboundMenuBackdrop` draws the lightweight animated arcade menu background procedurally.
- `verify_phase5_navigation_external.gd` covers app flow and UI state with isolated save data.

Navigation flow:

1. Startup loads `NetboundApp`.
2. Main Menu resolves Play/Continue from `LevelRegistry` and `SaveService`.
3. Level Select displays exactly the registered 20 levels in registry order.
4. Loading a level instances the registered scene under the app shell.
5. The level keeps stable shooting/reset/goal behavior and emits `level_completed` or `level_failed`.
6. The app shell presents production result overlays and navigation actions.

Level UI integration:

- Direct level scenes still keep legacy win/fail panels for historical regression scripts.
- The app shell calls `set_external_navigation_ui_enabled(true)` on loaded levels, hiding temporary result panels and the old Retry Level HUD button.
- Normal gameplay keeps shots remaining, tutorial copy, Reset Ball, swipe overlay, and the app-level Pause button.
- Developer labels remain hidden unless the saved development setting enables them.

## Phase 6 Cosmetic System Update

Phase 6 replaces the placeholder cosmetics menu with an offline, gameplay-earned cosmetic system. Cosmetics are visual-only and must not change launch tuning, mass, damping, collision shape, goal detection, radius, camera behavior, or progression math.

New systems:

- `CosmeticRegistry` (`res://scripts/cosmetics/cosmetic_registry.gd`) is the only authority for cosmetic IDs, categories, defaults, unlock requirements, display names, descriptions, and validation.
- `CosmeticVisuals` (`res://scripts/cosmetics/cosmetic_visuals.gd`) applies selected visuals to existing level nodes.
- `NetboundBallTrail` (`res://scripts/cosmetics/ball_trail.gd`) provides bounded visual-only trail points.
- `NetboundCosmeticPreview` (`res://scripts/cosmetics/cosmetic_preview.gd`) provides a lightweight preview viewport for the cosmetics screen without loading a production level.
- `verify_phase6_cosmetics_external.gd` covers registry, save migration, unlocks, UI state, gameplay visuals, result unlock messages, and production level startup.

Save/progression integration:

1. `SaveService.record_level_result()` records normal level progression after a successful goal.
2. The save service evaluates cosmetic milestones from completed levels and total best stars.
3. Newly unlocked cosmetic IDs are appended once, saved immediately, and returned on `ProgressionUpdate.unlocked_cosmetic_ids`.
4. Result UI displays only the newly unlocked IDs from that actual update.
5. Failure, Retry, Reset Ball, auto-reset, and previewing locked cosmetics never unlock or equip cosmetics.

Gameplay visual flow:

1. A level refreshes selected cosmetic IDs from `/root/SaveService` during ready/retry/reset and before goal feedback.
2. Ball skins replace only material overrides on the existing `Ball` child meshes.
3. Trails are child visual nodes and reset when the ball is reset or the level unloads.
4. Goal effects trigger once from `_show_goal_feedback()` after a valid score and are cleared on Retry, unload, Level Select, and Main Menu.

Developer-only utilities live on `SaveService`:

- `unlock_all_cosmetics_for_development()`
- `reset_cosmetics_to_defaults_for_development()`
- `print_cosmetic_registry_validation()`

They are not exposed in normal production UI.

## Phase 7 Presentation Service Update

Phase 7 starts a presentation layer for audio, haptics, motion, and feel. Presentation systems observe semantic gameplay events; they do not own gameplay outcomes.

New service layer:

- `AudioService` (`res://scripts/services/audio_service.gd`) is an Autoload responsible for generated audio assets, bus setup, music state, one-shot playback, cooldowns, bounded player pools, and settings application.
- `HapticsService` (`res://scripts/services/haptics_service.gd`) is an Autoload responsible for semantic haptic events, settings compliance, platform-safe no-ops, and impact rate limits.
- `NetboundGameplayFeedback` (`res://scripts/presentation/gameplay_feedback_controller.gd`) is a per-level observer that presents aim preview, shot release, impact, goal, and near-miss feedback from semantic gameplay state.
- `NetboundCameraFeedback` (`res://scripts/presentation/camera_feedback.gd`) supplies deterministic camera offsets that are applied after normal follow logic and cleared on Reset/Retry/navigation.
- `NetboundLevelVisualPolish` (`res://scripts/presentation/level_visual_polish.gd`) is a per-level visual-only component for environment colors, material language, non-colliding trim meshes, contact shadow, and goal-frame pulse.

Runtime audio buses:

- `Master`
- `Music`
- `SFX`
- `UI` routed to `SFX`

Presentation documentation:

- `docs/PRESENTATION.md`
- `docs/AUDIO.md`

Settings integration:

- Settings read and write Phase 4 `SaveService` keys.
- Master volume is applied to the `Master` bus when present.
- `Music`, `SFX`, and `UI` settings are applied through `AudioService`.
- Haptics is applied through `HapticsService`.
- Reduced motion and camera effects intensity are persisted for Phase 7 feedback systems.
- Developer debug is shown only in debug builds.

Gameplay presentation flow:

1. `prototype_controller.gd` computes the canonical launch velocity exactly as in Phase 1.
2. While aiming, it passes that velocity, shot category, power ratio, and signed curve value into `GameplayFeedback` for a visual-only trajectory/readout.
3. On launch, the ball velocity is assigned first; shot audio, haptics, launch ring, camera offset, and mesh squash/stretch observe the result.
4. Ball impacts route through one semantic impact method and are rate-limited by the audio/haptics services.
5. `level_controller.gd` may present a guarded near miss once per active shot, but valid swept goal detection and final-shot goal priority remain authoritative.
6. `LevelVisualPolish` applies per-level visual progression without touching collision, goal target dimensions, obstacle timing, or verified routes.
7. Reset, Retry, and unload clear aim dots, tweens, transient nodes, near-miss labels, goal pulses, and camera feedback without refunding attempts or changing level state rules.

UI motion:

- `NetboundApp` owns screen/modal/button/result tweens.
- Reduced Motion and headless runs skip UI tweens.
- Active UI tweens are killed on screen or gameplay overlay clear.
- UI motion does not own navigation or progression state.

## Phase 8 Simulated Monetization Update

Phase 8 adds player-friendly monetization architecture without real SDKs, analytics, accounts, cloud services, or online requirements. The layer is simulated and testable; it is intentionally ready for later iOS/Android providers without letting providers own gameplay.

New service layer:

- `MonetizationService` (`res://scripts/services/monetization_service.gd`) is an Autoload responsible for semantic ad/purchase requests, request tokens, entitlements, interstitial policy, provider callbacks, and save integration.
- `NetboundAdProvider` and `NetboundPurchaseProvider` define provider interfaces under `res://scripts/monetization/`.
- `NetboundSimulatedAdProvider` supports available/unavailable, success/cancel/failure, delayed callbacks, and duplicate callback simulation.
- `NetboundSimulatedPurchaseProvider` supports success/cancel/failure/already-owned/restore, delayed callbacks, and duplicate callback simulation.

Product and entitlement IDs:

- `netbound_remove_ads` grants `entitlement_remove_ads`.
- `netbound_starter_pack` grants `entitlement_remove_ads` and `entitlement_starter_pack`.
- Starter Pack also unlocks `ball_supporter`, `trail_supporter`, and `goal_supporter`.

Ownership boundaries:

1. UI and gameplay call semantic methods such as `request_rewarded_ad()`, `request_interstitial()`, `purchase_remove_ads()`, `purchase_starter_pack()`, and `restore_purchases()`.
2. Providers return simulated payloads only. They never mutate shot counts, progression, cosmetics, or save data directly.
3. `MonetizationService` validates request IDs and duplicate callbacks before emitting rewards or recording purchases.
4. `SaveService` is the authority for entitlements, owned products, supporter cosmetic unlocks, selections, and persisted monetization config.

Shot and rewarded-ad flow:

- Failure offers one free `Try Again` action, which starts a new run at zero shots used.
- `Reset Ball` remains inside the current run and never refunds a consumed shot.
- The HUD presents shots used beside par; shot efficiency remains the authority for stars and mastery.
- The old rewarded extra-shot grant path is retired. Its `LevelResult` flag remains readable for historical runtime fixtures but no longer affects star calculation.
- Rewarded ads remain voluntary in the Store and grant Net Tokens through the existing request-ID and duplicate-callback guards.

Interstitial policy:

- Centralized in `MonetizationService.should_show_interstitial(context)`.
- Never requested during gameplay, aiming, or failure.
- Requires at least three completed levels in the save and three completed-level events in the current session.
- At most one interstitial per app session, with a minimum time spacing.
- Disabled by either Remove Ads or Starter Pack.
- Unavailable/offline providers skip silently and navigation continues.

Store/UI flow:

- `NetboundApp` adds a Store screen reachable from Main Menu.
- Store cards show Remove Ads, Starter Pack, Restore Purchases, owned/unavailable/pending states, and simulated-development status.
- Cosmetics screen shows supporter cosmetics as locked preview items until Starter Pack entitlement exists and provides an Open Store route.
- Normal UI exposes no simulated-provider controls.

Monetization must never alter:

- launch speed, elevation, curve, damping, mass, collision radius, goal detection, level access rules, obstacle timing, difficulty, or non-ad star rules.

Proof scene:

- `res://levels/debug/level_architecture_test.tscn`
- Inherits Level 01 instead of duplicating the controller.
- Uses `level_architecture_test.tres` with a different shot limit.
- Demonstrates one `GoalTarget`, one `MovingObstacle`, one `RotatingObstacle`, and one `TimedGate`.
- It is not the configured main scene and is not production Level 02.

How to create a new configured level without changing core shooting:

1. Create a `LevelDefinition` resource under `res://levels/definitions/`.
2. Instance or inherit a level scene using `level_controller.gd`.
3. Assign the `level_definition` export.
4. Place `BallSpawn`, one or more `GoalTarget` nodes, static content, and optional resettable components.
5. Keep per-level changes in the definition and scene content; do not override global shooting exports unless a later phase explicitly documents why.
6. Run the Phase 1, Phase 2, and Phase 3 regression scripts.

## Current Entry Points

- `game/project.godot` runs `res://app/netbound_app.tscn`.
- `game/app/netbound_app.tscn` is the production app shell and menu entry point.
- `game/main.tscn` exists but is an empty `Node3D` and is not the configured main scene.
- `game/scenes/prototype.tscn` is an older standalone shooting prototype.
- `game/levels/level_01.tscn` is the first production gameplay level and remains loadable through the app shell.
- `game/levels/level_02.tscn` through `game/levels/level_20.tscn` are authored production levels for the current slice.
- `game/levels/debug/level_architecture_test.tscn` is an architecture proof scene, not a production level and not the configured main scene.

## Project Settings

- Godot feature tags: `4.7`, `Mobile`.
- Renderer: `mobile`.
- Physics engine: Jolt Physics.
- Stretch mode: `canvas_items`.
- Stretch aspect: `expand`.
- No custom input actions are configured. Gameplay reads mouse and touch events directly in `_unhandled_input`.
- No explicit mobile orientation, export preset, or platform packaging settings are present yet.
- Phase 5 app UI uses conservative margins and pauses on focus loss where practical; physical safe-area and suspend/resume validation remain mobile hardening/release work.

## Current Scene Structure

### `levels/level_01.tscn`

`Level01` is a `Node3D` scene with script `res://scripts/level_controller.gd` and `level_definition = res://levels/definitions/level_01_definition.tres`.

Main children:

- `WorldEnvironment`
- `DirectionalLight3D`
- `Camera3D`
- `BallSpawn`
- `Ground`
- `Obstacle`
- `Goal`
- `Ball`
- `AimGuide`
- `UI`

The scene still contains temporary UI and prototype-era nodes, but level metadata now comes from `LevelDefinition` and goal geometry/scoring is synchronized by `GoalTarget`.

### `levels/level_02.tscn` through `levels/level_20.tscn`

Production levels 02-20 inherit Level 01 and override scene content plus `level_definition`. They do not duplicate `level_controller.gd` or `prototype_controller.gd`.

High-level content:

- Level 02: timed gate.
- Level 03: static precision gap.
- Level 04: central curve blocker.
- Level 05: elevation barrier.
- Level 06: overhead low-road blocker.
- Level 07: rotating obstacle.
- Level 08: bounce wall and direct blocker.
- Level 09: two offset timed gates.
- Level 10: timed gate, low height hurdle, curve blocker, and off-center goal.
- Level 11: front shield and a taught side-enclosure route.
- Levels 12-13: continuously moving deterministic blockers.
- Levels 14-16: precision, elevation/curve, and low-curve combinations.
- Level 17: a smoothly moving composed goal target.
- Levels 18-19: alternate ricochet routes and three-beat timed gates.
- Level 20: final timing/height/curve challenge with a side-enclosure finish.

### `levels/debug/level_architecture_test.tscn`

Architecture proof scene inherited from Level 01. It assigns `level_architecture_test.tres`, uses the same core controller, and adds resettable moving, rotating, and timed components. This scene exists only to prove Phase 2 architecture and should not be treated as production Level 02.

### `scenes/prototype.tscn`

`Prototype` uses `res://scripts/prototype_controller.gd` directly. It contains a smaller ground, ball, aim guide, reset UI, debug labels, and swipe overlay. It is still referenced by several external debug scripts.

## Current Dimensions

- Ball radius: `0.49`.
- Ball spawn target height: `ball_radius + ball_ground_clearance`, currently about `0.52`.
- Level 01 ground mesh/collision: `48 x 0.2 x 42`, positioned at `z = -2`.
- Level 01 bounds in script:
  - `x`: `-24` to `24`
  - `z`: `-18` to `12`
  - minimum `y`: `-2`
- Goal root: `(0, 0, -10)`.
- Goal scoring line: `z = -10`.
- Goal half width used for scoring: `11`.
- Visual opening width from posts: about `22`.
- Crossbar scoring height: `8.4`.
- Goal interior depth: `5`.
- Prototype ground: `24 x 0.2 x 32`.

## Script Responsibilities

### `prototype_controller.gd`

Base shooting prototype controller. Responsibilities include:

- Camera setup.
- Ball spawn height setup.
- Ball/ground physics material setup.
- Mouse and touch swipe input.
- Swipe sampling and validation.
- Aim guide and swipe overlay updates.
- Shot power, elevation, and curve calculations.
- Direct launch velocity assignment.
- Runtime bounded curve rotation.
- Manual reset.
- Debug UI updates.

This file is currently 1017 lines and mixes production mechanics, UI, debug reporting, physics safeguards, and prototype-only behavior.

### `level_controller.gd`

Extends `prototype_controller.gd` and adds:

- Level definition application.
- Level states.
- Shot limits.
- Level results.
- Win/fail panels.
- Retry level.
- Auto-reset after misses.
- Bounds, timeout, stopped-ball miss checks.
- Goal target registration.
- Resettable level-element contract.
- Goal feedback.

Because it inherits the full prototype controller, level behavior depends on many base-class variables and private methods.

### `levels/level_definition.gd`

Typed `Resource` for per-level metadata and runtime setup values: ID, display name, shot limit, par shots, tutorial copy, bounds, setup camera framing, tags, mechanic ID, and next-level placeholder.

### `levels/level_result.gd`

Typed `Resource` for current-run completion data. Phase 4 records completion/failure, shots used, shots remaining, shot limit, par shots, result state, and level ID. Persistence and star ratings are handled by `SaveService`.

### `components/goal_target.gd`

Reusable goal component. It owns goal dimensions, keeps child visuals/debug helpers/scoring detector synchronized, wraps swept scoring calls, and emits a target-aware `goal_scored` signal.

### `components/moving_obstacle.gd`

Reusable deterministic point-to-point mover with loop/ping-pong settings, optional composed target path, and reset signature support for tests.

### `components/rotating_obstacle.gd`

Reusable deterministic rotator with exported axis, speed, start angle, and reset signature support.

### `components/timed_gate.gd`

Reusable deterministic open/closed gate that moves a target node between closed and open positions on a fixed cycle.

### `components/bounce_surface.gd`

Reusable local bounce surface that applies its own `PhysicsMaterial` override without changing ball or global ground tuning.

### `goal_detector.gd`

Standalone `GoalDetector` node. It performs swept goal-line crossing detection from previous to current ball position and emits `goal_scored`.

The detector scores immediately when the ball's full radius crosses the goal opening at the crossing moment. It intentionally does not invalidate a legal crossing later because of side or rear net position. Phase 3 adds `goal_center_x`, so off-center goals evaluate opening width relative to the goal root instead of assuming world `x = 0`.

### `swipe_overlay.gd`

Canvas overlay for drawing sampled swipe points, the shot arrow, and a curve preview.

## Game State Flow

Current `LevelState` values:

- `READY`
- `SHOT_ACTIVE`
- `AUTO_RESETTING`
- `GOAL`
- `FAILED`

Startup flow:

1. `level_controller._ready()` applies `LevelDefinition` runtime values such as shot limit, bounds, tutorial camera setup, and camera look-at.
2. It awaits `super._ready()`.
3. Base `_ready()` configures camera, spawn, swipe distance, ball tuning, debug UI, and awaits `_apply_physics_safe_reset()`.
4. Level `_ready()` applies tutorial text, registers `GoalTarget` nodes, connects UI callbacks, then awaits `_restart_level()`.

Shot flow:

1. `_begin_swipe()` accepts mouse/touch input when gameplay is allowed, no reset is active, the ball is stopped, and the pointer starts near the ball.
2. `_update_swipe()` samples and recalculates shot state.
3. `_end_swipe()` validates the gesture and calls `_fire_shot()` if valid.
4. `level_controller._fire_shot()` consumes a shot only when state is `READY`, increments `active_shot_id`, ensures the ball is awake, sets `SHOT_ACTIVE`, then calls `super._fire_shot()`.
5. `prototype_controller._fire_shot()` computes the canonical launch velocity, directly assigns `ball.linear_velocity`, starts bounded curve state when needed, and clears the swipe.
6. Goal tracking begins on all registered targets after the base launch call.

Shot resolution flow:

1. During `SHOT_ACTIVE`, `level_controller._physics_process()` first lets the base class apply bounded curve rotation, peak tracking, and smart camera follow.
2. It then evaluates goal crossing, bounds, timeout, and stopped-ball miss.
3. A valid goal emits `goal_scored` and enters `GOAL`.
4. A miss with remaining shots enters `AUTO_RESETTING` and schedules a timer.
5. A final miss enters `FAILED`.

Retry reset flow:

1. `_restart_level()` cancels stale shot callbacks and enters `AUTO_RESETTING`.
2. Shot counters and result data are reset.
3. The ball reset path is awaited.
4. All `netbound_level_resettable` nodes receive `reset_level_element(level_reset_generation)` immediately before READY.
5. The ball is made ready and the level enters `READY`.

## Shot Calculation

Current gesture model:

- Swipe start must be near the ball.
- Swipe endpoint controls horizontal aim through camera-space right/forward projection.
- Swipe distance controls power.
- Overall screen upward angle controls elevation.
- Lateral path deviation controls curve.

Current exported launch tuning is documented in the Phase 1 update above.

Important implementation detail:

- `_compute_launch_velocity()` is the canonical launch calculation.
- It returns a velocity, not an impulse.
- `_fire_shot()` assigns that velocity directly to `ball.linear_velocity`.
- Ball mass no longer affects launch speed.

## Curve Calculation

Current curve flow:

- `_calculate_curve_amount()` delegates to `_analyze_curve_intent()` so the full
  sampled gesture determines a single signed curve value.
- Weighted path area and peak chord deviation determine the dominant side; this
  prevents a clear hook from being cancelled when the gesture returns toward its
  endpoint.
- Normalized deviation determines strength through the proven
  `curve_full_bend_ratio = 0.28` response. A `curve_normalized_deadzone` of `0.012`
  (with a two-pixel minimum) rejects small wobble. Cumulative turn remains an
  inspectable diagnostic and does not multiply launch curvature.
- The curve response remains resolution-independent because all geometric values
  are normalized by chord length. Mouse and touch use the same sample analyzer.
- `_begin_bounded_curve()` maps signed curve amount to a total heading target.
- `_apply_arcade_curve()` rotates horizontal velocity over time.
- Curve does not modify vertical velocity.
- Curve is capped at `maximum_curve_heading_degrees`.

## Velocity Application

The current launch path uses direct velocity assignment:

1. `ball.freeze = false`
2. `ball.sleeping = false`
3. `ball.linear_velocity = Vector3.ZERO`
4. `ball.angular_velocity = Vector3.ZERO`
5. `ball.global_position.y` is lifted to at least spawn height plus launch clearance.
6. `ball.linear_velocity = launch_velocity`

Launch tuning and debug fields now use velocity terminology.

## Async Methods And Awaiting

Async methods:

- `prototype_controller._ready()` awaits `_apply_physics_safe_reset()`.
- `prototype_controller._run_reset()` awaits `_apply_physics_safe_reset()` and a physics frame.
- `prototype_controller._apply_physics_safe_reset()` awaits one physics frame.
- `prototype_controller._validate_launch_next_frame()` awaits one physics frame and only restores velocity if a stale freeze somehow returned.
- `level_controller._ready()` awaits `super._ready()` and `_restart_level()`.
- `level_controller._on_retry_level_pressed()` awaits `_restart_level()`.
- `level_controller._restart_level()` awaits `_reset_level_elements()` and `_apply_physics_safe_reset()`.
- `level_controller._auto_reset_after_miss()` awaits `_apply_physics_safe_reset()`.

Non-awaited or callback-driven async risks:

- `prototype_controller._fire_shot()` calls `_validate_launch_next_frame()` without awaiting it; the callback is token-guarded.
- Timer callbacks for auto-reset, goal flash, time-scale restore, and continue are generation-guarded.

## Freeze, Unfreeze, And Reposition Sites

Authoritative-ish reset flow today:

- `_apply_physics_safe_reset()` increments `reset_generation`, freezes the ball, zeros forces and velocities, applies spawn transform, awaits a physics frame, validates the token, reapplies transform and zero velocities, resets interpolation, unfreezes, leaves the ball sleeping at rest, and reapplies tuning.
- `_ensure_ball_ready_for_play()` clears `reset_in_progress`, unfreezes, zeros velocities, and leaves the ball sleeping at rest.

Other freeze/unfreeze sites:

- `_fire_shot()` unfreezes and wakes before velocity assignment.
- `_on_goal_scored()` freezes the ball after scoring.
- External debug scripts directly set `freeze`, `sleeping`, and velocities.

Risk:

- Reset ownership uses `reset_generation`.
- Shot/miss/goal callback ownership uses `state_generation` in `level_controller.gd`.

## Callbacks That Can End Or Reset A Shot

- `GoalDetector.goal_scored -> level_controller._on_goal_scored()`
- `level_controller._resolve_miss()` from:
  - `_is_ball_out_of_bounds()`
  - shot timeout
  - `_is_ball_stopped()`
- `_schedule_auto_reset()` timer -> `_auto_reset_after_miss()`
- Reset button -> `_on_reset_button_pressed()`
- Retry buttons -> `_on_retry_level_pressed()`
- Win continue button -> `_on_continue_pressed()` timer -> `_restart_level()`
- Goal feedback timers:
  - `_restore_time_scale()`
  - `_hide_goal_flash()`
- Reset label timer -> `_hide_reset_ok_label()`

## Goal Detection

Strengths:

- Uses swept crossing rather than relying on Area3D overlap timing.
- Scores at goal-mouth crossing and avoids invalidating legal goals later due to side net or rear net geometry.
- Uses a tracked shot ID to reject stale shot IDs.
- `GoalTarget` now synchronizes the detector values, debug helper volumes, and goal frame/net helper dimensions from one exported target configuration.
- Off-center goals are supported through `GoalDetector.goal_center_x`, synced by `GoalTarget`.

Risks:

- `GoalMouthTrigger` and `GoalInteriorTrigger` exist but have monitoring disabled and are not the primary scoring source.
- Phase 2 still keeps the old trigger nodes for visualization/debug support; scoring remains swept and script-driven.

## UI Structure

Current gameplay UI includes:

- Shots label.
- Reset Ball button.
- Instruction label.
- Power, direction, curve, loft, reset, and shot debug labels behind the developer debug flag.
- Power bar.
- Full-screen goal flash.
- Temporary win/fail panels for direct-scene regression runs.
- Swipe overlay.

Production app UI includes Main Menu, trajectory-route Level Select, compact gameplay HUD, Pause, Success/Failure results, the live-preview Locker, restrained Store, and grouped Settings. `NetboundApp` retains navigation ownership while `NetboundUITheme` and focused custom Controls own the reusable visual language. See `docs/UI_FLOW.md` and `docs/UI_ART_DIRECTION.md`.

UI art-direction components:

- `res://scripts/ui/netbound_ui_theme.gd`: centralized fonts, color/spacing tokens, state styles, and panel roles.
- `res://scripts/ui/wordmark.gd`: procedural Netbound wordmark and strike/target treatment.
- `res://scripts/ui/level_route.gd` and `level_marker.gd`: connected level progression presentation.
- `res://scripts/ui/star_display.gd` and `result_motif.gd`: glyph-independent stars and restrained result identity.
- `res://scripts/ui/cosmetic_choice_button.gd`: bounded horizontal Locker marker with responsive label sizing.
- `res://scripts/ui/menu_backdrop.gd`: primary and secondary sky/field trajectory backdrops.
- `res://scripts/debug/capture_ui_audit_external.gd`: isolated-fixture production screen capture and native-canvas responsive stress utility; it is not connected to production scenes.

The visual system does not own navigation, save state, progression, monetization, shooting, collision, or scoring. Goal frames remain white; cosmetic and shared goal celebrations render around the frame without changing geometry or gameplay materials.

## Camera Behavior

- Level 01 sets camera position to `(0, 11.5, 14)` and look-at to `(0, 3.6, -8.5)`.
- Prototype camera defaults to `(0, 6.5, 10)` looking at `(0, 0.65, -12)`.
- During active shots, the camera smoothly follows horizontal ball movement and rises with high lobs.
- Reset and retry disable shot follow and smoothly return to setup framing.
- Phase 1 did not yet implement per-level camera volumes or mobile safe-area UI work.

## Physics And Collision

- Collision layers and masks are not explicitly set in scenes or scripts.
- Ball and ground use default collision settings.
- Ball tuning is applied at runtime:
  - mass from `ball_mass`
  - linear and angular damping
  - `continuous_cd = true`
  - contact monitor enabled
  - runtime-created physics material
- Ground receives a runtime-created physics material.
- Goal posts and crossbar are colliding `StaticBody3D` nodes.
- Net side, top, rear, and floor are `MeshInstance3D` visuals only and do not collide.
- Obstacle is a single colliding `StaticBody3D`.

## Save, Progression, And Settings

No save system exists yet.

Missing:

- Save versioning.
- Unlocked/completed levels.
- Best stars and fewest shots.
- Cosmetic selection/unlocks.
- Settings.
- Tutorial completion.
- Corrupted-save fallback.
- Atomic save strategy.

## Production Debug Code

Normal-game UI:

- Numerical debug labels are hidden unless `developer_debug_enabled` is true.
- The player still sees normal gameplay controls such as shots, Reset Ball, Retry Level, instructions, and the power bar.

Developer-debug UI available behind the toggle:

- `ResetOkLabel`
- `PowerLabel`
- `DirectionLabel`
- `CurveLabel`
- `LoftCategoryLabel`
- `ShotDebugLabel`

Console logging:

- Production gameplay paths are quiet by default.
- `_debug_log()` prints only when `developer_debug_enabled` is true.
- Goal detection logs print only when `GoalDetector.debug_goal_detection` is true.

Debug scene data:

- Goal debug volume meshes exist in Level 01.
- `debug_goal_detection = false` in `level_01.tscn`.

## Phase 9 Mobile Runtime Update

Phase 9 adds mobile hardening without changing the stable shooting, level, progression, cosmetic, or monetization rules.

New autoload:

- `MobileRuntimeService` (`res://scripts/services/mobile_runtime_service.gd`)

Responsibilities:

- central application lifecycle signals for background, foreground, and quit requests
- safe-area margin calculation with a conservative `28px` fallback
- presentation-only quality tier normalization and effective tier selection
- release/development mode detection through export feature tags
- lifecycle save flush and audio pause/resume coordination

Lifecycle flow:

1. Godot focus/pause notifications enter `MobileRuntimeService`.
2. The service flushes dirty save state, pauses one-shot audio/music safely, and emits semantic app lifecycle signals.
3. `NetboundApp` clears incomplete aim gestures, asks the active level to handle backgrounding, and opens Pause when gameplay is active.
4. Foreground restore reapplies safe-area layout and lets audio resume its existing music player.

Safe-area flow:

- `NetboundApp` uses `_new_margin_container()` for Main Menu, Level Select, Settings, Cosmetics, and Store. The helper now reads safe-area margins from `MobileRuntimeService`.
- Pause/result modal panels clamp to the visible safe-area bounds.
- The gameplay Pause button and level HUD are repositioned through the same margin dictionary.
- `prototype_controller.gd` exposes `apply_safe_area_margins()` so direct level startup and app-loaded levels share the same HUD behavior.

Quality flow:

- `SaveService.settings.quality_tier` stores `auto`, `low`, `medium`, or `high`.
- `MobileRuntimeService` converts `auto` to a platform-sensitive effective tier.
- `LevelController.apply_quality_settings()` passes the visual budget to `LevelVisualPolish`, active ball trails, and goal particle counts.
- Quality settings affect only decorative geometry, shadows, trail point limits, particle multipliers, and camera/presentation multipliers. They do not affect ball physics, shot math, level timing, scoring, progression, or monetization rewards.

Release/development separation:

- Export presets use `netbound_development` or `netbound_release` feature tags.
- In release mode, simulated ad/purchase providers are disabled by `MonetizationService.set_release_mode_enabled(true)`.
- Developer Debug and simulated-provider controls are not exposed through normal release UI.

Save durability:

- `SaveService` now tracks a dirty flag. Existing setters still use immediate atomic writes, but failed writes remain dirty.
- `flush_if_dirty()` is called during app background/quit handling.
- No save-version bump was required because the new quality setting is an optional settings key normalized into save version `1`.

## External Verification Scripts

Scripts under `game/scripts/debug/`:

- `verify_airborne_external.gd`: measures ground, driven, and lofted shot peaks in Level 01.
- `verify_arcade_redesign_external.gd`: checks goal dimensions and shot peak categories.
- `verify_goal_detection_external.gd`: checks swept goal crossing cases.
- `verify_goal_scale_external.gd`: checks visual/scoring goal dimensions and frustum visibility.
- `verify_level01_external.gd`: checks basic Level 01 setup, scoring, retry, and reset behavior.
- `verify_loft_external.gd`: checks elevation categories in the prototype scene.
- `verify_phase1_shooting_external.gd`: covers Phase 1 production-scene launch, reset/retry, auto-reset, shot-height, curve, camera, final-shot, side-net, and cycle regressions.
- `verify_phase2_level_architecture_external.gd`: covers level definitions, `GoalTarget` sync, proof-scene loading, resettable component determinism, unchanged global shooting tuning, side-net goal, final-shot goal priority, and proof shot limit.
- `verify_release_path_external.gd`: drives the production release path and retry cycles.
- `verify_release_shot_external.gd`: verifies canonical launch velocity behavior and the production fire path.
- `verify_reset_external.gd`: checks reset in prototype scene.
- `verify_shot_order_external.gd`: checks final-shot goal/miss and stale callback cases.
- `verify_trajectory_external.gd`: measures trajectory peaks in prototype scene.

Audit notes:

- These scripts are useful regression references but are not a substitute for the real gameplay input path.
- Some scripts call private methods directly or set physics state manually.
- Phase 1 updated the launch and trajectory scripts to use velocity terminology.
- Current Phase 1 pass criteria reject the known bad 47-51 unit lob peaks.

There are also `.uid` files for missing `_validate_*.gd` scripts:

- `_diag_runtime.gd.uid`
- `_validate_camera.gd.uid`
- `_validate_milestone15.gd.uid`
- `_validate_repair.gd.uid`
- `_validate_usability.gd.uid`

## Baseline Verification

Commands run from `game/`:

```sh
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --version
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 5
/Users/ryland/Documents/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --check-only --script res://scripts/prototype_controller.gd
```

The parser check was run for every `.gd` file, including debug scripts.

Results:

- Godot version: `4.7.stable.official.5b4e0cb0f`.
- Headless import: passed.
- Headless startup of configured main scene: passed.
- Parser check for all `.gd` files: passed.
- Existing external debug scripts: all exited with code `0`.
- No parser errors were observed.
- No runtime errors were observed in the baseline startup.
- The Phase 0 baseline startup produced production debug logs; Phase 1 moved production logging behind debug toggles.

Measured trajectory evidence from existing scripts:

- `verify_airborne_external.gd` measured a lofted peak of about `47.45`.
- `verify_arcade_redesign_external.gd` measured a lofted peak of about `51.14`.
- `verify_trajectory_external.gd` measured strong prototype trajectory peak of about `48.16`.

## Phase 0 Highest-Risk Regression Points

1. Shot launch naming and math: the code calls the launch vector an impulse, then divides by mass into velocity. This is a likely root cause of excessive lob height.
2. Elevation cap: `maximum_elevation_degrees = 55` is too high for the desired arcade camera/readability target.
3. Manual reset while a shot is active: the level keeps `SHOT_ACTIVE` and the next launch can avoid normal READY-state shot consumption.
4. Non-awaited reset path: `level_controller._on_reset_button_pressed()` does not await the base async reset.
5. Timer callbacks: auto-reset, continue, goal flash, time-scale restore, and reset label timers need generation/state guards.
6. Launch safeguard: runs asynchronously after launch and can mutate velocity/freeze state later.
7. Static camera: high lobs leave the camera, and curves are not followed.
8. Debug output: production scene contains visible debug labels and noisy console logs.
9. External verification drift: current tests pass despite known unacceptable trajectory heights.
10. Geometry drift: visual goal and scoring values are manually duplicated.
11. Inheritance depth: `level_controller.gd` inherits a large prototype controller, making future reusable levels fragile.
12. No save/progression layer: future menu and star work will need a clean offline persistence boundary.

Phase 1 resolved the current-production portions of items 1 through 9. Phase 2 resolved the current-production goal geometry drift in item 10 by adding `GoalTarget`; future unusual goals still need careful authoring checks. Items 11 and 12 remain future architecture risks for later phases.

## Cosmetic Economy Architecture - July 14, 2026

The local economy adds one service without moving authority into UI or gameplay:

- `/root/WalletService` owns integer balances, grants, spends, reward evaluation, daily Token claims, cosmetic purchases, and transaction idempotency.
- `/root/SaveService` remains the persistence authority. Save version `2` stores economy ledgers and purchased cosmetic IDs through the existing atomic temp/backup flow.
- `/root/MonetizationService` owns provider lifecycle and policy. It passes validated simulated Token purchases and completed rewarded ads to `WalletService`.
- `CosmeticRegistry` owns the 38-item schema, rarity, acquisition type, Coin/Token price, requirements, visual mapping, and ordering.
- `NetboundApp` owns presentation only: wallet labels, filters, purchase confirmation, insufficient-funds feedback, and result reward copy.

Level completion remains authoritative in `SaveService.record_level_result()`. The resulting `ProgressionUpdate` is passed once to `WalletService.process_level_completion_rewards()`, then progression and economy are saved before the success rail is shown. No gameplay script reads currency and no economy method changes physics, collision, scoring, stars, level unlocks, or obstacle timing.

External callbacks use stable transaction IDs. The processed-ID ledger is bounded to 2048 and the developer history to 64 entries. This prevents unbounded local storage but is not a substitute for future server receipt validation. The complete contract is documented in `docs/ECONOMY.md` and `docs/CURRENCY_PRODUCTS.md`.
