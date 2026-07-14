# Netbound Architecture Audit

Phase 0 audit date: 2026-07-14  
Godot version used for baseline: 4.7.stable.official.5b4e0cb0f  
Project root: `game/`

## Current Entry Points

- `game/project.godot` runs `res://levels/level_01.tscn`.
- `game/main.tscn` exists but is an empty `Node3D` and is not the configured main scene.
- `game/scenes/prototype.tscn` is an older standalone shooting prototype.
- `game/levels/level_01.tscn` is the production scene for current gameplay.

## Project Settings

- Godot feature tags: `4.7`, `Mobile`.
- Renderer: `mobile`.
- Physics engine: Jolt Physics.
- Stretch mode: `canvas_items`.
- Stretch aspect: `expand`.
- No custom input actions are configured. Gameplay reads mouse and touch events directly in `_unhandled_input`.
- No explicit mobile orientation, safe area, pause/focus, export preset, audio, or platform settings are present yet.

## Current Scene Structure

### `levels/level_01.tscn`

`Level01` is a monolithic `Node3D` scene with script `res://scripts/level_controller.gd`.

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

The scene combines level geometry, reusable gameplay logic, temporary UI, debug labels, goal detection, and feedback. There is no reusable level definition resource yet.

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
- Runtime curve force application.
- Manual reset.
- Debug UI updates.

This file is currently 893 lines and mixes production mechanics, UI, debug reporting, physics safeguards, and prototype-only behavior.

### `level_controller.gd`

Extends `prototype_controller.gd` and adds:

- Level states.
- Shot limits.
- Win/fail panels.
- Retry level.
- Auto-reset after misses.
- Bounds, timeout, stopped-ball miss checks.
- Goal detector wiring.
- Goal feedback.

Because it inherits the full prototype controller, level behavior depends on many base-class variables and private methods.

### `goal_detector.gd`

Standalone `GoalDetector` node. It performs swept goal-line crossing detection from previous to current ball position and emits `goal_scored`.

The detector scores immediately when the ball's full radius crosses the goal opening at the crossing moment. It intentionally does not invalidate a legal crossing later because of side or rear net position.

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

1. `Level01._ready()` sets camera tuning values.
2. It awaits `super._ready()`.
3. Base `_ready()` configures camera, spawn, swipe distance, ball tuning, debug UI, and awaits `_apply_physics_safe_reset()`.
4. Level `_ready()` configures `GoalDetector`, connects UI and goal callbacks, then awaits `_restart_level()`.

Shot flow:

1. `_begin_swipe()` accepts mouse/touch input when gameplay is allowed, no reset is active, the ball is stopped, and the pointer starts near the ball.
2. `_update_swipe()` samples and recalculates shot state.
3. `_end_swipe()` validates the gesture and calls `_fire_shot()` if valid.
4. `level_controller._fire_shot()` consumes a shot only when state is `READY`, increments `active_shot_id`, ensures the ball is awake, sets `SHOT_ACTIVE`, then calls `super._fire_shot()`.
5. `prototype_controller._fire_shot()` computes a vector named `impulse`, divides by mass into `launch_velocity`, directly assigns `ball.linear_velocity`, starts curve state, and clears the swipe.
6. Goal tracking begins after the base launch call.

Shot resolution flow:

1. During `SHOT_ACTIVE`, `level_controller._physics_process()` first lets the base class apply curve force and peak tracking.
2. It then evaluates goal crossing, bounds, timeout, and stopped-ball miss.
3. A valid goal emits `goal_scored` and enters `GOAL`.
4. A miss with remaining shots enters `AUTO_RESETTING` and schedules a timer.
5. A final miss enters `FAILED`.

## Shot Calculation

Current gesture model:

- Swipe start must be near the ball.
- Swipe endpoint controls horizontal aim through camera-space right/forward projection.
- Swipe distance controls power.
- Overall screen upward angle controls elevation.
- Lateral path deviation controls curve.

Current exported launch tuning:

- `minimum_impulse = 3.5`
- `maximum_impulse = 20.0`
- `power_curve_exponent = 0.68`
- `minimum_elevation_degrees = 0.0`
- `driven_elevation_degrees = 8.0`
- `maximum_elevation_degrees = 55.0`
- `elevation_response_exponent = 1.0`

Important implementation detail:

- `_compute_shot_impulse()` uses the desired arcade launch formula:
  - horizontal direction
  - elevation angle
  - shot speed
  - launch direction = horizontal * cos(elevation) + up * sin(elevation)
- However, the returned vector is named and treated as an impulse. `_fire_shot()` divides it by ball mass to produce velocity.
- With ball mass `0.43`, a nominal speed of `20` becomes a velocity around `46.5`.
- This explains the current full-lob peak measurements of roughly `47` to `51` world units.

Additional mismatch:

- `_recalculate_swipe_state()` already applies `power_curve_exponent` to `current_power_ratio`.
- `_compute_shot_impulse()` applies `power_curve_exponent` again.
- UI power and actual launch speed can therefore diverge.

## Curve Calculation

Current curve flow:

- `_calculate_curve_amount()` measures lateral deviation of swipe samples from the start-to-end line.
- The result is signed and capped by `maximum_curve_strength = 1.75`.
- On launch, the ball receives a torque impulse around `Vector3.UP`.
- During physics frames, while `curve_force_time_remaining > 0`, the ball receives lateral central force:
  - lateral = `travel_direction.cross(Vector3.UP).normalized()`
  - force = lateral * sign * strength * `curve_force_multiplier` * mass

Current curve tuning:

- `curve_force_duration = 1.7`
- `curve_force_multiplier = 22.0`
- `curve_spin_impulse = 7.5`
- `curve_full_bend_ratio = 0.28`
- `curve_response_exponent = 0.7`

Risks:

- No total heading-change cap.
- Curve force can add energy and does not preserve a fixed forward-speed budget.
- Curve behavior is tied to physics integration and current velocity direction.
- Curve has duration and low-speed gates, but no explicit "maximum 80 degrees from original heading" bound.

## Velocity Application

The current launch path uses direct velocity assignment, not an impulse:

1. `ball.freeze = false`
2. `ball.sleeping = false`
3. `ball.linear_velocity = Vector3.ZERO`
4. `ball.angular_velocity = Vector3.ZERO`
5. `ball.global_position.y` is lifted to at least spawn height plus launch clearance.
6. `ball.linear_velocity = launch_velocity`

The code still uses names such as `minimum_impulse`, `maximum_impulse`, `last_final_impulse`, and `_compute_shot_impulse()`, which are misleading for the current deterministic arcade behavior.

## Async Methods And Awaiting

Async methods:

- `prototype_controller._ready()` awaits `_apply_physics_safe_reset()`.
- `prototype_controller._run_reset()` awaits `_apply_physics_safe_reset()` and a physics frame.
- `prototype_controller._apply_physics_safe_reset()` awaits one physics frame.
- `prototype_controller._run_launch_y_safeguard()` awaits one physics frame.
- `prototype_controller._log_shot_velocity_next_frame()` awaits one physics frame and appears unused.
- `level_controller._ready()` awaits `super._ready()` and `_restart_level()`.
- `level_controller._on_retry_level_pressed()` awaits `_restart_level()`.
- `level_controller._restart_level()` awaits `_apply_physics_safe_reset()`.
- `level_controller._auto_reset_after_miss()` awaits `_apply_physics_safe_reset()`.

Non-awaited or callback-driven async risks:

- `level_controller._on_reset_button_pressed()` calls `super._on_reset_button_pressed()` without awaiting the base reset flow.
- `prototype_controller._fire_shot()` calls `_run_launch_y_safeguard()` without awaiting it. This may be intentional, but it must be token-safe.
- `level_controller._on_continue_pressed()` connects a timer callback that calls `_restart_level()` without awaiting it.
- Timer callbacks for auto-reset, goal flash, time-scale restore, and reset labels can fire after state changes unless guarded.

## Freeze, Unfreeze, And Reposition Sites

Authoritative-ish reset flow today:

- `_apply_physics_safe_reset()` increments `reset_generation`, freezes the ball, zeros forces and velocities, applies spawn transform, awaits a physics frame, validates the token, reapplies transform and zero velocities, resets interpolation, unfreezes, wakes the ball, and reapplies tuning.
- `_ensure_ball_ready_for_play()` clears `reset_in_progress`, unfreezes, wakes, and zeroes tiny velocities.

Other freeze/unfreeze sites:

- `_fire_shot()` forcibly unfreezes and wakes before velocity assignment.
- `_on_goal_scored()` freezes the ball after scoring.
- External debug scripts directly set `freeze`, `sleeping`, and velocities.

Risk:

- Reset ownership uses `reset_generation`, but shot launch currently captures the existing generation instead of incrementing or claiming ownership.
- A reset, launch safeguard, or timer callback can still observe stale state if a newer shot or retry begins.

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

Risks:

- Gameplay bounds and visual goal dimensions are manually duplicated through exported values and scene geometry.
- `GoalMouthTrigger` and `GoalInteriorTrigger` exist but have monitoring disabled and are not the primary scoring source.
- `debug_goal_detection` defaults to `true` in both script and Level 01, causing production logs.

## UI Structure

Current gameplay UI includes:

- Shots label.
- Retry Level button.
- Reset Ball button.
- Reset OK label.
- Instruction label.
- Power, direction, curve, loft, and shot debug labels.
- Power bar.
- Full-screen goal flash.
- Temporary win/fail panels.
- Swipe overlay.

There is no main menu, level select, pause menu, polished result screen, settings screen, cosmetics screen, or save UI yet.

## Camera Behavior

- Current camera is static.
- Level 01 sets camera position to `(0, 11.5, 14)` and look-at to `(0, 3.6, -8.5)`.
- Prototype camera defaults to `(0, 6.5, 10)` looking at `(0, 0.65, -12)`.
- No shot follow, high-lob tracking, curve tracking, reset transition, or mobile-safe framing is implemented yet.

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

Visible normal-game UI debug:

- `ResetOkLabel`
- `PowerLabel`
- `DirectionLabel`
- `CurveLabel`
- `LoftCategoryLabel`
- `ShotDebugLabel`

Console logging in production paths:

- Startup/reset: `INIT`, `RESTART_DONE`, `RESET`.
- Release path: `RELEASE_RECEIVED`, `RELEASE_LEVEL`, `RELEASE_FIRE`, `LAUNCH_SAFEGUARD`.
- Peak tracking: `PEAK`.
- Goal detection: `GOAL sync`, `GOAL track_begin`, crossing detail, score messages.

Debug scene data:

- Goal debug volume meshes exist in Level 01.
- `debug_goal_detection = true` in `level_01.tscn`.

## External Verification Scripts

Scripts under `game/scripts/debug/`:

- `verify_airborne_external.gd`: measures ground, driven, and lofted shot peaks in Level 01.
- `verify_arcade_redesign_external.gd`: checks goal dimensions and shot peak categories.
- `verify_goal_detection_external.gd`: checks swept goal crossing cases.
- `verify_goal_scale_external.gd`: checks visual/scoring goal dimensions and frustum visibility.
- `verify_level01_external.gd`: checks basic Level 01 setup, scoring, retry, and reset behavior.
- `verify_loft_external.gd`: checks elevation categories in the prototype scene.
- `verify_release_path_external.gd`: drives the production release path and retry cycles.
- `verify_release_shot_external.gd`: compares old impulse behavior with production fire path.
- `verify_reset_external.gd`: checks reset in prototype scene.
- `verify_shot_order_external.gd`: checks final-shot goal/miss and stale callback cases.
- `verify_trajectory_external.gd`: measures trajectory peaks in prototype scene.

Audit notes:

- These scripts are useful regression references but are not a substitute for the real gameplay input path.
- Some scripts call private methods directly or set physics state manually.
- Several scripts still use older impulse assumptions.
- Current "PASS" criteria allow the known bad 47-51 unit lob peaks.

There are also `.uid` files for missing `_validate_*.gd` scripts:

- `_diag_runtime.gd.uid`
- `_validate_camera.gd.uid`
- `_validate_milestone15.gd.uid`
- `_validate_repair.gd.uid`
- `_validate_usability.gd.uid`

## Baseline Verification

Commands run from `game/`:

```sh
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --version
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --import
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --quit-after 5
/Users/ryland/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/ryland/Documents/NetBound/game --check-only --script res://scripts/prototype_controller.gd
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
- Startup still produces production debug logs.

Measured trajectory evidence from existing scripts:

- `verify_airborne_external.gd` measured a lofted peak of about `47.45`.
- `verify_arcade_redesign_external.gd` measured a lofted peak of about `51.14`.
- `verify_trajectory_external.gd` measured strong prototype trajectory peak of about `48.16`.

## Highest-Risk Regression Points

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
