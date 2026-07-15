# Netbound Content Expansion

Date: 2026-07-15
Engine: Godot `4.7.stable.official.5b4e0cb0f`

## Scope

This pass responds to production-play feedback without changing the canonical launch model, ball physics, star rules, wallet rules, or simulated provider boundaries. It expands the authored route from 10 to 20 levels and keeps save version `2`.

## Arcade Goal Model

`GoalTarget` owns the visible goal and one shared scoring enclosure. `GoalDetector` performs swept previous-to-current segment checks against four configured boundaries:

- front boundary: valid inward entry
- left boundary: valid entry into the enclosure
- right boundary: valid entry into the enclosure
- rear boundary: explicitly invalid

A candidate crossing scores only when the segment moves from outside to inside the enclosure through a valid boundary and the crossing point fits the configured width, height, depth, and ball-radius allowances. A shot ID and one-shot latch prevent duplicate goals. Fully outside passes and rear approaches are rejected. Goal registration still occurs before final-shot failure resolution.

Developer-debug mode can show the enclosure; normal gameplay does not render scoring helpers.

## Motion Model

`MovingObstacle` and `TimedGate` use elapsed physics phase rather than cycle Tweens. Their transforms are derived continuously from normalized phase time, so 30/60 FPS samples follow the same path. Retry restores exact start phase and position. Pause stops physics progression and Resume continues the same phase.

`MovingObstacle.target_path` allows one controller to move a composed target. Level 17 uses this to move the complete `GoalTarget`; detector geometry synchronizes from the goal's current global transform before each swept scoring query.

## Aiming And UI

Normal gameplay renders one gesture-owned `Line2D` from the ball through the active swipe samples. The dotted prediction, arrow, and duplicate guide are hidden outside developer debug. The line clears on release, cancel, pause, focus loss, reset, and retry.

Player-facing copy was shortened, low-contrast states received explicit backing/foreground colors, and the late-level environment palette remains bright and playful. Goal frames are always neutral white; level mechanic color belongs to obstacles and celebration effects, never the frame.

## Cosmetic Quality

The 38-item registry remains authoritative. All 18 balls retain the same `0.49` collision radius and reference sphere while using bounded visual-only panel/concept layers. Early Common/Rare items include recognizable soccer variants; later Rare/Epic/Legendary items use distinct concepts such as watermelon, cloud, comet, lava core, prism, void, and champion treatments.

Trails differ by shape/motion as well as color. All eight goal effects use distinct 1-2 second, goal-anchored silhouettes with quality-tier node caps and complete cleanup. See `docs/COSMETIC_VISUAL_AUDIT.md`.

Acquisition distribution remains:

| Route | Count | Share |
| --- | ---: | ---: |
| Direct level/star gameplay | 10 | 26.3% |
| Arcade Coins | 12 | 31.6% |
| Net Tokens | 8 | 21.1% |
| Supporter entitlement | 3 | 7.9% |
| Major achievement | 2 | 5.3% |
| Defaults | 3 | 7.9% |

Coins are earned through play, so more than half the catalog is available without a real-money purchase. Existing ownership and prices are unchanged.

## Levels 11-20

| Level | Intended solution |
| --- | --- |
| 11 Side Door | Use a mild curve around the front shield and enter the right side of the net enclosure. |
| 12 Elevator | Wait for the vertical blocker to expose the lane, then use a controlled driven shot. |
| 13 Cross Traffic | Read the two horizontal movers and release through their shared opening. |
| 14 Pinhole | Use a short centered driven shot through the clearly framed gap. |
| 15 Sky Hook | Lift wide and curve around the tall blocker. |
| 16 Under And Around | Stay under the overhead geometry and add mild curve around the side block. |
| 17 Moving Target | Lead the smoothly translating goal; visual and scoring geometry move together. |
| 18 Ricochet Run | Bank from either bright side wall; both routes are visible. |
| 19 Rhythm Gates | Release into the repeating three-gate shared window. |
| 20 Netbound Finale | Read the opening beat, add moderate lift and curve, and enter through the side enclosure. |

The external Phase 3 suite completes all 20 scenes through production mouse-swipe input. It additionally asserts a `right` entry boundary for Levels 11 and 20.

## Save Compatibility

No schema change is required. `LevelRegistry` now contains 20 entries and `total_stars` is recalculated from valid best-star records for a maximum of 60. During normal version-2 normalization:

- existing completion, stars, wallet balances, cosmetics, entitlements, and reward ledgers remain intact
- a completed Level 10 unlocks Level 11
- Level 12 remains locked until Level 11 is completed
- existing 30-star cosmetic milestones remain unlocked and are never revoked
- Level 20 has no next level

This behavior is covered by `verify_content_expansion_external.gd` with an isolated legacy version-2 fixture.

## Verification Outcome

Final local matrix:

- Godot 4.7 headless editor import: passed
- configured production app startup: passed
- strict parser sweep: `68/68` GDScripts passed
- direct production scene startup: `20/20` passed
- retained behavioral matrix: `27/27` external scripts passed
- all script/scene logs: zero matched parser errors, runtime errors, Godot warnings, ObjectDB leaks, or console spam
- visible Forward Mobile captures: passed on Apple M4 Metal
- responsive Level Select captures: all six required sizes rendered at exact native dimensions
- Android debug APK: passed, signed, 28 MB, SHA-256 `618d986543abb0493d8000ffde8a887bfd7ea5cf199f22c72d88b351ae00b806`
- Android debug AAB: passed from an isolated template copy, structurally valid, 28 MB, SHA-256 `05223e3916083abe88a2ddd3e4d774147709c9bd6cf2043716e4d2b618726d69`
- `git diff --check`: passed before final commit

The combined template-install/export process emitted Godot's known scan-abort exit warning in the temporary copy. Re-exporting from the fully installed temporary template completed with zero Godot warnings. `apksigner` emitted a Java native-access deprecation warning from Android build-tools 36 while still verifying APK v2/v3 signatures with one signer. The debug AAB is intentionally unsigned, as documented for this local development preset.

Verification logs:

- parser: `/tmp/netbound-content-parser.7uEh1Q`
- level startup: `/tmp/netbound-content-levels.gSNR3e`
- regressions: `/tmp/netbound-content-regressions.5NcYXy`
- Android artifacts: `/tmp/netbound-content-expansion-exports-20260715/`

## Visual Evidence

Current screenshots are stored under:

- `artifacts/content-expansion/before/`
- `artifacts/content-expansion/final/`
- `artifacts/content-expansion/levels/final/`
- `artifacts/content-expansion/ui/`
- `artifacts/content-expansion/responsive/`

Representative final captures include Level 11 side-entry setup, Level 12's elevator, Level 14's precision gap, Level 17's moving goal, Level 20's final route, the 20-marker Level Select, and the 60-star final result.

## Physical Device Work

Desktop/native Metal and headless checks cannot certify touchscreen feel, safe-area behavior, thermal stability, haptic strength, audio focus, or sustained 30/60 FPS motion on physical iOS/Android hardware. Those checks remain in `docs/MOBILE_RELEASE_CHECKLIST.md`.
