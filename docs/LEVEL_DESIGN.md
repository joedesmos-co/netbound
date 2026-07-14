# Netbound Level Design Notes

This document records the current level baseline and the target structure for the 10-level vertical slice.

## Current Baseline

Only one production level exists:

- `res://levels/level_01.tscn`
- Scene root: `Level01`
- Script: `res://scripts/level_controller.gd`
- Shot limit: `3`
- Goal: oversized arcade goal at `z = -10`
- Goal opening: about `22` units wide and `8.4` units high
- Ground: `48 x 42`
- Obstacle: one small static block near the left side at about `(-11.5, 0.38, -3.8)`
- Camera: static, elevated, goal-facing

The current Level 01 is useful as an open-range shooting prototype, but it is not yet a reusable level architecture.

## Current Level Authoring Issues

- Gameplay controller, UI, goal, ball, field, obstacle, and debug elements are all in one scene.
- Goal scoring dimensions are manually mirrored between scene geometry and exported script values.
- No level ID, display name, star/par data, tutorial copy, or completion result resource exists.
- No moving obstacles, rotating obstacles, timed gates, bounce surfaces, or level-specific camera configuration exist as reusable components.
- No deterministic reset hooks exist for future moving hazards.

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

Future level configuration should include:

- Unique level ID.
- Display name.
- Shot limit.
- Ball spawn.
- One or more goals/targets.
- Static obstacles.
- Moving obstacles.
- Rotating obstacles.
- Timed gates.
- Optional bounce surfaces.
- Bounds.
- Level-specific camera framing.
- Par shots for star ratings.
- Optional tutorial copy.
- Completion result.

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

- The static camera cannot handle current extreme lobs.
- The huge goal is good for identity but should become a reusable component.
- The side/rear nets are visual only, which is correct for legal crossing behavior.
- The debug goal volumes are hidden, but debug logging remains active.
