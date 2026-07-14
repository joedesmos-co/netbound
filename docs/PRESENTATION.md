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
- impact cooldown: 0.08-0.14 seconds depending on type
- no unbounded presentation arrays
- no production debug spam

Later Phase 7 subsystems must keep these budgets current as camera, UI, near-miss, and level polish are added.

## Physical Checks Still Required

Headless and desktop-visible checks cannot prove physical mobile feel. iOS and Android hardware still need validation for:

- touch comfort
- audio focus behavior
- device volume/headphone behavior
- haptic feel
- safe areas
- thermal/performance behavior
