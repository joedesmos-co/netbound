class_name NetboundSaveService
extends Node

signal progression_changed(update)
signal save_loaded(save_data: Dictionary)
signal save_failed(message: String)

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://netbound_save.json"
const DEFAULT_TEMP_PATH := "user://netbound_save.tmp"
const DEFAULT_BACKUP_PATH := "user://netbound_save.bak"
const DEFAULT_CORRUPT_PATH := "user://netbound_save.corrupt"

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const ProgressionUpdateScript := preload("res://scripts/services/progression_update.gd")

const DEFAULT_BALL := "classic"
const DEFAULT_TRAIL := "none"
const DEFAULT_GOAL_EFFECT := "classic"
const DEFAULT_UNLOCKED_COSMETICS := [
	"ball:classic",
	"trail:none",
	"goal_effect:classic",
]

var recording_enabled: bool = true
var developer_diagnostics_enabled: bool = false

var _save_path: String = DEFAULT_SAVE_PATH
var _temp_path: String = DEFAULT_TEMP_PATH
var _backup_path: String = DEFAULT_BACKUP_PATH
var _corrupt_path: String = DEFAULT_CORRUPT_PATH
var _save_data: Dictionary = {}
var _loaded: bool = false
var _diagnostics: PackedStringArray = PackedStringArray()
var _simulate_next_write_failure: bool = false


func _ready() -> void:
	recording_enabled = not _is_script_mode()
	if recording_enabled:
		load_or_create()


func configure_storage_paths(
	primary_path: String,
	temp_path: String = "",
	backup_path: String = "",
	corrupt_path: String = ""
) -> void:
	_save_path = primary_path
	_temp_path = temp_path if not temp_path.is_empty() else "%s.tmp" % primary_path
	_backup_path = backup_path if not backup_path.is_empty() else "%s.bak" % primary_path
	_corrupt_path = corrupt_path if not corrupt_path.is_empty() else "%s.corrupt" % primary_path
	_save_data = {}
	_loaded = false


func get_save_path() -> String:
	return _save_path


func get_temp_path() -> String:
	return _temp_path


func get_backup_path() -> String:
	return _backup_path


func get_corrupt_path() -> String:
	return _corrupt_path


func get_diagnostics() -> PackedStringArray:
	return _diagnostics.duplicate()


func clear_diagnostics() -> void:
	_diagnostics = PackedStringArray()


func get_save_data() -> Dictionary:
	_ensure_loaded()
	return _save_data.duplicate(true)


func load_or_create() -> bool:
	_diagnostics = PackedStringArray()
	var registry_validation := LevelRegistryScript.validate_registry()
	if not bool(registry_validation.ok):
		for error in registry_validation.errors:
			_diagnostic("level registry: %s" % String(error))

	if not FileAccess.file_exists(_save_path):
		_save_data = _create_default_save()
		_loaded = true
		var default_saved := save()
		save_loaded.emit(_save_data.duplicate(true))
		return default_saved

	var text := FileAccess.get_file_as_string(_save_path)
	var json := JSON.new()
	var parse_error := json.parse(text)
	var parsed: Variant = json.data if parse_error == OK else null
	if parse_error != OK or typeof(parsed) != TYPE_DICTIONARY:
		_diagnostic("save file is malformed JSON; recreating defaults")
		_preserve_corrupt_text(text)
		_save_data = _create_default_save()
		_loaded = true
		var recovered_saved := save()
		save_loaded.emit(_save_data.duplicate(true))
		return recovered_saved

	_save_data = _normalize_save(parsed as Dictionary)
	_loaded = true
	save_loaded.emit(_save_data.duplicate(true))
	return true


func save() -> bool:
	_ensure_loaded_without_saving()
	_save_data = _normalize_save(_save_data)
	var text := JSON.stringify(_save_data, "\t", true)
	if _simulate_next_write_failure:
		_simulate_next_write_failure = false
		_diagnostic("simulated save failure")
		save_failed.emit("simulated save failure")
		return false

	var temp_file := FileAccess.open(_temp_path, FileAccess.WRITE)
	if not temp_file:
		var open_error := FileAccess.get_open_error()
		_diagnostic("failed to open temp save %s error=%s" % [_temp_path, open_error])
		save_failed.emit("failed to open temp save")
		return false
	temp_file.store_string(text)
	temp_file.flush()
	temp_file.close()

	var replaced := _replace_primary_with_temp()
	if not replaced:
		save_failed.emit("failed to replace primary save")
	return replaced


func reset_to_defaults(save_to_disk: bool = true) -> bool:
	_save_data = _create_default_save()
	_loaded = true
	if FileAccess.file_exists(_temp_path):
		DirAccess.remove_absolute(_temp_path)
	if save_to_disk:
		return save()
	return true


func is_level_unlocked(level_id: String) -> bool:
	_ensure_loaded()
	return _string_array_contains(_progression_array("unlocked_levels"), level_id)


func is_level_completed(level_id: String) -> bool:
	_ensure_loaded()
	return _string_array_contains(_progression_array("completed_levels"), level_id)


func get_best_stars(level_id: String) -> int:
	_ensure_loaded()
	var best_stars := _progression_dict("best_stars")
	return int(best_stars.get(level_id, 0))


func get_fewest_shots(level_id: String) -> int:
	_ensure_loaded()
	var fewest_shots := _progression_dict("fewest_shots")
	return int(fewest_shots.get(level_id, -1))


func get_total_stars() -> int:
	_ensure_loaded()
	var total := 0
	var best_stars := _progression_dict("best_stars")
	for level_id in LevelRegistryScript.get_level_ids():
		total += int(best_stars.get(level_id, 0))
	return total


func calculate_stars(level_result: LevelResult, level_definition: LevelDefinition) -> int:
	var shot_limit := level_definition.shot_limit if level_definition else level_result.shot_limit
	var par_shots := level_definition.par_shots if level_definition else level_result.par_shots
	if par_shots > shot_limit and shot_limit > 0:
		_diagnostic(
			"invalid star config for %s: par_shots=%d shot_limit=%d" % [
				level_result.level_id,
				par_shots,
				shot_limit,
			]
		)
	return calculate_stars_for_values(
		level_result.completed,
		level_result.shots_used,
		shot_limit,
		par_shots
	)


static func calculate_stars_for_values(
	completed: bool,
	shots_used: int,
	shot_limit: int,
	par_shots: int
) -> int:
	if not completed:
		return 0
	if shot_limit <= 0 or par_shots <= 0 or shots_used <= 0:
		return 0
	var safe_par := mini(par_shots, shot_limit)
	var safe_shots := clampi(shots_used, 1, shot_limit)
	if safe_shots <= safe_par:
		return 3
	if safe_shots == safe_par + 1 and safe_shots <= shot_limit:
		return 2
	return 1


func record_level_result(
	level_result: LevelResult,
	level_definition: LevelDefinition
) -> RefCounted:
	var update := ProgressionUpdateScript.new()
	if not level_result or not level_definition:
		_diagnostic("record_level_result called without result or definition")
		return update

	update.level_id = level_result.level_id
	update.completed = level_result.completed
	if not recording_enabled:
		_diagnostic("progression recording skipped because recording is disabled")
		return update

	_ensure_loaded()
	update.total_stars_before = get_total_stars()
	update.previous_best_stars = get_best_stars(update.level_id)
	update.previous_fewest_shots = get_fewest_shots(update.level_id)
	update.new_best_stars = update.previous_best_stars
	update.new_fewest_shots = update.previous_fewest_shots

	if not level_result.completed:
		update.total_stars_after = update.total_stars_before
		return update
	if not LevelRegistryScript.has_level_id(level_result.level_id):
		_diagnostic("unknown level result ignored: %s" % level_result.level_id)
		update.total_stars_after = update.total_stars_before
		return update
	if not is_level_unlocked(level_result.level_id):
		_diagnostic("locked level result ignored: %s" % level_result.level_id)
		update.total_stars_after = update.total_stars_before
		return update

	update.stars_earned = calculate_stars(level_result, level_definition)
	var progression := _save_data.progression as Dictionary
	var completed_levels := progression.completed_levels as Array
	var unlocked_levels := progression.unlocked_levels as Array
	var best_stars := progression.best_stars as Dictionary
	var fewest_shots := progression.fewest_shots as Dictionary

	if not _string_array_contains(completed_levels, level_result.level_id):
		completed_levels.append(level_result.level_id)
		update.changed = true

	if update.stars_earned > update.previous_best_stars:
		best_stars[level_result.level_id] = update.stars_earned
		update.new_best_stars = update.stars_earned
		update.changed = true

	if (
		update.previous_fewest_shots < 0
		or level_result.shots_used < update.previous_fewest_shots
	):
		fewest_shots[level_result.level_id] = level_result.shots_used
		update.new_fewest_shots = level_result.shots_used
		update.changed = true

	var next_level_id := level_definition.next_level_id
	if (
		not next_level_id.is_empty()
		and LevelRegistryScript.has_level_id(next_level_id)
		and not _string_array_contains(unlocked_levels, next_level_id)
	):
		unlocked_levels.append(next_level_id)
		update.unlocked_level_id = next_level_id
		update.did_unlock_new_level = true
		update.changed = true

	_save_data = _normalize_save(_save_data)
	update.total_stars_after = get_total_stars()
	update.save_succeeded = save()
	progression_changed.emit(update)
	return update


func mark_tutorial_complete(level_id: String) -> bool:
	_ensure_loaded()
	if not LevelRegistryScript.has_level_id(level_id):
		return false
	var tutorial_completed := _progression_dict("tutorial_completed")
	tutorial_completed[level_id] = true
	_save_data = _normalize_save(_save_data)
	return save()


func is_tutorial_complete(level_id: String) -> bool:
	_ensure_loaded()
	return bool(_progression_dict("tutorial_completed").get(level_id, false))


func get_selected_ball() -> String:
	_ensure_loaded()
	return String((_save_data.cosmetics as Dictionary).get("selected_ball", DEFAULT_BALL))


func get_selected_trail() -> String:
	_ensure_loaded()
	return String((_save_data.cosmetics as Dictionary).get("selected_trail", DEFAULT_TRAIL))


func get_selected_goal_effect() -> String:
	_ensure_loaded()
	return String(
		(_save_data.cosmetics as Dictionary).get("selected_goal_effect", DEFAULT_GOAL_EFFECT)
	)


func unlock_cosmetic(cosmetic_id: String) -> bool:
	_ensure_loaded()
	if cosmetic_id.is_empty():
		return false
	var unlocked := (_save_data.cosmetics as Dictionary).unlocked as Array
	if not _string_array_contains(unlocked, cosmetic_id):
		unlocked.append(cosmetic_id)
		_save_data = _normalize_save(_save_data)
		return save()
	return true


func is_cosmetic_unlocked(cosmetic_id: String) -> bool:
	_ensure_loaded()
	return _string_array_contains((_save_data.cosmetics as Dictionary).unlocked as Array, cosmetic_id)


func set_selected_ball(ball_id: String) -> bool:
	return _set_selected_cosmetic("selected_ball", "ball:%s" % ball_id, ball_id, DEFAULT_BALL)


func set_selected_trail(trail_id: String) -> bool:
	return _set_selected_cosmetic("selected_trail", "trail:%s" % trail_id, trail_id, DEFAULT_TRAIL)


func set_selected_goal_effect(effect_id: String) -> bool:
	return _set_selected_cosmetic(
		"selected_goal_effect",
		"goal_effect:%s" % effect_id,
		effect_id,
		DEFAULT_GOAL_EFFECT
	)


func get_setting_value(setting_name: String, default_value: Variant = null) -> Variant:
	_ensure_loaded()
	return (_save_data.settings as Dictionary).get(setting_name, default_value)


func set_setting_value(setting_name: String, value: Variant) -> bool:
	_ensure_loaded()
	var settings := _save_data.settings as Dictionary
	settings[setting_name] = value
	_save_data = _normalize_save(_save_data)
	return save()


func simulate_next_write_failure_for_tests() -> void:
	_simulate_next_write_failure = true


func _create_default_save() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"progression": {
			"unlocked_levels": [LevelRegistryScript.get_first_level_id()],
			"completed_levels": [],
			"best_stars": {},
			"fewest_shots": {},
			"tutorial_completed": {},
			"total_stars": 0,
		},
		"cosmetics": {
			"selected_ball": DEFAULT_BALL,
			"selected_trail": DEFAULT_TRAIL,
			"selected_goal_effect": DEFAULT_GOAL_EFFECT,
			"unlocked": DEFAULT_UNLOCKED_COSMETICS.duplicate(),
		},
		"settings": {
			"master_volume": 1.0,
			"music_volume": 1.0,
			"sfx_volume": 1.0,
			"haptics_enabled": true,
			"developer_debug": false,
		},
	}


func _normalize_save(raw: Dictionary) -> Dictionary:
	var normalized := raw.duplicate(true)
	var version := int(raw.get("save_version", SAVE_VERSION))
	if version != SAVE_VERSION:
		_diagnostic("migrating save version %d to %d" % [version, SAVE_VERSION])
	normalized.save_version = SAVE_VERSION

	var raw_progression: Dictionary = _dict_or_empty(raw.get("progression", {}))
	var progression := {
		"unlocked_levels": _normalized_level_array(
			raw_progression.get("unlocked_levels", [])
		),
		"completed_levels": _normalized_level_array(
			raw_progression.get("completed_levels", [])
		),
		"best_stars": _normalized_best_stars(raw_progression.get("best_stars", {})),
		"fewest_shots": _normalized_fewest_shots(raw_progression.get("fewest_shots", {})),
		"tutorial_completed": _normalized_tutorials(
			raw_progression.get("tutorial_completed", {})
		),
		"total_stars": 0,
	}

	if not _string_array_contains(progression.unlocked_levels, LevelRegistryScript.get_first_level_id()):
		progression.unlocked_levels.append(LevelRegistryScript.get_first_level_id())

	for completed_level_id in progression.completed_levels:
		if not _string_array_contains(progression.unlocked_levels, completed_level_id):
			progression.unlocked_levels.append(completed_level_id)
		var definition := LevelRegistryScript.load_definition(completed_level_id)
		if definition and not definition.next_level_id.is_empty():
			if not _string_array_contains(progression.unlocked_levels, definition.next_level_id):
				progression.unlocked_levels.append(definition.next_level_id)

	progression.unlocked_levels = _ordered_level_array(progression.unlocked_levels)
	progression.completed_levels = _ordered_level_array(progression.completed_levels)
	progression.total_stars = _sum_best_stars(progression.best_stars)
	normalized.progression = progression

	var cosmetics := _normalize_cosmetics(_dict_or_empty(raw.get("cosmetics", {})))
	normalized.cosmetics = cosmetics
	normalized.settings = _normalize_settings(_dict_or_empty(raw.get("settings", {})))
	return normalized


func _normalized_level_array(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var level_id := String(item)
		if LevelRegistryScript.has_level_id(level_id) and not _string_array_contains(result, level_id):
			result.append(level_id)
	return result


func _ordered_level_array(values: Array) -> Array:
	var ordered: Array = []
	for level_id in LevelRegistryScript.get_level_ids():
		if _string_array_contains(values, level_id):
			ordered.append(level_id)
	return ordered


func _normalized_best_stars(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := _dict_or_empty(value)
	for level_id in LevelRegistryScript.get_level_ids():
		if source.has(level_id):
			result[level_id] = clampi(int(source[level_id]), 0, 3)
	return result


func _normalized_fewest_shots(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := _dict_or_empty(value)
	for level_id in LevelRegistryScript.get_level_ids():
		if not source.has(level_id):
			continue
		var definition := LevelRegistryScript.load_definition(level_id)
		var shot_limit := definition.shot_limit if definition else 99
		var shots := clampi(int(source[level_id]), 1, max(shot_limit, 1))
		result[level_id] = shots
	return result


func _normalized_tutorials(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	var source := _dict_or_empty(value)
	for level_id in LevelRegistryScript.get_level_ids():
		if source.has(level_id):
			result[level_id] = bool(source[level_id])
	return result


func _normalize_cosmetics(raw: Dictionary) -> Dictionary:
	var unlocked: Array = []
	var raw_unlocked: Variant = raw.get("unlocked", [])
	if typeof(raw_unlocked) == TYPE_ARRAY:
		for item in raw_unlocked:
			var cosmetic_id := String(item)
			if not cosmetic_id.is_empty() and not _string_array_contains(unlocked, cosmetic_id):
				unlocked.append(cosmetic_id)
	for default_cosmetic in DEFAULT_UNLOCKED_COSMETICS:
		if not _string_array_contains(unlocked, default_cosmetic):
			unlocked.append(default_cosmetic)

	var selected_ball := String(raw.get("selected_ball", DEFAULT_BALL))
	if not _string_array_contains(unlocked, "ball:%s" % selected_ball):
		selected_ball = DEFAULT_BALL
	var selected_trail := String(raw.get("selected_trail", DEFAULT_TRAIL))
	if not _string_array_contains(unlocked, "trail:%s" % selected_trail):
		selected_trail = DEFAULT_TRAIL
	var selected_goal_effect := String(raw.get("selected_goal_effect", DEFAULT_GOAL_EFFECT))
	if not _string_array_contains(unlocked, "goal_effect:%s" % selected_goal_effect):
		selected_goal_effect = DEFAULT_GOAL_EFFECT

	return {
		"selected_ball": selected_ball,
		"selected_trail": selected_trail,
		"selected_goal_effect": selected_goal_effect,
		"unlocked": unlocked,
	}


func _normalize_settings(raw: Dictionary) -> Dictionary:
	return {
		"master_volume": clampf(float(raw.get("master_volume", 1.0)), 0.0, 1.0),
		"music_volume": clampf(float(raw.get("music_volume", 1.0)), 0.0, 1.0),
		"sfx_volume": clampf(float(raw.get("sfx_volume", 1.0)), 0.0, 1.0),
		"haptics_enabled": bool(raw.get("haptics_enabled", true)),
		"developer_debug": bool(raw.get("developer_debug", false)),
	}


func _sum_best_stars(best_stars: Dictionary) -> int:
	var total := 0
	for level_id in LevelRegistryScript.get_level_ids():
		total += clampi(int(best_stars.get(level_id, 0)), 0, 3)
	return total


func _set_selected_cosmetic(
	key: String,
	unlock_id: String,
	selected_value: String,
	default_value: String
) -> bool:
	_ensure_loaded()
	var cosmetics := _save_data.cosmetics as Dictionary
	if not _string_array_contains(cosmetics.unlocked as Array, unlock_id):
		return false
	cosmetics[key] = selected_value if not selected_value.is_empty() else default_value
	_save_data = _normalize_save(_save_data)
	return save()


func _progression_array(key: String) -> Array:
	_ensure_loaded()
	return (_save_data.progression as Dictionary).get(key, []) as Array


func _progression_dict(key: String) -> Dictionary:
	_ensure_loaded()
	return (_save_data.progression as Dictionary).get(key, {}) as Dictionary


func _replace_primary_with_temp() -> bool:
	var had_primary := FileAccess.file_exists(_save_path)
	if had_primary:
		if FileAccess.file_exists(_backup_path):
			DirAccess.remove_absolute(_backup_path)
		var backup_error := DirAccess.rename_absolute(_save_path, _backup_path)
		if backup_error != OK:
			_diagnostic("failed to move primary save to backup error=%s" % backup_error)
			return false

	var replace_error := DirAccess.rename_absolute(_temp_path, _save_path)
	if replace_error == OK:
		return true

	_diagnostic("failed to move temp save into place error=%s" % replace_error)
	if had_primary and FileAccess.file_exists(_backup_path):
		var restore_error := DirAccess.rename_absolute(_backup_path, _save_path)
		if restore_error != OK:
			_diagnostic("failed to restore backup save error=%s" % restore_error)
	return false


func _preserve_corrupt_text(text: String) -> void:
	if text.is_empty():
		return
	var file := FileAccess.open(_corrupt_path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.flush()
		file.close()


func _ensure_loaded() -> void:
	if not _loaded:
		load_or_create()


func _ensure_loaded_without_saving() -> void:
	if _loaded:
		return
	_save_data = _create_default_save()
	_loaded = true


func _dict_or_empty(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}


func _string_array_contains(values: Array, needle: String) -> bool:
	for value in values:
		if String(value) == needle:
			return true
	return false


func _diagnostic(message: String) -> void:
	_diagnostics.append(message)
	if developer_diagnostics_enabled:
		push_warning("SaveService: %s" % message)


func _is_script_mode() -> bool:
	var args := OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--script":
			return true
	return false
