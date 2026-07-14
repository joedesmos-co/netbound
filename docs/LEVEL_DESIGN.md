# Netbound Level Design Notes

Phase 3 builds the first production level set: exactly 10 authored, deterministic levels that use the reusable Phase 2 architecture without changing the stable Phase 1 shooting model.

## Production Level Set

All production levels live under `res://levels/level_01.tscn` through `res://levels/level_10.tscn`. Each has a matching `LevelDefinition` in `res://levels/definitions/`.

| Level | Name | Main mechanic | Shots | Par | Verified route |
| --- | --- | --- | ---: | ---: | --- |
| 01 | Open Range | Basic swipe shooting | 3 | 1 | Straight forgiving swipe toward the giant center goal. |
| 02 | The Gate | Simple timing | 3 | 1 | Wait briefly for the timed gate opening, then shoot straight. |
| 03 | Thread The Gap | Directional precision | 3 | 1 | Driven center-lane shot through two static walls. |
| 04 | Bend Around | Curve | 4 | 2 | Aim wide left and bend back right around the central blocker. |
| 05 | Over The Top | Elevation | 4 | 2 | Normal air shot over the low-tuned tall barrier. |
| 06 | Low Road | Ground control | 3 | 1 | Low straight shot under the overhead blocker. |
| 07 | Rotation | Rotating timing obstacle | 4 | 2 | Wait for the rotating bar to open, then shoot through. |
| 08 | Bank Job | Bounce shot | 4 | 2 | Shoot into the bright right wall and bank around the direct blocker. |
| 09 | Double Timing | Two offset timed gates | 5 | 3 | Wait for overlapping openings, then shoot straight through both gates. |
| 10 | The Impossible Shot | Timing, height, and curve | 5 | 3 | Wait, fire a strong air shot with mild left-lane bend into the off-center goal. |

## Scripted Solution Parameters

The Phase 3 regression suite uses production mouse-swipe input, not teleports or helper-only scoring. These values are test guidance, not hidden requirements:

| Level | Swipe offset | Curve px | Wait |
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

## Component Usage

- `GoalTarget`: all production goals, including Level 10's off-center goal. Visual frame/net helpers and scoring geometry are synced from the same exported values.
- `TimedGate`: Levels 02, 09, and 10.
- `RotatingObstacle`: Level 07.
- `BounceSurface`: Level 08.
- Static authored blockers: Levels 03, 04, 05, 06, 08, and 10.

## Production Level Notes

### Level 01 - Open Range

- Preserves the existing giant arcade goal and forgiving center route.
- Keeps one small obstacle far to the side.
- Tutorial covers swipe direction, power, height, and curve.
- Remains the first production gameplay level. Phase 5 loads it through the app shell instead of using it as the configured main scene.

### Level 02 - The Gate

- Uses one readable `TimedGate` with a wide opening.
- The player can wait and shoot straight; no curve is required.
- Reset and Retry restore the gate phase deterministically.

### Level 03 - Thread The Gap

- Two static wall blocks create a central lane.
- The intended solution is a driven precision shot with comfortable clearance.
- Mild diagonal alternatives remain possible.

### Level 04 - Bend Around

- Large central blocker teaches curve routing.
- The verified route aims left and bends right; the goal remains large and visible.
- Does not require maximum curve.

### Level 05 - Over The Top

- A readable barrier blocks ground/driven shots.
- Normal air is enough; maximum lob is not required.
- The camera setup looks higher to keep the barrier and landing region understandable.

### Level 06 - Low Road

- Elevated blocker visually communicates staying low.
- Ground/low-driven shots pass underneath.
- Airborne shots are discouraged by the overhead geometry.

### Level 07 - Rotation

- Uses `RotatingObstacle` with deterministic start angle and speed.
- The timing window is generous enough for mobile latency.
- Retry returns to the exact start rotation.

### Level 08 - Bank Job

- Direct route is blocked by a large center obstacle.
- A bright `BounceSurface` on the right creates a deterministic one-bank solution.
- The bounce wall is locally materialized and does not alter global ball physics.

### Level 09 - Double Timing

- Two `TimedGate` components use offset phases.
- The verified route waits for a shared opening and shoots straight.
- Cycles are short enough to avoid excessive waiting.

### Level 10 - The Impossible Shot

- Final authored challenge combines a timed gate, a low height hurdle, a shifted route, curve input, and an off-center giant goal.
- The title is dramatic, but the verified route is repeatable and does not require maximum curve.
- Off-center scoring is supported by `GoalDetector.goal_center_x`, synced by `GoalTarget`.

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

## Star Rating Notes

- Phase 4 uses each `LevelDefinition.par_shots` and `shot_limit` for saved star ratings.
- `3` stars: complete at or under par.
- `2` stars: complete in exactly `par + 1`.
- `1` star: complete within the shot limit after `par + 1`.
- Replays preserve best-ever stars and fewest shots.

## Future Phase Notes

- Phase 5 added menu navigation, level selection UI, and save-driven result screens.
- Cosmetic unlocks and level selection must read these definitions later; levels themselves do not implement progression.
