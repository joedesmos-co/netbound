# Netbound Cosmetics

Phase 6 implements offline gameplay cosmetics. The economy phase expands the same visual-only system with Coin and Token purchases while preserving Phase 8 supporter entitlements. Cosmetics must never alter ball physics, collision, scoring, shot tuning, camera behavior, level unlocks, or star calculation.

## Registry

The authoritative registry is `res://scripts/cosmetics/cosmetic_registry.gd`.

Each definition includes:

- `cosmetic_id`
- `display_name`
- `category`
- `description`
- `unlock_requirement`
- `rarity`
- `acquisition_method`
- `coin_price`
- `token_price`
- `preview_color`
- `preview_resource`
- `gameplay_visual_resource`
- `visual_style`
- `sort_order`
- `is_default`
- `default_unlocked`

The registry validates unique IDs, valid categories and rarities, one default per category, acquisition/price combinations, unlock requirements, and referenced procedural resources. The launch catalog contains 38 items; the complete table is in `docs/CURRENCY_PRODUCTS.md`.

## IDs

Ball skins:

- `ball_classic`
- `ball_neon`
- `ball_fire`
- `ball_ice`
- `ball_galaxy`
- `ball_gold`
- `ball_supporter`
- `ball_candy`, `ball_mint`, `ball_watermelon`, `ball_sunset`, `ball_checker`, `ball_cloud`
- `ball_comet`, `ball_lava`, `ball_prism`, `ball_void`
- `ball_champion`

Trails:

- `trail_none`
- `trail_blue`
- `trail_flame`
- `trail_spark`
- `trail_rainbow`
- `trail_supporter`
- `trail_chalk`, `trail_bubble`, `trail_streamers`
- `trail_comet`, `trail_pixel`, `trail_starfall`

Goal effects:

- `goal_classic`
- `goal_confetti`
- `goal_shockwave`
- `goal_supporter`
- `goal_ribbons`, `goal_splash`, `goal_fireworks`, `goal_portal`

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
| Own Starter Pack | Supporter Ball, Supporter Trail, Supporter Burst |

Unlocks are monotonic. Worse replays cannot remove cosmetics, and repeated evaluation does not duplicate IDs.

## Save Flow

`SaveService` stores:

- `selected_ball`
- `selected_trail`
- `selected_goal_effect`
- `unlocked`
- `purchased`

Save version `2` adds purchased ownership while preserving selection and unlocked arrays. Phase 6 legacy IDs still migrate into stable registry IDs. Starter Pack entitlement still unlocks its three supporter IDs; Coin/Token purchase ownership is committed atomically with wallet deduction.

Selection rules:

- locked cosmetics cannot be selected
- invalid saved IDs fall back to category defaults
- one selected item is stored per category
- selection saves immediately
- previewing a locked item never saves
- supporter cosmetics cannot be selected until `entitlement_starter_pack` exists
- Coin/Token catalog items cannot be selected until purchased

## Phase 8 Supporter Cosmetics

Supporter cosmetics are entitlement-locked rather than gameplay-earned:

- `ball_supporter`: teal-and-gold Supporter ball
- `trail_supporter`: restrained teal/gold trail
- `goal_supporter`: Supporter Burst goal effect

The Cosmetics screen may preview them while locked and shows “Own the Starter Pack” as the requirement. The Open Store button is shown only for locked entitlement cosmetics. Previewing does not save a selection; equipping still goes through the same unlocked-item save path as gameplay cosmetics.

## Gameplay Flow

`level_controller.gd` refreshes selected cosmetics from `/root/SaveService` on ready, reset, retry, and goal feedback.

- Ball skins use material overrides on existing visual mesh children.
- Trails use `NetboundBallTrail`, a bounded visual-only child node with no physics interaction.
- Goal effects trigger from `_show_goal_feedback()` after valid scoring and are cleared on retry, unload, and navigation.
- Phase 7 level presentation may add lighting/material context around the ball, but cosmetics remain the only system that changes ball visual skin/trail selection.

## Preview Flow

The Cosmetics screen uses `NetboundCosmeticPreview`, a lightweight `SubViewport` with a dummy ball and goal. It does not load a production level. Previewing can show locked items, but only the Equip button can save an unlocked selection.

## Performance Constraints

- No per-frame material allocation.
- Ball skin materials are cached by stable cosmetic ID.
- Reapplying the same selected trail resets the trail without rebuilding its materials.
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
