# Netbound Visual Declutter Audit

Date: 2026-07-29  
Scope: obstacle-kit simplification, world-deck reductions, level composition polish  
Constraint: presentation-only. No new levels, mechanics, currencies, cosmetics, ads, billing, or cloud.

## Main Clutter Problems

Before this pass, production levels read as kit-bashed training sets:

1. **Obstacle faces stacked detail** — rings, hubs, bolts, triple stripes, dual-side marks, and track+marker pairs on every archetype.
2. **Foreground world props** — five cyan cones across the ball’s near field competed with the ball silhouette.
3. **Busy field graphics** — nine field stripes plus corridor route rails doubled the ground noise.
4. **Stadium goal occlusion** — centered scoreboard and stacked stand layers sat behind the goal and competed with the white frame.
5. **Too many accents per object** — navy + coral + canvas + yellow often appeared on one collider silhouette.

## Obstacle-Kit Simplifications

`NetboundArcadeCourseArt` archetypes now use one silhouette, one primary face material, and at most one accent:

| Archetype | Before | After |
| --- | --- | --- |
| Padded blocker | Frame + pad + ring + center disc | Frame + coral face |
| Sliding panel | Frame + face + track + yellow marker | Frame + teal face + one yellow motion stripe |
| Training spinner | Frame + five stripes + hub + bolt | Frame + three stripes + one hub |
| Stacked tower | Frame + one or three mats | Frame + one pad, or two mats when tall |
| Training partition | Frame + face + three coral stripes | Frame + canvas face + one coral stripe |
| Rebound board | Frame + dual faces + dual marks | Frame + dual impact faces only |

Shared materials remain navy / canvas / coral / teal / yellow. Individual objects do not consume the full five-color set.

Course-art budgets after declutter: **52 wrappers**, **max 15 visual nodes** per level course kit, **0 collision descendants** inside wrappers, materials ≤ 8.

## World-Background Reductions

Shared deck:

- Field stripes **9 → 5**
- Removed corridor **RouteRails**
- Softened arena rails and side trim

Training Yard:

- Banners **4 → 2** (side-only)
- Cones **5 foreground → 2** far sideline markers
- Fence retained as a single distant band

Street Arcade:

- Wall stripes **3 → 1** centered band
- Court rails retained, slightly quieter

Stadium Showdown:

- Removed centered **ScoreboardFace** behind the goal
- Removed stacked **UpperDeck**
- Flags **3 → 2**, offset to the sides
- Floodlights moved wider/higher
- Added side **crowd wings** for depth without crossing the goal sightline

## Level-By-Level Composition Notes

Collision layouts, moving paths, and GoalTarget scoring geometry were not edited. Composition gains come from kit + deck + quieter authored route materials.

| Levels | Main mechanic | Visual change |
| ---: | --- | --- |
| 01–03 | open / timing / gap | Fewer stripes; no foreground cones; quieter framing |
| 04–06 | curve / lift / overhead | Blocker/tower faces lose rings and extra mats |
| 07–10 | spinner / bank / combo | Spinner and gates read as one panel language |
| 11–14 | side door / elevator / traffic | Partition and gate accents reduced |
| 15–17 | sky hook / open timing | Tall pads use two mats max; Low quality keeps essential faces |
| 18–20 | street finale combo | Moving panels: one motion stripe; no track stack |
| 21–24 | stadium intro set | Side stands/flags replace goal-centered scoreboard |
| 25–29 | precision / banks / rhythm | Same collider routes; quieter faces and decks |
| 30 | Grand Final | Dedicated composition pass below |

## Level 30 Grand Final

Retained authoritative objects: `CrossSlider`, `LiftBar`, `FinalBeat`, `FrontShield`, side-entry goal.

Visual drama now comes from:

- simplified partition + gate faces
- stadium side depth and flags without a goal-blocking scoreboard
- fewer field stripes
- quieter route marks

Verified Phase 3 completion route retained (right-side entry after timing/lift).

## Palette And Material Restraint

- White goals remain white with success emission unchanged.
- Route marks use lower alpha and non-emissive materials.
- Training side trim softened away from neon cyan.
- Moving hazards stay teal + yellow stripe; static pads stay coral; partitions stay canvas + one coral stripe.
- Coral is not used as ordinary success feedback.

## Collision Verification

Environment-art harness compared pre/post polish collision signatures for all 30 levels:

- collider transforms unchanged
- wrapper base size equals `BoxShape3D`
- no decorative collision added
- Phase 3: all 30 production swipe routes PASS
- World expansion + Phase 7 budgets PASS

## Screenshot Evidence

Root: `artifacts/visual-declutter/`

| Set | Path |
| --- | --- |
| Before | `artifacts/visual-declutter/before/levels/level_{01,05,10,11,15,20,21,25,30}.png` |
| After / final | `artifacts/visual-declutter/final/levels/` and `after/levels/` |
| Low quality | `artifacts/visual-declutter/after/quality/low_level_{01,15,30}.png` |
| Viewports | `artifacts/visual-declutter/after/viewports/` |
| Level Select | `artifacts/visual-declutter/final/ui/level_select.png` |
| Level 30 wide | `artifacts/visual-declutter/final/levels/level_30_2340x1080.png` |

## Tests And Exports

- Parser sweep: 75/75
- Configured startup: PASS
- 30/30 scene startups: PASS
- Phase 3 routes: PASS
- Environment art / world expansion / Phase 7: PASS
- Rewarded skip / economy / economy RC / goal detection / final RC flow / player feel / level clarity: PASS
- Phase 9: PASS (known safe-area harness script errors on freed level-grid controls; pre-existing)
- Android debug APK: `/tmp/netbound-visual-declutter-exports-20260729/netbound-debug.apk`
- Android debug AAB: same export directory (isolated template path)

## Remaining Limitations

- Stadium identity is still primitive geometry, not dense crowd meshes.
- Authored yellow lift/route markers (for example Level 05 `TopMarker`) remain where they communicate the intended line.
- Capture harnesses must use the `complete` fixture for mid/late levels; world-only fixtures unlock only the next level after the fixture cutoff.
- Physical-device beta preparation is intentionally not started.

## Physical-Device Checks Remaining

- Install APK on a representative Android phone; confirm silhouette readability outdoors.
- Confirm Low quality still feels intentional on mid-range GPUs.
- Confirm side-entry openings remain obvious under real glare and finger occlusion.
- iOS device install once signing/team IDs are available.
