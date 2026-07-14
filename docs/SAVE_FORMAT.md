# Netbound Save Format

Phase 4 introduces versioned, offline-only local progression storage.

## Location

Default save files:

- Primary: `user://netbound_save.json`
- Temporary write file: `user://netbound_save.tmp`
- Backup: `user://netbound_save.bak`
- Corrupt diagnostic copy: `user://netbound_save.corrupt`

No personal information, online account data, analytics identifiers, purchases, or ad data are stored.

## Version

Current `save_version`: `1`

Older or malformed versions are normalized into the current schema. Unknown future fields are preserved where practical, but gameplay only reads the documented fields below.

## Schema

```json
{
  "save_version": 1,
  "progression": {
    "unlocked_levels": ["level_01"],
    "completed_levels": [],
    "best_stars": {},
    "fewest_shots": {},
    "tutorial_completed": {},
    "total_stars": 0
  },
  "cosmetics": {
    "selected_ball": "classic",
    "selected_trail": "none",
    "selected_goal_effect": "classic",
    "unlocked": ["ball:classic", "trail:none", "goal_effect:classic"]
  },
  "settings": {
    "master_volume": 1.0,
    "music_volume": 1.0,
    "sfx_volume": 1.0,
    "haptics_enabled": true,
    "developer_debug": false
  }
}
```

## Normalization

The save service validates every loaded save:

- `level_01` is always unlocked.
- Unknown level IDs are ignored.
- Completion results for locked levels are ignored by the save service.
- Completed levels remain completed and are forced unlocked.
- Completing a level unlocks its `next_level_id` when one exists.
- Stars are clamped to `0..3`.
- Fewest shots are clamped to the level shot limit.
- `total_stars` is recalculated from `best_stars`.
- Missing progression, cosmetic, or settings fields are filled with defaults.
- Volumes are clamped to `0..1`.
- Selected cosmetics fall back to defaults if they are not unlocked.
- Unknown top-level fields are preserved where practical.

## Star Rules

Stars are calculated by `NetboundSaveService.calculate_stars_for_values()`:

- `3` stars: completed with `shots_used <= par_shots`
- `2` stars: completed with `shots_used == par_shots + 1`
- `1` star: completed within the shot limit but worse than `par + 1`
- `0` stars: not completed or malformed result data

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

## Public API

Primary service: Autoload `SaveService`, script class `NetboundSaveService`.

Important methods:

- `load_or_create()`
- `save()`
- `is_level_unlocked(level_id)`
- `is_level_completed(level_id)`
- `get_best_stars(level_id)`
- `get_fewest_shots(level_id)`
- `get_total_stars()`
- `record_level_result(level_result, level_definition)`
- `mark_tutorial_complete(level_id)`
- `is_tutorial_complete(level_id)`
- `reset_to_defaults()`
- `unlock_cosmetic(cosmetic_id)`
- `is_cosmetic_unlocked(cosmetic_id)`
- `set_selected_ball(ball_id)`
- `set_selected_trail(trail_id)`
- `set_selected_goal_effect(effect_id)`
- `get_setting_value(setting_name, default_value)`
- `set_setting_value(setting_name, value)`

`reset_to_defaults()` is a development/testing reset hook. It is not exposed as a normal player button in Phase 4.

## Level Registry

`LevelRegistry` explicitly registers all production levels in order. It does not depend on directory enumeration.

Each entry contains:

- `level_id`
- scene path
- definition path

The registry validates:

- exactly 10 levels
- unique IDs
- existing scenes and definitions
- matching `LevelDefinition.level_id`
- sequential `next_level_id`
- empty next ID for Level 10

## Result Recording

`level_controller.gd` records progression only when a goal is scored:

1. Build a completed `LevelResult`.
2. Call `SaveService.record_level_result()`.
3. Calculate stars from the result and definition.
4. Preserve best-ever stars and fewest shots.
5. Mark completion permanently.
6. Unlock the next level if available.
7. Save immediately.
8. Emit `progression_changed(update)`.

Failures, Retry, auto-reset, and manual Reset Ball do not alter progression.

Debug-script runs disable Autoload recording by default. Phase 4 tests explicitly configure isolated `user://phase4_*` paths before enabling recording.
