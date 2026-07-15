# Netbound Save Format

Phase 4 introduces versioned, offline-only local progression storage.

## Location

Default save files:

- Primary: `user://netbound_save.json`
- Temporary write file: `user://netbound_save.tmp`
- Backup: `user://netbound_save.bak`
- Corrupt diagnostic copy: `user://netbound_save.corrupt`

No personal information, online account data, analytics identifiers, cloud data, or real transaction receipts are stored. Monetization and economy data are local simulated state plus future consent-readiness placeholders.

## Version

Current `save_version`: `2`

Older or malformed versions are normalized into the current schema. Unknown future fields are preserved where practical, but gameplay only reads the documented fields below.

## Schema

```json
{
  "save_version": 2,
  "progression": {
    "unlocked_levels": ["level_01"],
    "completed_levels": [],
    "normal_completed_levels": [],
    "assisted_levels": [],
    "assisted_fulfillment_ids": [],
    "best_stars": {},
    "fewest_shots": {},
    "tutorial_completed": {},
    "total_stars": 0
  },
  "cosmetics": {
    "selected_ball": "ball_classic",
    "selected_trail": "trail_none",
    "selected_goal_effect": "goal_classic",
    "unlocked": ["ball_classic", "trail_none", "goal_classic"],
    "purchased": []
  },
  "settings": {
    "master_volume": 1.0,
    "music_volume": 1.0,
    "sfx_volume": 1.0,
    "haptics_enabled": true,
    "reduced_motion_enabled": false,
    "camera_effects_intensity": 1.0,
    "quality_tier": "auto",
    "developer_debug": false
  },
  "economy": {
    "arcade_coins": 0,
    "net_tokens": 0,
    "processed_transaction_ids": [],
    "transaction_history": [],
    "daily_rewarded_tokens": {
      "local_date": "",
      "completed_rewards": 0,
      "tokens_granted": 0
    },
    "first_completion_rewards": [],
    "rewarded_star_milestones": {},
    "rewarded_best_shots": {},
    "next_transaction_sequence": 1
  },
  "monetization": {
    "entitlements": [],
    "purchases": {
      "netbound_remove_ads": {
        "product_id": "netbound_remove_ads",
        "owned": false,
        "state": "not_purchased",
        "provider": "",
        "transaction_id": "",
        "last_updated_unix": 0.0
      },
      "netbound_starter_pack": {
        "product_id": "netbound_starter_pack",
        "owned": false,
        "state": "not_purchased",
        "provider": "",
        "transaction_id": "",
        "last_updated_unix": 0.0
      }
    },
    "config": {
      "ads_enabled": true,
      "purchases_enabled": true,
      "child_directed_treatment": false,
      "privacy_consent_status": "unknown",
      "personalized_ads_allowed": false
    }
  }
}
```

## Normalization

The save service validates every loaded save:

- `level_01` is always unlocked.
- Unknown level IDs are ignored.
- Completion results for locked levels are ignored by the save service.
- Completed levels remain completed and are forced unlocked.
- Normal and assisted completion IDs must also exist in `completed_levels`; a normal completion supersedes assisted status.
- Missing `normal_completed_levels` in an older version-2 save is seeded from its existing completed levels because assisted clears did not yet exist.
- Assisted fulfillment IDs are strings bounded to the most recent `256` entries.
- Completing a level unlocks its `next_level_id` when one exists.
- Stars are clamped to `0..3`.
- Fewest shots retain the historical `shot_limit + 1` normalization ceiling so version-2 saves produced before the extra-shot feature was retired remain lossless.
- `total_stars` is recalculated from `best_stars`.
- Registry expansion is monotonic: a valid existing Level 10 completion unlocks Level 11, while later levels remain sequentially locked.
- Missing progression, cosmetic, or settings fields are filled with defaults.
- Volumes are clamped to `0..1`.
- `quality_tier` normalizes to `auto`, `low`, `medium`, or `high`.
- Selected cosmetics fall back to defaults if they are not unlocked.
- Cosmetic IDs are validated against `CosmeticRegistry`.
- Purchased cosmetic IDs are limited to valid Coin/Token catalog items and imply unlock ownership.
- Currency balances clamp to non-negative 32-bit-safe integers.
- Daily rewarded counters clamp to five completions and ten Tokens.
- Processed transaction IDs and transaction history are bounded.
- Invalid entitlements and products are ignored.
- Owned products re-grant their matching entitlements during normalization.
- Starter Pack entitlement re-grants supporter cosmetics during normalization.
- Phase 4 legacy IDs such as `classic`, `ball:classic`, `trail:none`, and `goal_effect:classic` migrate into stable Phase 6 IDs.
- Unknown top-level fields are preserved where practical.

## Star Rules

Stars are calculated by `NetboundSaveService.calculate_stars_for_values()`:

- `3` stars: completed with `shots_used <= par_shots`
- `2` stars: completed with `shots_used == par_shots + 1`
- `1` star: completed within the valid allowance but worse than `par + 1`
- `0` stars: not completed or malformed result data

Compatibility rule:

- `LevelResult.rewarded_continue_used` remains a legacy runtime field so old fixtures load safely.
- New runs never set it, and star calculation ignores it.
- Save schema remains version `2`; no persisted wallet, progression, or cosmetic field changed when the extra-shot feature was retired.

If `par_shots` exceeds `shot_limit`, the service clamps the effective par to the shot limit and records a diagnostic.

## Atomic Write Flow

`NetboundSaveService.save()` writes safely:

1. Normalize the in-memory save data.
2. Serialize deterministic JSON with sorted keys.
3. Write to `user://netbound_save.tmp`.
4. Flush and close the temp file.
5. Move the existing primary save to `user://netbound_save.bak` when present.
6. Rename the temp file to `user://netbound_save.json`.
7. If replacement fails after backup creation, attempt to restore the backup.

Malformed JSON is copied to `user://netbound_save.corrupt`, then defaults are recreated and saved.

Phase 9 adds a dirty flag without changing the atomic write format:

- Successful saves clear the dirty flag.
- Failed writes leave the dirty flag set.
- `flush_if_dirty()` is called during mobile background and quit handling.
- Existing gameplay/progression/cosmetic/settings setters still save immediately, so no per-frame or debounced save writer was introduced.

Phase 9 did not require a version bump. The economy phase increases the version from `1` to `2` because it adds authoritative balances, reward ledgers, transaction IDs, and purchased cosmetic ownership. Version `1` migration seeds reward ledgers from existing progression so old completions/stars/bests are not paid again.

The 20-level content expansion also does not require a version bump. It changes registry content, not save shape. Version-2 normalization validates old level IDs against the expanded registry, preserves all prior results, unlocks Level 11 for a completed Level 10, and recalculates a maximum of `60` stars. Existing 6-30 star cosmetic milestones stay valid and monotonic; no retroactive economy rewards are created.

The rewarded level-skip phase also keeps save version `2`. Its three progression
arrays are optional, normalized fields rather than a reinterpretation of existing
balances, rewards, best shots, or ownership. Older version-2 completions normalize
as normal completions. Assisted clears store at least one best star but never
write `fewest_shots`; their bounded fulfillment IDs provide persistent duplicate
callback protection. A failed assisted write restores the full previous snapshot.

## Public API

Primary service: Autoload `SaveService`, script class `NetboundSaveService`.

Important methods:

- `load_or_create()`
- `save()`
- `is_level_unlocked(level_id)`
- `is_level_completed(level_id)`
- `is_level_normally_completed(level_id)`
- `is_level_assisted(level_id)`
- `get_best_stars(level_id)`
- `get_fewest_shots(level_id)`
- `get_total_stars()`
- `get_completed_level_count()`
- `record_level_result(level_result, level_definition)`
- `record_assisted_clear(level_id, level_definition, fulfillment_id)`
- `mark_tutorial_complete(level_id)`
- `is_tutorial_complete(level_id)`
- `reset_to_defaults()`
- `unlock_cosmetic(cosmetic_id)`
- `is_cosmetic_unlocked(cosmetic_id)`
- `get_unlocked_cosmetics()`
- `get_selected_cosmetic(category)`
- `set_selected_cosmetic(category, cosmetic_id)`
- `evaluate_cosmetic_unlocks()`
- `set_selected_ball(ball_id)`
- `set_selected_trail(trail_id)`
- `set_selected_goal_effect(effect_id)`
- `flush_if_dirty()`
- `is_dirty()`
- `get_last_successful_save_msec()`
- `unlock_all_cosmetics_for_development()`
- `reset_cosmetics_to_defaults_for_development()`
- `print_cosmetic_registry_validation()`
- `get_setting_value(setting_name, default_value)`
- `set_setting_value(setting_name, value)`
- `has_entitlement(entitlement_id)`
- `get_entitlements()`
- `get_monetization_config()`
- `is_product_owned(product_id)`
- `record_purchase(product_id, transaction_id, provider_name)`
- `restore_purchase(product_id, transaction_id)`

`reset_to_defaults()` is a development/testing reset hook. It is not exposed as a normal player button in Phase 4.

## Level Registry

`LevelRegistry` explicitly registers all production levels in order. It does not depend on directory enumeration.

Each entry contains:

- `level_id`
- scene path
- definition path

The registry validates:

- exactly 20 levels
- unique IDs
- existing scenes and definitions
- matching `LevelDefinition.level_id`
- sequential `next_level_id`
- empty next ID for Level 20

## Result Recording

`level_controller.gd` records progression only when a goal is scored:

1. Build a completed `LevelResult`.
2. Call `SaveService.record_level_result()`.
3. Calculate stars from the result and definition.
4. Preserve best-ever stars and fewest shots.
5. Mark completion permanently.
6. Unlock the next level if available.
7. Evaluate gameplay-earned cosmetic unlocks from completed levels and total best stars.
8. Save immediately.
9. Emit `progression_changed(update)`.

Failures, Retry, auto-reset, and manual Reset Ball do not alter progression.

Debug-script runs disable Autoload recording by default. Phase 4 tests explicitly configure isolated `user://phase4_*` paths before enabling recording.

## Phase 5 UI Integration

The Phase 5 Settings screen reads and writes the existing `settings` object through `SaveService`.

- `master_volume` is applied to Godot's `Master` audio bus when present.
- `music_volume` and `sfx_volume` are persisted and applied when matching buses exist.
- `haptics_enabled` is persisted for the later mobile feedback layer.
- `developer_debug` is exposed only in debug builds and toggles gameplay debug labels for levels loaded through the app shell.

No new save-version migration was required for Phase 5.

## Phase 7 Settings Integration

No save-version bump is required for Phase 7. The existing `settings` dictionary is normalized with safe defaults for missing keys:

- `reduced_motion_enabled`: default `false`
- `camera_effects_intensity`: default `1.0`, clamped to `0..1`

`AudioService` applies Master/Music/SFX/UI bus volumes from the existing volume fields. `HapticsService` applies `haptics_enabled`.

## Phase 6 Cosmetic Integration

No save-version bump was required for Phase 6 because the Phase 4 schema already had the needed cosmetic slots:

- one selected ball
- one selected trail
- one selected goal effect
- an unlocked cosmetic ID array

Phase 6 changes the values inside those fields to stable registry IDs. The loader migrates known Phase 4 placeholder IDs safely and filters invalid IDs. Selection can only be saved if the cosmetic is already unlocked.

Cosmetic categories:

- `ball`
- `trail`
- `goal_effect`

Stable default IDs:

- `ball_classic`
- `trail_none`
- `goal_classic`

Unlock evaluation is monotonic. Newly unlocked IDs are returned on `ProgressionUpdate.unlocked_cosmetic_ids` for the result screen, but existing unlocked cosmetics are not announced again.

## Phase 8 Monetization Integration

No save-version bump was required for Phase 8 because version `1` normalization already tolerates missing dictionaries and fills safe defaults. A Phase 7 save with no `monetization` block loads into the schema above.

Stable product IDs:

- `netbound_remove_ads`
- `netbound_starter_pack`

Stable entitlement IDs:

- `entitlement_remove_ads`
- `entitlement_starter_pack`

Starter Pack content:

- Remove Ads entitlement
- `ball_supporter`
- `trail_supporter`
- `goal_supporter`

Rules:

- Entitlements are monotonic.
- Purchase and restore calls save immediately.
- Duplicate provider callbacks and repeated restores are idempotent.
- Invalid saved selections fall back unless the matching supporter cosmetic is actually unlocked.
- Monetization config fields are local placeholders for future real-SDK consent/platform work and do not collect data.
