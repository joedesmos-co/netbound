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

The gameplay controller owns the stable shot calculation, then passes the current launch velocity and curve values to `GameplayFeedback` for display only. The component creates:

- a bounded 14-dot aim preview derived from the current canonical launch values
- a bottom shot readout for category, power, and curve strength
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
- cosmetic confetti pieces: 24
- cosmetic shockwave rings: 1 transient node
- aim preview dots per active level: 14
- gameplay camera feedback: one reusable component per level
- launch rings/near-miss labels: transient and cleared on Reset/Retry
- impact cooldown: 0.08-0.14 seconds depending on type
- no unbounded presentation arrays
- no production debug spam

Later Phase 7 subsystems must keep these budgets current as UI motion, world polish, and level presentation are added.

## Physical Checks Still Required

Headless and desktop-visible checks cannot prove physical mobile feel. iOS and Android hardware still need validation for:

- touch comfort
- audio focus behavior
- device volume/headphone behavior
- haptic feel
- safe areas
- thermal/performance behavior
