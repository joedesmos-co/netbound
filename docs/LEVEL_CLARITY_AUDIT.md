# Netbound Production Level Clarity Audit

## Scope

This audit covers every visible gameplay object in Levels 01-20 after the rewarded-skip phase. It compares authored collision, runtime course-art wrappers, route hints, and production screenshots. The goal is deliberate simplicity: one readable challenge, recognizable equipment, and no object whose only effect is apparent difficulty.

Shared environmental support in every scene consists of the field and its markings, low arena boundaries, sky/lighting, and the white goal frame/net. These elements do not add hidden gameplay collision. The inherited prototype `Obstacle` is hidden with collision disabled in production levels that do not use it.

## Findings

| Level | Required mechanic objects | Route/readability aids | Audit disposition |
|---|---|---|---|
| 01 Open Range | None | Open lane and giant goal | Retained. The empty route is the mechanic. |
| 02 The Gate | Sliding `GateBody` | Painted gate lane | Retained. One moving panel, one timing decision. |
| 03 Thread the Gap | `LeftWall`, `RightWall` | Visible center opening | Retained. Both partitions define one precision gap. |
| 04 Bend Around | `CentralBlocker` | Two curved floor arrows | Retained. Arrows explain the two valid routes and do not collide. |
| 05 Over the Top | `TallBarrier` | Open vertical sightline | Retained. One obstacle communicates lift. |
| 06 Low Road | `OverheadBlocker` | Low floor marker | Retained. The marker identifies the usable underside and does not collide. |
| 07 Rotation | `RotatingGate` | Spinner hub and stripe language | Retained. All visible parts move with the one collider. |
| 08 Bank Job | `DirectBlocker`, `BankWall` | Bright rebound face | Retained. The blocker removes the direct route; the wall creates the bank route. |
| 09 Double Timing | `FirstGate`, `SecondGate` | Bright shared-lane marker | Retained. The apparent overlap is intentional depth: two independently timed planes. |
| 10 The Impossible Shot | `CoreBlocker`, `LiftBarrier`, `FinalGate` | Lift/curve lane marker | Retained. Each object adds a distinct choice: route, height, or timing. |
| 11 Side Door | `FrontShield` | Left/right side-route paint | Retained. The shield teaches side-enclosure scoring; the paint is non-colliding guidance. |
| 12 Elevator | `ElevatorBlocker` | Two vertical rails | Retained. Rails communicate the movement axis and have no collision. |
| 13 Cross Traffic | `NearTraffic`, `FarTraffic` | Distinct depth and height | Retained. Two crossing lanes create the timing mechanic. |
| 14 Pinhole | `LeftWall`, `RightWall`, `TopCap` | `GapMarker` | Retained. The three colliders are the four-sided pinhole assembly, not duplicate walls. |
| 15 Sky Hook | `HookTower` | `LeftHookRoute` | Retained. One tower blocks the direct/high route; the marker suggests the curve side. |
| 16 Under and Around | `Overhead`, `LowBlocker` | `LowCurveRoute` | Retained. The two objects independently enforce low height and lateral bend. |
| 17 Moving Target | Moving goal assembly | `GoalTrack` | Retained. The track communicates the goal's deterministic motion and does not collide. |
| 18 Ricochet Run | `DirectBlocker`, `EasyBank`, `AdvancedBank` | Contrasting rebound faces | Retained. Two bank boards expose two real solutions rather than duplicate one route. |
| 19 Rhythm Gates | `BeatOne`, `BeatTwo`, `BeatThree` | Repeated scoreboard language | Retained. Three depth-separated gates are the authored three-beat challenge. |
| 20 Netbound Finale | `CrossSlider`, `LiftBar`, `FinalBeat`, `FrontShield` | Off-center goal framing and open right-side lane | Simplified. Removed `CurveTower`, which sat in front of `FrontShield` and repeated the same obstruction without adding a decision. |

## Level 20 Cleanup

`CurveTower` was a level-specific colliding `StaticBody3D` with a `3.6 x 5.4 x 1.0` box shape. Its stacked crash-pad wrapper visually covered the larger `FrontShield`, making two walls read as one cluttered pile. The verified route did not depend on contacting or passing a unique boundary created by the tower.

The cleanup removes the node and its material, mesh, and shape resources. It does not add a replacement. The remaining objects retain distinct ownership:

- `CrossSlider`: horizontal timing.
- `LiftBar`: low lift requirement.
- `FinalBeat`: final timed opening.
- `FrontShield`: strong curve and right-side enclosure entry.

The production mouse route still completes Level 20 and reports `right` as the scoring entry boundary. Course-art wrappers now total four, and every wrapper still derives its exact size and transform from its authoritative collider.

## Visual Evidence

- Before: `artifacts/rewarded-level-skip/before/levels/level_20.png`
- After: `artifacts/rewarded-level-skip/after/levels/level_20.png`
- Levels 01-20 baseline review: `artifacts/rewarded-level-skip/before/levels/`

## Verification

- `verify_level_clarity_audit_external.gd`: 20 scenes, documented course-collider counts, exact visual/collider size checks, duplicate-transform rejection, and the four-object Level 20 contract.
- `verify_environment_art_external.gd`: 34 course wrappers across all levels after cleanup; collision unchanged by runtime art.
- `verify_phase3_levels_external.gd`: production mouse-swipe completion `20/20`; Level 20 right-side entry retained.
- `verify_content_expansion_external.gd`: registry, moving-goal synchronization, production visuals, and version-2 migration passed.

No other collider was removed. Levels 09, 14, 18, and 19 contain multiple nearby objects because their authored mechanics require multiple timing planes, a bounded opening, alternate bank routes, or a three-beat sequence; the screenshot and collider audit found no duplicate decision in those arrangements.
