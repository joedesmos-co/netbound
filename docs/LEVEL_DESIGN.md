# Netbound Level Design Notes

This document records the current level baseline and the target structure for the 10-level vertical slice.

## Current Baseline

Only one production level exists:

- `res://levels/level_01.tscn`
- Scene root: `Level01`
- Script: `res://scripts/level_controller.gd`
- Definition: `res://levels/definitions/level_01_definition.tres`
- Shot limit: `3`
- Goal: oversized arcade goal at `z = -10`
- Goal opening: about `22` units wide and `8.4` units high
- Ground: `48 x 42`
- Obstacle: one small static block near the left side at about `(-11.5, 0.38, -3.8)`
- Camera: elevated, goal-facing setup with Phase 1 shot follow

Level 01 remains the only production level. Phase 2 preserves it as the open-range baseline while moving metadata into a reusable `LevelDefinition` and goal sizing into `GoalTarget`.

One non-production architecture proof scene also exists:

- `res://levels/debug/level_architecture_test.tscn`
- Inherits Level 01.
- Definition: `res://levels/definitions/level_architecture_test.tres`
- Shot limit: `4`
- Demonstrates one `MovingObstacle`, one `RotatingObstacle`, and one `TimedGate`.
- This is not Level 02 and should not be included in the final 10-level sequence.

## Current Level Authoring Issues

- Gameplay controller, temporary UI, ball, field, and some prototype-era nodes still share one scene shell.
- `GoalTarget` now prevents silent drift between goal dimensions and scoring dimensions.
- `LevelDefinition` now provides level ID, display name, shot limit, par shots, tutorial copy, bounds, camera setup, tags, mechanic ID, and next-level placeholder.
- `MovingObstacle`, `RotatingObstacle`, `TimedGate`, and `BounceSurface` exist as reusable components.
- Retry now has a group-based deterministic reset hook for future moving hazards.
- Star ratings, progression, menu navigation, and save data are intentionally still future phases.

## Vertical Slice Level Sequence

Build exactly 10 initial levels after the shooting core is stable.

### Level 01 - Open Range

- Giant open goal.
- Minimal obstacle.
- Teaches swipe direction, power, height, and curve.
- Very forgiving.
- Shot limit: `3`.

### Level 02 - The Gate

- Large moving gate.
- Player times a shot through the opening.
- Teaches timing.
- Shot limit: `3`.

### Level 03 - Thread The Gap

- Two walls with a narrow central opening.
- Driven precision shot.
- Shot limit: `3`.

### Level 04 - Bend Around

- Large central blocker.
- Requires left or right curve.
- Generous goal.
- Shot limit: `4`.

### Level 05 - Over The Top

- Tall barrier.
- Requires a moderate air shot or lob.
- Shot limit: `4`.

### Level 06 - Low Road

- Elevated blockers.
- Requires a ground-skimming shot.
- Shot limit: `3`.

### Level 07 - Rotation

- Rotating obstacle with periodic opening.
- Timing plus directional control.
- Shot limit: `4`.

### Level 08 - Bank Job

- Direct path blocked.
- Uses an angled bounce wall.
- Shot limit: `4`.

### Level 09 - Double Timing

- Two moving gates with offset timing.
- Multiple valid solutions.
- Shot limit: `5`.

### Level 10 - The Impossible Shot

- Moving gap, height choice, and strong curve.
- Difficult but fair.
- Shot limit: `5`.

## Level Design Rules

- Level 1 must feel easy and empowering.
- Introduce one main concept at a time.
- Avoid pixel-perfect requirements in early levels.
- Later gaps may be tight, but must be visually readable.
- Every level must be completable through consistent player skill.
- Avoid physics randomness.
- Include alternate solutions where practical.
- Camera framing must communicate the route and moving hazards.
- Moving objects must use deterministic motion.
- Retry must reset moving object phases consistently.
- Do not use copyrighted external assets.

## Required Data Per Level

Current `LevelDefinition` configuration includes:

- Unique level ID.
- Display name.
- Shot limit.
- Par shots for future star ratings.
- Optional tutorial copy.
- Bounds.
- Level-specific setup camera framing.
- Mechanic ID/tags.
- Next-level identifier placeholder.

Scene content should include:

- Ball spawn.
- One or more goals/targets.
- Static obstacles.
- Moving obstacles.
- Rotating obstacles.
- Timed gates.
- Optional bounce surfaces.

Runtime completion result is represented by `LevelResult`, but save data and star ratings are not implemented yet.

## Reusable Component Notes

`GoalTarget`

- Attach to the goal root.
- Configure opening half-width, crossbar height, interior depth, ball radius, post radius, and debug visibility.
- The component synchronizes visual helpers and the child `GoalDetector` from those values.
- Side and rear net visuals remain non-colliding unless a level intentionally adds separate collision.

`MovingObstacle`

- Configure `point_a`, `point_b`, duration, loop/ping-pong, and start phase.
- Retry resets exact position and phase.

`RotatingObstacle`

- Configure axis, degrees per second, and start angle.
- Retry resets exact rotation and elapsed time.

`TimedGate`

- Configure open/closed positions, durations, starting state, and phase.
- Retry resets exact state and phase.

`BounceSurface`

- Configure only local bounce/friction.
- It must not alter global ball physics or shot tuning.

## Star Rating Direction

Initial rule:

- 3 stars: complete at or under par.
- 2 stars: complete within par + 1.
- 1 star: complete within the shot limit.

Stars must never downgrade a previously earned best result.

## Camera Requirements

Each level should define camera setup data, but the camera system itself should remain global and stable.

Minimum expectations:

- Ball starts lower-center in frame.
- Goal and primary route are visible.
- Moving hazards are readable before launch.
- High lobs and strong curves stay understandable.
- Camera returns smoothly after reset.

## Current Level 01 Risk Notes

- The side/rear nets are visual only, which is correct for legal crossing behavior.
- The huge goal is now backed by `GoalTarget`; future levels can reuse or resize it through exported configuration.
- The debug goal volumes are hidden and normal debug logging is disabled.
