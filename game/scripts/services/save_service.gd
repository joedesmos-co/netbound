class_name NetboundSaveService
extends Node

signal progression_changed(update)
signal save_loaded(save_data: Dictionary)
signal save_failed(message: String)

const SAVE_VERSION := 2
const DEFAULT_SAVE_PATH := "user://netbound_save.json"
const DEFAULT_TEMP_PATH := "user://netbound_save.tmp"
const DEFAULT_BACKUP_PATH := "user://netbound_save.bak"
const DEFAULT_CORRUPT_PATH := "user://netbound_save.corrupt"

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const ProgressionUpdateScript := preload("res://scripts/services/progression_update.gd")

const DEFAULT_BALL := "ball_classic"
const DEFAULT_TRAIL := "trail_none"
const DEFAULT_GOAL_EFFECT := "goal_classic"
const DEFAULT_UNLOCKED_COSMETICS := [
	"ball_classic",
	"trail_none",
	"goal_classic",
]
const ENTITLEMENT_REMOVE_ADS := "entitlement_remove_ads"
const ENTITLEMENT_STARTER_PACK := "entitlement_starter_pack"
const PRODUCT_REMOVE_ADS := "netbound_remove_ads"
const PRODUCT_STARTER_PACK := "netbound_starter_pack"
const QUALITY_AUTO := "auto"
const QUALITY_LOW := "low"
const QUALITY_MEDIUM := "medium"
const QUALITY_HIGH := "high"
const VALID_QUALITY_TIERS := [QUALITY_AUTO, QUALITY_LOW, QUALITY_MEDIUM, QUALITY_HIGH]
const SUPPORTER_COSMETICS := [
	"ball_supporter",
	"trail_supporter",
	"goal_supporter",
]
const VALID_ENTITLEMENTS := [
	ENTITLEMENT_REMOVE_ADS,
	ENTITLEMENT_STARTER_PACK,
]
const VALID_PRODUCTS := [
	PRODUCT_REMOVE_ADS,
	PRODUCT_STARTER_PACK,
]

const MAX_PROCESSED_TRANSACTIONS := 2048
const MAX_TRANSACTION_HISTORY := 64

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
var _dirty: bool = false
var _last_successful_save_msec: int = 0
var _wallet_service_override: Node


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
	_dirty = false


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


func configure_wallet_service(service: Node) -> void:
	_wallet_service_override = service


func load_or_create() -> bool:
	_diagnostics = PackedStringArray()
	var registry_validation := LevelRegistryScript.validate_registry()
	if not bool(registry_validation.ok):
		for error in registry_validation.errors:
			_diagnostic("level registry: %s" % String(error))
	var cosmetic_validation := CosmeticRegistryScript.validate_registry()
	if not bool(cosmetic_validation.ok):
		for error in cosmetic_validation.errors:
			_diagnostic("cosmetic registry: %s" % String(error))

	if not FileAccess.file_exists(_save_path):
		var backup_data: Variant = _read_save_dictionary(_backup_path)
		if typeof(backup_data) == TYPE_DICTIONARY:
			_diagnostic("primary save missing; recovered from backup")
			return _finish_loaded_save(backup_data as Dictionary, true)
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
		var backup_data: Variant = _read_save_dictionary(_backup_path)
		if typeof(backup_data) == TYPE_DICTIONARY:
			_diagnostic("malformed primary save; recovered from backup")
			var remove_error := DirAccess.remove_absolute(_save_path)
			if remove_error != OK:
				_diagnostic("failed to remove malformed primary save error=%s" % remove_error)
				_save_data = _normalize_save(backup_data as Dictionary)
				_evaluate_cosmetic_unlocks_for_current_save()
				_loaded = true
				save_loaded.emit(_save_data.duplicate(true))
				return true
			return _finish_loaded_save(backup_data as Dictionary, true)
		_save_data = _create_default_save()
		_loaded = true
		var recovered_saved := save()
		save_loaded.emit(_save_data.duplicate(true))
		return recovered_saved

	_save_data = _normalize_save(parsed as Dictionary)
	var migrated_cosmetics := _evaluate_cosmetic_unlocks_for_current_save()
	_loaded = true
	if not migrated_cosmetics.is_empty():
		save()
	save_loaded.emit(_save_data.duplicate(true))
	return true


func _read_save_dictionary(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data


func _finish_loaded_save(raw: Dictionary, persist_recovery: bool) -> bool:
	_save_data = _normalize_save(raw)
	var migrated_cosmetics := _evaluate_cosmetic_unlocks_for_current_save()
	_loaded = true
	var saved := true
	if persist_recovery or not migrated_cosmetics.is_empty():
		saved = save()
	save_loaded.emit(_save_data.duplicate(true))
	return saved


func save() -> bool:
	_ensure_loaded_without_saving()
	_save_data = _normalize_save(_save_data)
	_dirty = true
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
	else:
		_dirty = false
		_last_successful_save_msec = Time.get_ticks_msec()
	return replaced


func flush_if_dirty() -> bool:
	if not _dirty:
		return true
	return save()


func is_dirty() -> bool:
	return _dirty


func get_last_successful_save_msec() -> int:
	return _last_successful_save_msec


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


func get_completed_level_count() -> int:
	_ensure_loaded()
	return (_save_data.progression as Dictionary).completed_levels.size()


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
	par_shots: int,
	_legacy_rewarded_continue_used: bool = false
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
	var save_snapshot := _save_data.duplicate(true)
	update.total_stars_before = get_total_stars()
	update.first_completion = not is_level_completed(update.level_id)
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
	update.unlocked_cosmetic_ids = _evaluate_cosmetic_unlocks_for_current_save()
	if not update.unlocked_cosmetic_ids.is_empty():
		update.changed = true
	var wallet_service := _wallet_service()
	if wallet_service and wallet_service.has_method("process_level_completion_rewards"):
		wallet_service.call("process_level_completion_rewards", update)
	update.save_succeeded = save()
	if not update.save_succeeded:
		_save_data = save_snapshot
		update.first_completion = false
		update.new_best_stars = update.previous_best_stars
		update.new_fewest_shots = update.previous_fewest_shots
		update.unlocked_level_id = ""
		update.did_unlock_new_level = false
		update.unlocked_cosmetic_ids = []
		update.total_stars_after = update.total_stars_before
		update.changed = false
		update.reward_transaction_id = ""
		update.completion_coins = 0
		update.first_completion_coins = 0
		update.new_star_coins = 0
		update.personal_best_coins = 0
		update.coins_earned = 0
		update.coin_balance_after = update.coin_balance_before
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
	return get_selected_cosmetic(CosmeticRegistryScript.CATEGORY_BALL)


func get_selected_trail() -> String:
	return get_selected_cosmetic(CosmeticRegistryScript.CATEGORY_TRAIL)


func get_selected_goal_effect() -> String:
	return get_selected_cosmetic(CosmeticRegistryScript.CATEGORY_GOAL_EFFECT)


func get_selected_cosmetic(category: String) -> String:
	_ensure_loaded()
	if not CosmeticRegistryScript.is_valid_category(category):
		return ""
	var key := CosmeticRegistryScript.get_selection_key(category)
	var fallback := CosmeticRegistryScript.get_default_for_category(category)
	var cosmetic_id := String((_save_data.cosmetics as Dictionary).get(key, fallback))
	if not CosmeticRegistryScript.has_cosmetic(cosmetic_id):
		return fallback
	return cosmetic_id


func get_unlocked_cosmetics() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for cosmetic_id in (_save_data.cosmetics as Dictionary).unlocked as Array:
		result.append(String(cosmetic_id))
	return result


func get_purchased_cosmetics() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for cosmetic_id in (_save_data.cosmetics as Dictionary).purchased as Array:
		result.append(String(cosmetic_id))
	return result


func is_cosmetic_purchased(cosmetic_id: String) -> bool:
	var normalized := CosmeticRegistryScript.normalize_any_id(cosmetic_id)
	return _string_array_contains(get_purchased_cosmetics(), normalized)


func unlock_cosmetic(cosmetic_id: String) -> bool:
	_ensure_loaded()
	var normalized := CosmeticRegistryScript.normalize_any_id(cosmetic_id)
	if not CosmeticRegistryScript.has_cosmetic(normalized):
		return false
	var unlocked := (_save_data.cosmetics as Dictionary).unlocked as Array
	if not _string_array_contains(unlocked, normalized):
		unlocked.append(normalized)
		_save_data = _normalize_save(_save_data)
		return save()
	return true


func is_cosmetic_unlocked(cosmetic_id: String) -> bool:
	_ensure_loaded()
	var normalized := CosmeticRegistryScript.normalize_any_id(cosmetic_id)
	return _string_array_contains((_save_data.cosmetics as Dictionary).unlocked as Array, normalized)


func evaluate_cosmetic_unlocks() -> Array[String]:
	_ensure_loaded()
	var new_unlocks := _evaluate_cosmetic_unlocks_for_current_save()
	if not new_unlocks.is_empty():
		save()
	return new_unlocks


func set_selected_cosmetic(category: String, cosmetic_id: String) -> bool:
	_ensure_loaded()
	if not CosmeticRegistryScript.is_valid_category(category):
		return false
	var normalized := CosmeticRegistryScript.normalize_id_for_category(category, cosmetic_id)
	if not is_cosmetic_unlocked(normalized):
		return false
	var key := CosmeticRegistryScript.get_selection_key(category)
	(_save_data.cosmetics as Dictionary)[key] = normalized
	_save_data = _normalize_save(_save_data)
	return save()


func set_selected_ball(ball_id: String) -> bool:
	return set_selected_cosmetic(CosmeticRegistryScript.CATEGORY_BALL, ball_id)


func set_selected_trail(trail_id: String) -> bool:
	return set_selected_cosmetic(CosmeticRegistryScript.CATEGORY_TRAIL, trail_id)


func set_selected_goal_effect(effect_id: String) -> bool:
	return set_selected_cosmetic(CosmeticRegistryScript.CATEGORY_GOAL_EFFECT, effect_id)


func get_economy_state() -> Dictionary:
	_ensure_loaded()
	return (_save_data.economy as Dictionary).duplicate(true)


func set_economy_state_from_wallet(state: Dictionary, save_to_disk: bool = true) -> bool:
	_ensure_loaded()
	var previous_economy := (_save_data.economy as Dictionary).duplicate(true)
	_save_data.economy = _normalize_economy(state, _save_data.progression as Dictionary, false)
	if not save_to_disk or save():
		return true
	_save_data.economy = previous_economy
	return false


func commit_cosmetic_purchase(cosmetic_id: String, economy_state: Dictionary) -> bool:
	_ensure_loaded()
	var normalized := CosmeticRegistryScript.normalize_any_id(cosmetic_id)
	var definition := CosmeticRegistryScript.get_definition(normalized)
	if definition.is_empty() or not CosmeticRegistryScript.is_currency_purchase(normalized):
		return false
	var old_cosmetics := (_save_data.cosmetics as Dictionary).duplicate(true)
	var old_economy := (_save_data.economy as Dictionary).duplicate(true)
	var cosmetics := _save_data.cosmetics as Dictionary
	var purchased := cosmetics.purchased as Array
	var unlocked := cosmetics.unlocked as Array
	if not _string_array_contains(purchased, normalized):
		purchased.append(normalized)
	if not _string_array_contains(unlocked, normalized):
		unlocked.append(normalized)
	cosmetics.purchased = CosmeticRegistryScript.get_sorted_ids(purchased)
	cosmetics.unlocked = CosmeticRegistryScript.get_sorted_ids(unlocked)
	_save_data.cosmetics = cosmetics
	_save_data.economy = _normalize_economy(economy_state, _save_data.progression as Dictionary, false)
	if save():
		return true
	_save_data.cosmetics = old_cosmetics
	_save_data.economy = old_economy
	return false


func unlock_all_cosmetics_for_development(save_to_disk: bool = true) -> bool:
	_ensure_loaded()
	var unlocked := (_save_data.cosmetics as Dictionary).unlocked as Array
	for definition in CosmeticRegistryScript.get_all():
		var cosmetic_id := String(definition.get("cosmetic_id", ""))
		if not _string_array_contains(unlocked, cosmetic_id):
			unlocked.append(cosmetic_id)
	_save_data = _normalize_save(_save_data)
	return save() if save_to_disk else true


func reset_cosmetics_to_defaults_for_development(save_to_disk: bool = true) -> bool:
	_ensure_loaded()
	(_save_data.cosmetics as Dictionary).selected_ball = DEFAULT_BALL
	(_save_data.cosmetics as Dictionary).selected_trail = DEFAULT_TRAIL
	(_save_data.cosmetics as Dictionary).selected_goal_effect = DEFAULT_GOAL_EFFECT
	(_save_data.cosmetics as Dictionary).unlocked = DEFAULT_UNLOCKED_COSMETICS.duplicate()
	(_save_data.cosmetics as Dictionary).purchased = []
	_save_data = _normalize_save(_save_data)
	return save() if save_to_disk else true


func print_cosmetic_registry_validation() -> void:
	var validation := CosmeticRegistryScript.validate_registry()
	print(JSON.stringify(validation, "\t"))


func get_setting_value(setting_name: String, default_value: Variant = null) -> Variant:
	_ensure_loaded()
	return (_save_data.settings as Dictionary).get(setting_name, default_value)


func set_setting_value(setting_name: String, value: Variant) -> bool:
	_ensure_loaded()
	var settings := _save_data.settings as Dictionary
	settings[setting_name] = value
	_save_data = _normalize_save(_save_data)
	return save()


func has_entitlement(entitlement_id: String) -> bool:
	_ensure_loaded()
	return _string_array_contains((_save_data.monetization as Dictionary).entitlements as Array, entitlement_id)


func get_entitlements() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for entitlement_id in (_save_data.monetization as Dictionary).entitlements as Array:
		result.append(String(entitlement_id))
	return result


func get_monetization_config() -> Dictionary:
	_ensure_loaded()
	return ((_save_data.monetization as Dictionary).config as Dictionary).duplicate(true)


func is_product_owned(product_id: String) -> bool:
	_ensure_loaded()
	var purchases := (_save_data.monetization as Dictionary).purchases as Dictionary
	var purchase := _dict_or_empty(purchases.get(product_id, {}))
	return bool(purchase.get("owned", false))


func record_purchase(
	product_id: String,
	transaction_id: String = "",
	provider_name: String = "simulated"
) -> bool:
	_ensure_loaded()
	if not VALID_PRODUCTS.has(product_id):
		return false
	var monetization := _save_data.monetization as Dictionary
	var purchases := monetization.purchases as Dictionary
	var purchase := _dict_or_empty(purchases.get(product_id, {}))
	var changed := not bool(purchase.get("owned", false))
	purchase.owned = true
	purchase.state = "owned"
	purchase.product_id = product_id
	purchase.provider = provider_name
	purchase.transaction_id = transaction_id
	purchase.last_updated_unix = Time.get_unix_time_from_system()
	purchases[product_id] = purchase

	for entitlement_id in _entitlements_for_product(product_id):
		if _grant_entitlement_in_memory(entitlement_id, product_id):
			changed = true
	if product_id == PRODUCT_STARTER_PACK:
		for cosmetic_id in SUPPORTER_COSMETICS:
			if _unlock_cosmetic_in_memory(cosmetic_id):
				changed = true

	_save_data = _normalize_save(_save_data)
	save()
	return changed


func restore_purchase(product_id: String, transaction_id: String = "") -> bool:
	return record_purchase(product_id, transaction_id, "simulated_restore")


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
			"purchased": [],
		},
		"settings": {
			"master_volume": 1.0,
			"music_volume": 1.0,
			"sfx_volume": 1.0,
			"haptics_enabled": true,
			"reduced_motion_enabled": false,
			"camera_effects_intensity": 1.0,
			"quality_tier": QUALITY_AUTO,
			"developer_debug": false,
		},
		"monetization": _default_monetization(),
		"economy": _default_economy(),
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
	normalized.monetization = _normalize_monetization(_dict_or_empty(raw.get("monetization", {})))
	var migrating_without_economy := version < 2 and not raw.has("economy")
	normalized.economy = _normalize_economy(
		_dict_or_empty(raw.get("economy", {})),
		progression,
		migrating_without_economy
	)
	_apply_entitlement_cosmetic_unlocks(normalized)
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
		var shots := clampi(int(source[level_id]), 1, max(shot_limit + 1, 1))
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
			var cosmetic_id := CosmeticRegistryScript.normalize_any_id(String(item))
			if (
				CosmeticRegistryScript.has_cosmetic(cosmetic_id)
				and not _string_array_contains(unlocked, cosmetic_id)
			):
				unlocked.append(cosmetic_id)
	for default_cosmetic in DEFAULT_UNLOCKED_COSMETICS:
		if not _string_array_contains(unlocked, default_cosmetic):
			unlocked.append(default_cosmetic)
	unlocked = CosmeticRegistryScript.get_sorted_ids(unlocked)
	var purchased: Array = []
	var raw_purchased: Variant = raw.get("purchased", [])
	if typeof(raw_purchased) == TYPE_ARRAY:
		for item in raw_purchased as Array:
			var cosmetic_id := CosmeticRegistryScript.normalize_any_id(String(item))
			if (
				CosmeticRegistryScript.is_currency_purchase(cosmetic_id)
				and not _string_array_contains(purchased, cosmetic_id)
			):
				purchased.append(cosmetic_id)
				if not _string_array_contains(unlocked, cosmetic_id):
					unlocked.append(cosmetic_id)
	unlocked = CosmeticRegistryScript.get_sorted_ids(unlocked)
	purchased = CosmeticRegistryScript.get_sorted_ids(purchased)

	var selected_ball := CosmeticRegistryScript.normalize_id_for_category(
		CosmeticRegistryScript.CATEGORY_BALL,
		String(raw.get("selected_ball", DEFAULT_BALL))
	)
	if not _string_array_contains(unlocked, selected_ball):
		selected_ball = DEFAULT_BALL
	var selected_trail := CosmeticRegistryScript.normalize_id_for_category(
		CosmeticRegistryScript.CATEGORY_TRAIL,
		String(raw.get("selected_trail", DEFAULT_TRAIL))
	)
	if not _string_array_contains(unlocked, selected_trail):
		selected_trail = DEFAULT_TRAIL
	var selected_goal_effect := CosmeticRegistryScript.normalize_id_for_category(
		CosmeticRegistryScript.CATEGORY_GOAL_EFFECT,
		String(raw.get("selected_goal_effect", DEFAULT_GOAL_EFFECT))
	)
	if not _string_array_contains(unlocked, selected_goal_effect):
		selected_goal_effect = DEFAULT_GOAL_EFFECT

	return {
		"selected_ball": selected_ball,
		"selected_trail": selected_trail,
		"selected_goal_effect": selected_goal_effect,
		"unlocked": unlocked,
		"purchased": purchased,
	}


func _default_economy() -> Dictionary:
	return {
		"arcade_coins": 0,
		"net_tokens": 0,
		"processed_transaction_ids": [],
		"transaction_history": [],
		"daily_rewarded_tokens": {
			"local_date": "",
			"completed_rewards": 0,
			"tokens_granted": 0,
		},
		"first_completion_rewards": [],
		"rewarded_star_milestones": {},
		"rewarded_best_shots": {},
		"next_transaction_sequence": 1,
	}


func _normalize_economy(raw: Dictionary, progression: Dictionary, seed_from_progress: bool) -> Dictionary:
	var first_rewards: Array = _normalized_level_array(raw.get("first_completion_rewards", []))
	var star_rewards := _normalized_reward_milestones(raw.get("rewarded_star_milestones", {}), 0, 3)
	var best_rewards := _normalized_reward_milestones(raw.get("rewarded_best_shots", {}), 1, 99)
	if seed_from_progress:
		first_rewards = (progression.get("completed_levels", []) as Array).duplicate()
		star_rewards = (progression.get("best_stars", {}) as Dictionary).duplicate(true)
		best_rewards = (progression.get("fewest_shots", {}) as Dictionary).duplicate(true)
	var processed := _normalized_unique_strings(raw.get("processed_transaction_ids", []), MAX_PROCESSED_TRANSACTIONS)
	var history := _normalized_transaction_history(raw.get("transaction_history", []))
	var daily_raw := _dict_or_empty(raw.get("daily_rewarded_tokens", {}))
	return {
		"arcade_coins": clampi(int(raw.get("arcade_coins", 0)), 0, 2000000000),
		"net_tokens": clampi(int(raw.get("net_tokens", 0)), 0, 2000000000),
		"processed_transaction_ids": processed,
		"transaction_history": history,
		"daily_rewarded_tokens": {
			"local_date": String(daily_raw.get("local_date", "")),
			"completed_rewards": clampi(int(daily_raw.get("completed_rewards", 0)), 0, 5),
			"tokens_granted": clampi(int(daily_raw.get("tokens_granted", 0)), 0, 10),
		},
		"first_completion_rewards": _ordered_level_array(first_rewards),
		"rewarded_star_milestones": star_rewards,
		"rewarded_best_shots": best_rewards,
		"next_transaction_sequence": maxi(int(raw.get("next_transaction_sequence", 1)), 1),
	}


func _normalized_reward_milestones(value: Variant, minimum: int, maximum: int) -> Dictionary:
	var result: Dictionary = {}
	var source := _dict_or_empty(value)
	for level_id in LevelRegistryScript.get_level_ids():
		if source.has(level_id):
			result[level_id] = clampi(int(source[level_id]), minimum, maximum)
	return result


func _normalized_unique_strings(value: Variant, maximum: int) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value as Array:
		var text := String(item).strip_edges()
		if not text.is_empty() and not _string_array_contains(result, text):
			result.append(text)
	while result.size() > maximum:
		result.pop_front()
	return result


func _normalized_transaction_history(value: Variant) -> Array:
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value as Array:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry := item as Dictionary
		result.append({
			"transaction_id": String(entry.get("transaction_id", "")),
			"currency": String(entry.get("currency", "")),
			"delta": int(entry.get("delta", 0)),
			"reason": String(entry.get("reason", "")),
			"unix_time": maxf(float(entry.get("unix_time", 0.0)), 0.0),
		})
	while result.size() > MAX_TRANSACTION_HISTORY:
		result.pop_front()
	return result


func _default_monetization() -> Dictionary:
	return {
		"entitlements": [],
		"purchases": {
			PRODUCT_REMOVE_ADS: _default_purchase_record(PRODUCT_REMOVE_ADS),
			PRODUCT_STARTER_PACK: _default_purchase_record(PRODUCT_STARTER_PACK),
		},
		"config": {
			"ads_enabled": true,
			"purchases_enabled": true,
			"child_directed_treatment": false,
			"privacy_consent_status": "unknown",
			"personalized_ads_allowed": false,
		},
	}


func _default_purchase_record(product_id: String) -> Dictionary:
	return {
		"product_id": product_id,
		"owned": false,
		"state": "not_purchased",
		"provider": "",
		"transaction_id": "",
		"last_updated_unix": 0.0,
	}


func _normalize_monetization(raw: Dictionary) -> Dictionary:
	var entitlements: Array = []
	var raw_entitlements: Variant = raw.get("entitlements", [])
	if typeof(raw_entitlements) == TYPE_ARRAY:
		for item in raw_entitlements as Array:
			var entitlement_id := String(item)
			if VALID_ENTITLEMENTS.has(entitlement_id) and not _string_array_contains(entitlements, entitlement_id):
				entitlements.append(entitlement_id)

	var raw_purchases := _dict_or_empty(raw.get("purchases", {}))
	var purchases := {}
	for product_id in VALID_PRODUCTS:
		var purchase := _normalize_purchase_record(String(product_id), _dict_or_empty(raw_purchases.get(product_id, {})))
		purchases[product_id] = purchase
		if bool(purchase.get("owned", false)):
			for entitlement_id in _entitlements_for_product(product_id):
				if not _string_array_contains(entitlements, entitlement_id):
					entitlements.append(entitlement_id)

	var config := _normalize_monetization_config(_dict_or_empty(raw.get("config", {})))
	return {
		"entitlements": entitlements,
		"purchases": purchases,
		"config": config,
	}


func _normalize_purchase_record(product_id: String, raw: Dictionary) -> Dictionary:
	var record := _default_purchase_record(product_id)
	record.owned = bool(raw.get("owned", false))
	record.state = "owned" if bool(record.owned) else "not_purchased"
	record.provider = String(raw.get("provider", ""))
	record.transaction_id = String(raw.get("transaction_id", ""))
	record.last_updated_unix = maxf(float(raw.get("last_updated_unix", 0.0)), 0.0)
	return record


func _normalize_monetization_config(raw: Dictionary) -> Dictionary:
	return {
		"ads_enabled": bool(raw.get("ads_enabled", true)),
		"purchases_enabled": bool(raw.get("purchases_enabled", true)),
		"child_directed_treatment": bool(raw.get("child_directed_treatment", false)),
		"privacy_consent_status": String(raw.get("privacy_consent_status", "unknown")),
		"personalized_ads_allowed": bool(raw.get("personalized_ads_allowed", false)),
	}


func _apply_entitlement_cosmetic_unlocks(save_data: Dictionary) -> void:
	var monetization := save_data.monetization as Dictionary
	var entitlements := monetization.entitlements as Array
	if not _string_array_contains(entitlements, ENTITLEMENT_STARTER_PACK):
		return
	var cosmetics := save_data.cosmetics as Dictionary
	var unlocked := cosmetics.unlocked as Array
	for cosmetic_id in SUPPORTER_COSMETICS:
		if CosmeticRegistryScript.has_cosmetic(cosmetic_id) and not _string_array_contains(unlocked, cosmetic_id):
			unlocked.append(cosmetic_id)
	cosmetics.unlocked = CosmeticRegistryScript.get_sorted_ids(unlocked)
	save_data.cosmetics = cosmetics


func _grant_entitlement_in_memory(entitlement_id: String, _source: String = "") -> bool:
	if not VALID_ENTITLEMENTS.has(entitlement_id):
		return false
	var monetization := _save_data.monetization as Dictionary
	var entitlements := monetization.entitlements as Array
	if _string_array_contains(entitlements, entitlement_id):
		return false
	entitlements.append(entitlement_id)
	monetization.entitlements = entitlements
	_save_data.monetization = monetization
	return true


func _unlock_cosmetic_in_memory(cosmetic_id: String) -> bool:
	var normalized := CosmeticRegistryScript.normalize_any_id(cosmetic_id)
	if not CosmeticRegistryScript.has_cosmetic(normalized):
		return false
	var cosmetics := _save_data.cosmetics as Dictionary
	var unlocked := cosmetics.unlocked as Array
	if _string_array_contains(unlocked, normalized):
		return false
	unlocked.append(normalized)
	cosmetics.unlocked = unlocked
	_save_data.cosmetics = cosmetics
	return true


func _entitlements_for_product(product_id: String) -> Array[String]:
	match product_id:
		PRODUCT_REMOVE_ADS:
			return [ENTITLEMENT_REMOVE_ADS]
		PRODUCT_STARTER_PACK:
			return [ENTITLEMENT_REMOVE_ADS, ENTITLEMENT_STARTER_PACK]
		_:
			return []


func _normalize_settings(raw: Dictionary) -> Dictionary:
	return {
		"master_volume": clampf(float(raw.get("master_volume", 1.0)), 0.0, 1.0),
		"music_volume": clampf(float(raw.get("music_volume", 1.0)), 0.0, 1.0),
		"sfx_volume": clampf(float(raw.get("sfx_volume", 1.0)), 0.0, 1.0),
		"haptics_enabled": bool(raw.get("haptics_enabled", true)),
		"reduced_motion_enabled": bool(raw.get("reduced_motion_enabled", false)),
		"camera_effects_intensity": clampf(float(raw.get("camera_effects_intensity", 1.0)), 0.0, 1.0),
		"quality_tier": _normalize_quality_tier(raw.get("quality_tier", QUALITY_AUTO)),
		"developer_debug": bool(raw.get("developer_debug", false)),
	}


func _normalize_quality_tier(value: Variant) -> String:
	var tier := String(value).to_lower()
	return tier if VALID_QUALITY_TIERS.has(tier) else QUALITY_AUTO


func _sum_best_stars(best_stars: Dictionary) -> int:
	var total := 0
	for level_id in LevelRegistryScript.get_level_ids():
		total += clampi(int(best_stars.get(level_id, 0)), 0, 3)
	return total


func _evaluate_cosmetic_unlocks_for_current_save() -> Array[String]:
	var new_unlocks: Array[String] = []
	if _save_data.is_empty() or not _save_data.has("progression") or not _save_data.has("cosmetics"):
		return new_unlocks

	var progression := _save_data.progression as Dictionary
	var completed_levels := progression.get("completed_levels", []) as Array
	var total_stars := int(progression.get("total_stars", 0))
	var cosmetics := _save_data.cosmetics as Dictionary
	var unlocked := cosmetics.get("unlocked", []) as Array

	for definition in CosmeticRegistryScript.get_all():
		var cosmetic_id := String(definition.get("cosmetic_id", ""))
		if _string_array_contains(unlocked, cosmetic_id):
			continue
		if CosmeticRegistryScript.is_requirement_met(cosmetic_id, completed_levels, total_stars):
			unlocked.append(cosmetic_id)
			new_unlocks.append(cosmetic_id)

	if not new_unlocks.is_empty():
		cosmetics.unlocked = CosmeticRegistryScript.get_sorted_ids(unlocked)
		_save_data.cosmetics = cosmetics
		_save_data = _normalize_save(_save_data)
	return new_unlocks


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


func _wallet_service() -> Node:
	if _wallet_service_override:
		return _wallet_service_override
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/WalletService")


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
