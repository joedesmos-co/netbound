# Netbound Presentation Architecture

Phase 7 presentation systems observe gameplay state and produce feel. They never decide gameplay outcomes, modify physics, alter scoring, or change progression.

## Audit Snapshot

Current production presentation before Phase 7:

- Audio: no final audio layer existed. Phase 5 applied volume sliders directly to buses only if those buses existed.
- Audio buses: only Godot's default `Master` bus existed before runtime setup.
- Particles: Level 01 base scene has `Goal/GoalParticles`; Phase 6 adds bounded trail points and transient cosmetic goal nodes.
- Camera: `prototype_controller.gd` owns setup framing, shot follow, and reset return behavior.
- UI transitions: Phase 5/6 screens were mostly instant, with a persistent `Fade` node unused for motion.
- Level materials: inherited Level 01 primitives plus per-level simple material overrides.
- Runtime allocations: Phase 6 cosmetics created ball materials when applying a skin and transient materials for goal effects.
- Debug visuals/logging: gameplay debug labels and goal volumes are hidden by default; debug logs print only when `developer_debug_enabled` is true.
- Mobile renderer: project uses the mobile renderer, so Phase 7 favors simple materials, bounded particles, small meshes, and reusable players.

## Ownership

Gameplay emits or calls semantic presentation events:

- `aim_started`
- `shot_fired`
- `ball_impact`
- `near_miss`
- `goal_scored`
- `result_shown`

Presentation observers may play audio, haptics, camera feedback, particles, transient visual nodes, and UI animation. They must not:

- apply forces
- change ball velocity
- change collision
- change goal detection
- delay authoritative goal registration
- mutate saved progression
- block gameplay input unexpectedly

## Services

### AudioService

Autoload: `/root/AudioService`
Script: `res://scripts/services/audio_service.gd`

Responsibilities:

- create and maintain `Music`, `SFX`, and `UI` buses
- load original generated WAV assets
- play music loops through one reusable music player
- play one-shots through bounded SFX/UI player pools
- enforce per-sound cooldowns for rapid impact spam
- apply saved Master/Music/SFX settings
- clean up one-shots on scene navigation

### HapticsService

Autoload: `/root/HapticsService`
Script: `res://scripts/services/haptics_service.gd`

Responsibilities:

- route semantic haptic events
- respect saved `haptics_enabled`
- no-op safely on unsupported desktop platforms
- rate-limit repeated impact haptics
- keep platform vibration calls out of gameplay scripts

### GameplayFeedback

Component: `GameplayFeedback`
Script: `res://scripts/presentation/gameplay_feedback_controller.gd`

The gameplay controller owns the stable shot calculation, then passes the current launch velocity and curve values to `GameplayFeedback` for developer diagnostics and release feedback only. Normal gameplay now presents one gesture-owned line from the ball through the active swipe samples. The redundant prediction dots, arrows, and numerical shot readout are hidden unless developer debug is enabled. The component creates:

- an optional developer-only bounded 14-dot launch preview derived from canonical values
- an optional developer-only shot readout for category, power, and curve strength
- visual-only ball anticipation and release squash/stretch on mesh children
- launch ring, impact, goal, and near-miss presentation hooks
- audio and haptic semantic event calls

The component never writes `linear_velocity`, collision shapes, ball mass, goal state, shot counts, progression, or save data.

### CameraFeedback

Component: child of `GameplayFeedback`
Script: `res://scripts/presentation/camera_feedback.gd`

`CameraFeedback` returns a deterministic per-frame offset for shot, impact/post, and goal events. `prototype_controller.gd` applies it after normal camera follow and subtracts the previous offset before the next smoothing step, so feedback does not drift the authored setup framing. Reset, Retry, and level unload clear all camera feedback state.

### Near Miss Presentation

Near-miss feedback is presentation-only and lives in `level_controller.gd`. It may fire once per active shot when:

- the shot is still the active generation
- the level is not already in `GOAL`
- the ball is close to the registered goal plane
- the ball is just outside a post or just over the crossbar

Post/crossbar impacts can also request the same guarded feedback. Valid swept goal detection still resolves first and remains authoritative.

### LevelVisualPolish

Component: `LevelVisualPolish`
Script: `res://scripts/presentation/level_visual_polish.gd`

Each production level creates one visual-only polish node at runtime. It owns:

- per-level environment colors and directional light color/energy
- shared material language for fields, goals, nets, static blockers, gates, route hints, and bounce surfaces
- non-colliding arena trim, route rails, field stripes, and backdrop meshes
- one visual-only contact shadow that follows the ball
- a goal frame pulse that layers with the selected cosmetic goal effect

Goal-frame base materials remain neutral white in every level. Celebration color and shape live in transient visual-only effect roots, so the playable opening stays familiar and readable.

The component only assigns material overrides or creates `MeshInstance3D` children in the `netbound_visual_polish` group. Regression tests assert those nodes include no `CollisionObject3D` instances and that `GoalTarget` geometry remains synced.

Phase 9 quality tiers can disable decorative geometry, contact shadows, and dynamic shadows through `apply_quality_settings(config)`. These changes are visual-only and do not alter level geometry, collision, moving obstacle timing, or scoring geometry.

### UI Motion

`NetboundApp` owns screen and modal motion. It adds:

- short screen fade-ins for Main Menu, Level Select, Settings, and Cosmetics
- modal fade/scale on Pause and Results
- small button press scale feedback
- staggered result/card/button reveal where practical

Reduced Motion and headless runs skip these tweens. UI animations do not disable controls or own navigation results; the existing navigation lock still prevents double navigation.

## Settings

Phase 7 extends the existing version `1` settings dictionary with:

- `reduced_motion_enabled`
- `camera_effects_intensity`

No save-version bump is required because settings normalization already accepts missing keys and supplies defaults.

## Budgets

Initial presentation budgets:

- SFX players: 10
- UI players: 4
- Music players: 1
- trail points per ball: 16
- cosmetic celebration pieces: base maximum `38` on High, quality-scaled on lower tiers
- cosmetic goal-effect roots: maximum `3` for Goal Portal; all other effects use `1-2`
- cosmetic goal-effect lifetime: `0.52-1.36` seconds plus bounded cleanup
- aim preview dots per active level: 14
- gameplay camera feedback: one reusable component per level
- launch rings/near-miss labels: transient and cleared on Reset/Retry
- level visual polish nodes per level: at most 24, zero collision objects
- contact shadows: one mesh per level
- active UI tweens: transient and killed on screen/gameplay overlay clear
- impact cooldown: 0.08-0.14 seconds depending on type
- cached ball skin/detail materials and procedural detail meshes; attachments rebuild only when a skin is applied
- no unbounded presentation arrays
- no production debug spam

Phase 9 quality budgets:

- Low: decorative level geometry off, contact shadows off, dynamic shadows off, trail limit `8`, particle multiplier `0.45`.
- Medium: decorative geometry on, contact shadows on, dynamic shadows off, trail limit `12`, particle multiplier `0.7`.
- High: decorative geometry on, contact shadows on, dynamic shadows on, trail limit `16`, particle multiplier `1.0`.
- Auto: Medium on mobile feature builds, High on desktop development builds.

Later presentation work must keep these budgets current as any final QA instrumentation is added.

## Physical Checks Still Required

Headless and desktop-visible checks cannot prove physical mobile feel. iOS and Android hardware still need validation for:

- touch comfort
- audio focus behavior
- device volume/headphone behavior
- haptic feel
- safe areas
- thermal/performance behavior

## Phase 7 Profiling Snapshot

Desktop/headless instrumentation checks currently verify:

- SFX player pool: `10`
- UI player pool: `4`
- music players: `1`
- trail points per active ball: `16`
- aim preview dots per active level: `14`
- level polish visual nodes per production level: `<= 24`
- level polish collision objects: `0`
- cosmetic confetti pieces: `24`
- shockwave nodes: `1`
- material reuse: repeated ball skin and same-trail refreshes reuse existing materials
- cleanup: Reset/Retry/unload clears camera feedback, goal pulses, cosmetic effects, and UI tweens

This is not a substitute for physical mobile profiling. GPU cost, thermal behavior, safe-area comfort, haptic feel, and audio focus still need iOS/Android hardware validation in the mobile hardening/release phase.
