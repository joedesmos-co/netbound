# Netbound Environment Art

Audit date: 2026-07-15
Direction: Trajectory Playground training equipment

## Problem Audit

The production levels were mechanically readable but most hazards exposed one
unarticulated `BoxMesh`. Color alone separated a gate from a wall, large challenges
looked like collision layouts, and adding several differently colored boxes made
Levels 10 and 20 read as unrelated parts rather than one course.

The first replacement draft added many small indicators and mixed-color pads. It
improved differentiation but became noisy when several obstacles overlapped. That
direction was rejected. The final kit uses fewer, larger details and one physical
construction language.

## Object Vocabulary

All course equipment uses a restrained real-world training palette:

- dark navy: steel/rubber frames and protective edging
- off-white: canvas, board faces, and high-contrast markings
- coral: safety padding and barricade stripes
- teal: moving scoreboard faces and rebound surfaces
- yellow: motion tracks and rotating-hazard markings only

Reusable archetypes:

- **Padded target blocker:** navy frame, one coral safety pad, white target ring.
- **Moving scoreboard panel:** navy frame, teal board face, one white motion track.
- **Rotating training barrier:** navy bar, alternating white/yellow barrier panels,
  octagonal coral hub.
- **Rebound board:** navy frame, teal impact face, one broad white rebound mark.
- **Crash-pad stack:** navy frame with one or three separate coral mats.
- **Training barricade:** navy frame, off-white face, three restrained coral safety
  stripes.

These are recognizable pieces of an arcade soccer training course. They avoid
logos, characters, text decals, and one-off novelty objects.

## Runtime Architecture

`NetboundArcadeCourseArt` is created by `LevelVisualPolish` after scene setup. It:

1. discovers collision-backed obstacle `StaticBody3D` nodes
2. leaves the authoritative `CollisionShape3D`, body transform, scripts, physics
   material, timing, and reset state untouched
3. hides only the original direct `MeshInstance3D`
4. adds an exact-size visual base plus inset face details as children of the same
   collision body
5. lets moving/rotating visuals inherit the authoritative body transform directly

No visual wrapper contains a collision object. Goal frames and nets are excluded,
so their shared `GoalTarget` geometry and white frame language remain authoritative.
The inherited off-course prototype obstacle remains available as a compatibility
collider but its obsolete red marker mesh is hidden in production presentation.

Meshes and materials are cached per level setup and never created per frame. High
quality uses secondary markings. Low quality keeps the exact visual base and the
essential face that identifies each object, while hiding smaller secondary marks.

## Level Review

| Level | Previous primitive read | Production object replacement | Readability and collision contract |
|---|---|---|---|
| 01 | Open yard; inherited side placeholder | No course wrapper | Keeps the intentionally open teaching route. |
| 02 | Large cyan moving box | Hanging moving scoreboard panel | Dark frame separates the panel from the white goal; exact gate box retained. |
| 03 | Two plain wall boxes | Paired training barricades | Matching framed partitions make the central gap explicit. |
| 04 | Single red block | Padded target blocker | One clear target-pad silhouette supports curve routing. |
| 05 | Wide red barrier | Wide safety crash pad | One framed pad communicates a harmless object to lift over. |
| 06 | Elevated box | Padded overhead hurdle | Low route remains visually open; exact underside retained. |
| 07 | Thin rotating cuboid | Striped rotating training barrier | Octagonal hub and barrier marks advertise rotation without enlarging the collider. |
| 08 | Red block and cyan wall | Target pad and framed rebound board | Rebound face is distinct from the direct blocker; both verified bank routes remain. |
| 09 | Two cyan moving boxes | Two matching scoreboard gates | Shared construction language makes timing phases easy to compare. |
| 10 | Three unrelated colored boxes | Target pad, low crash pad, scoreboard gate | Fewer colors make the lift/curve/timing sequence parse as one course. |
| 11 | Large coral wall | Framed street-course barricade | White face and coral safety stripes leave the side-net route readable. |
| 12 | Cyan elevator box | Framed elevator scoreboard | Existing yellow guide rails remain; the moving panel reads as one mechanism. |
| 13 | Two colored moving boxes | Paired moving scoreboard panels | Consistent frames clarify cross-traffic timing. |
| 14 | Three plain precision blocks | Two barricades and a crash-pad cap | The pinhole remains unchanged and visually bounded by related equipment. |
| 15 | Tall colored tower | Stack of coral crash mats | Separate mat faces communicate height without changing tower silhouette. |
| 16 | Overhead and low boxes | Overhead crash pad and target blocker | Low-and-around route remains unobstructed and easy to infer. |
| 17 | Moving goal plus flat track | White moving goal retained | Goal visuals/scoring stay synchronized and are deliberately not wrapped. |
| 18 | Blocker and two cyan walls | Target pad and two rebound boards | Both bank options use one rebound language; collision angles remain authored. |
| 19 | Three colored gate boxes | Three rhythm scoreboard panels | Matching faces emphasize phase rhythm rather than color guessing. |
| 20 | Four meaningful finale objects after clarity cleanup | Barricade and scoreboard/lift equipment | The redundant crash-mat `CurveTower` was removed; timing, lift, curve, and right-side entry remain readable and intact. |

## Verification And Budgets

`verify_environment_art_external.gd` instantiates all 20 production scenes and
checks the scene collision signature before and after `_ready`. Current result:

- wrapped course obstacles: `34`
- reusable archetypes represented: `6/6`
- maximum course-art visual nodes in one level: `19`
- shared material resources per level: `7`
- new collision nodes: `0`
- all visual bases equal the paired `BoxShape3D.size`
- Low quality retains essential object identity and hides secondary details
- all course-art nodes clean up with their scene
- all 20 production swipe routes still complete

## Visual Evidence

Before captures: `artifacts/player-feel/pass4/before/`
Final captures: `artifacts/player-feel/pass4/final/`

The final set includes Levels 01, 02, 05, 07, 10, 11, 12, 17, and 20, a rebound
example, Low-quality examples, a 4:3 capture, and a wide-phone capture.

## Remaining Device Work

- verify material readability under physical OLED/LCD brightness ranges
- verify Low-quality readability and frame pacing on representative Android hardware
- inspect moving-object silhouette clarity on small phones at arm's length
- confirm no device-specific Metal/Vulkan material or depth-sorting issue
