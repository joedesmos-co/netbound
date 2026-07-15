# Netbound Level Design Notes

Phase 3 built the first ten authored levels. The content-expansion pass extends the same reusable architecture to exactly 20 deterministic production levels without changing the stable Phase 1 shooting model.

## Production Level Set

All production levels live under `res://levels/level_01.tscn` through `res://levels/level_20.tscn`. Each has a matching `LevelDefinition` in `res://levels/definitions/`.

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
| 11 | Side Door | Arcade side-net entry | 4 | 2 | Bend into the right enclosure boundary around the front shield. |
| 12 | Elevator | Vertical moving blocker | 4 | 2 | Wait for the lift, then use a controlled driven shot. |
| 13 | Cross Traffic | Two horizontal movers | 4 | 2 | Read both lanes and shoot through their shared opening. |
| 14 | Pinhole | Compact precision gap | 4 | 2 | Use a short centered driven swipe through the framed opening. |
| 15 | Sky Hook | Elevation plus curve | 5 | 3 | Lift wide and hook around the tall blocker. |
| 16 | Under And Around | Low shot plus curve | 4 | 2 | Keep the shot low while bending around the side block. |
| 17 | Moving Target | Laterally moving goal | 5 | 3 | Lead the goal and shoot as it crosses the center lane. |
| 18 | Ricochet Run | Alternate bank routes | 5 | 3 | Bank from either bright wall; the right route is the reference solution. |
| 19 | Rhythm Gates | Three-beat timing | 5 | 3 | Follow the repeating gate rhythm and release into the shared window. |
| 20 | Netbound Finale | Timing, curve, height, side entry | 6 | 4 | Use the opening beat and bend into the goal's right enclosure boundary. |

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
| 11 | `(25, -230)` | `11` | `0.0` |
| 12 | `(0, -140)` | `0` | `0.8` |
| 13 | `(0, -225)` | `0` | `0.45` |
| 14 | `(0, -130)` | `0` | `0.0` |
| 15 | `(-165, -260)` | `-16` | `0.0` |
| 16 | `(-115, -145)` | `-8` | `0.0` |
| 17 | `(0, -230)` | `0` | `0.4` |
| 18 | `(230, -205)` | `0` | `0.0` |
| 19 | `(0, -225)` | `0` | `0.55` |
| 20 | `(75, -230)` | `20` | `0.0` |

## Component Usage

- `GoalTarget`: all production goals, including off-center and moving targets. Visual frame/net helpers and swept scoring geometry are synced from the same exported values at runtime.
- `TimedGate`: Levels 02, 09, 10, 19, and 20.
- `MovingObstacle`: Levels 12, 13, and 17. Level 17 targets the entire goal root so visual and scoring geometry move together.
- `RotatingObstacle`: Level 07.
- `BounceSurface`: Levels 08 and 18.
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

### Levels 11-20 - Championship Route

- Level 11 teaches the deliberately generous arcade rule that front, left-side, and right-side entries into the shared net enclosure score; rear entry remains invalid.
- Levels 12-13 make continuous deterministic translation the readable timing language before later combinations.
- Level 14 is compact but leaves ball-radius clearance and uses camera framing to advertise the gap.
- Levels 15-16 combine one established height category with bounded curve instead of changing global shooting values.
- Level 17 moves the `GoalTarget` as one unit and synchronizes its detector before every swept check.
- Level 18 exposes two visible bank routes rather than one hidden solution.
- Level 19 uses three short, deterministic phases without an excessive idle wait.
- Level 20 combines a visible opening beat, moderate lift, bounded bend, and side entry. It accepts multiple nearby swipe/curve variants and does not require a maximum gesture.

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
- The expanded registry has a maximum of `60` best stars. Existing 6-30 star cosmetic milestones remain intentionally unchanged as early/mid-route rewards.

## Future Phase Notes

- Phase 5 added menu navigation, level selection UI, and save-driven result screens.
- Cosmetic unlocks and level selection must read these definitions later; levels themselves do not implement progression.
