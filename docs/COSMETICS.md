# Netbound Cosmetics

Phase 6 implements offline, gameplay-earned cosmetics. Cosmetics are visual-only and must never alter ball physics, collision, scoring, shot tuning, camera behavior, level unlocks, or star calculation.

## Registry

The authoritative registry is `res://scripts/cosmetics/cosmetic_registry.gd`.

Each definition includes:

- `cosmetic_id`
- `display_name`
- `category`
- `description`
- `unlock_requirement`
- `preview_color`
- `sort_order`
- `is_default`
- `default_unlocked`

The registry validates unique IDs, valid categories, one default per category, and valid unlock requirements. Gameplay resources are procedural, so there are no external texture or scene paths to resolve.

## IDs

Ball skins:

- `ball_classic`
- `ball_neon`
- `ball_fire`
- `ball_ice`
- `ball_galaxy`
- `ball_gold`

Trails:

- `trail_none`
- `trail_blue`
- `trail_flame`
- `trail_spark`
- `trail_rainbow`

Goal effects:

- `goal_classic`
- `goal_confetti`
- `goal_shockwave`

## Unlocks

Defaults:

- Classic Ball
- No Trail
- Classic Goal Flash

Gameplay milestones:

| Requirement | Unlocks |
| --- | --- |
| Complete Level 2 | Neon Ball |
| Complete Level 4 | Blue Streak Trail |
| Complete Level 6 | Ice Ball |
| Complete Level 8 | Spark Trail |
| Complete Level 10 | Galaxy Ball |
| Earn 6 total stars | Fire Ball |
| Earn 12 total stars | Flame Trail |
| Earn 18 total stars | Confetti Goal Effect |
| Earn 24 total stars | Rainbow Trail |
| Earn 30 total stars | Gold Ball, Shockwave Goal Effect |

Unlocks are monotonic. Worse replays cannot remove cosmetics, and repeated evaluation does not duplicate IDs.

## Save Flow

`SaveService` stores:

- `selected_ball`
- `selected_trail`
- `selected_goal_effect`
- `unlocked`

No save-version bump was required because Phase 4 already had these fields. Phase 6 migrates legacy placeholder values such as `classic`, `ball:classic`, and `trail:none` into stable registry IDs.

Selection rules:

- locked cosmetics cannot be selected
- invalid saved IDs fall back to category defaults
- one selected item is stored per category
- selection saves immediately
- previewing a locked item never saves

## Gameplay Flow

`level_controller.gd` refreshes selected cosmetics from `/root/SaveService` on ready, reset, retry, and goal feedback.

- Ball skins use material overrides on existing visual mesh children.
- Trails use `NetboundBallTrail`, a bounded visual-only child node with no physics interaction.
- Goal effects trigger from `_show_goal_feedback()` after valid scoring and are cleared on retry, unload, and navigation.

## Preview Flow

The Cosmetics screen uses `NetboundCosmeticPreview`, a lightweight `SubViewport` with a dummy ball and goal. It does not load a production level. Previewing can show locked items, but only the Equip button can save an unlocked selection.

## Performance Constraints

- No per-frame material allocation.
- Trail point count is fixed.
- Goal effect nodes are transient and self-cleaning.
- No external copyrighted assets or textures.
- Transparency and particles are kept modest for the mobile renderer.

## Developer Utilities

Developer-only methods on `SaveService`:

- `unlock_all_cosmetics_for_development()`
- `reset_cosmetics_to_defaults_for_development()`
- `print_cosmetic_registry_validation()`

These actions are not exposed in normal production UI and never run automatically.
