extends SceneTree

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const WorldCatalogScript := preload("res://scripts/levels/world_catalog.gd")
const SaveServiceScript := preload("res://scripts/services/save_service.gd")
const AppScene := preload("res://app/netbound_app.tscn")

const TEST_SAVE := "user://world_expansion_v2.json"
const TEST_TMP := "user://world_expansion_v2.tmp"
const TEST_BAK := "user://world_expansion_v2.bak"
const TEST_CORRUPT := "user://world_expansion_v2.corrupt"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := true
	passed = _verify_worlds_and_registry() and passed
	passed = _verify_save_migration() and passed
	passed = await _verify_level_select() and passed
	_cleanup()
	print("WORLD_EXPANSION verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _verify_worlds_and_registry() -> bool:
	var validation := LevelRegistryScript.validate_registry()
	var ids := LevelRegistryScript.get_level_ids()
	var passed := bool(validation.ok) and ids.size() == 30
	passed = WorldCatalogScript.get_worlds().size() == 3 and passed
	passed = WorldCatalogScript.get_world_id_for_level_id("level_01") == WorldCatalogScript.WORLD_TRAINING and passed
	passed = WorldCatalogScript.get_world_id_for_level_id("level_11") == WorldCatalogScript.WORLD_STREET and passed
	passed = WorldCatalogScript.get_world_id_for_level_id("level_21") == WorldCatalogScript.WORLD_STADIUM and passed
	passed = LevelRegistryScript.get_next_level_id("level_20") == "level_21" and passed
	passed = LevelRegistryScript.get_next_level_id("level_30").is_empty() and passed
	print("WORLD_EXPANSION registry ok=", passed, " count=", ids.size())
	return passed


func _verify_save_migration() -> bool:
	_cleanup()
	var completed: Array = []
	var unlocked: Array = []
	var best_stars: Dictionary = {}
	for index in range(1, 21):
		var level_id := "level_%02d" % index
		completed.append(level_id)
		unlocked.append(level_id)
		best_stars[level_id] = 3
	var legacy := {
		"save_version": 2,
		"progression": {
			"unlocked_levels": unlocked,
			"completed_levels": completed,
			"best_stars": best_stars,
			"fewest_shots": {},
			"tutorial_completed": {},
			"total_stars": 60,
		},
		"cosmetics": {
			"selected_ball": "ball_classic",
			"selected_trail": "trail_none",
			"selected_goal_effect": "goal_classic",
			"unlocked": ["ball_classic", "trail_none", "goal_classic", "ball_gold"],
			"purchased": [],
		},
		"settings": {},
		"monetization": {},
		"economy": {
			"arcade_coins": 2222,
			"net_tokens": 33,
			"processed_transaction_ids": [],
			"transaction_history": [],
			"daily_rewarded_tokens": {},
			"first_completion_rewards": completed,
			"rewarded_star_milestones": {},
			"rewarded_best_shots": {},
			"next_transaction_sequence": 4,
		},
	}
	_write_json(TEST_SAVE, legacy)
	var service = SaveServiceScript.new()
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	var loaded := service.load_or_create()
	var data: Dictionary = service.get_save_data()
	var passed := (
		loaded
		and int(data.save_version) == 2
		and service.is_level_completed("level_20")
		and service.is_level_unlocked("level_21")
		and not service.is_level_unlocked("level_22")
		and service.get_total_stars() == 60
		and service.is_cosmetic_unlocked("ball_gold")
		and int(data.economy.arcade_coins) == 2222
		and int(data.economy.net_tokens) == 33
	)
	print(
		"WORLD_EXPANSION migration unlock21=", service.is_level_unlocked("level_21"),
		" stars=", service.get_total_stars(),
		" ok=", passed
	)
	service.free()
	return passed


func _verify_level_select() -> bool:
	var service = get_root().get_node("SaveService")
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()
	var app := AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await process_frame
	app.show_level_select()
	await process_frame
	var passed := (
		app.get_registered_level_card_count() == 30
		and app.total_stars_label.text == "Stars: 0 / 90"
		and app.level_world_routes.size() == 3
	)
	print(
		"WORLD_EXPANSION level_select cards=", app.get_registered_level_card_count(),
		" worlds=", app.level_world_routes.size(),
		" ok=", passed
	)
	app.queue_free()
	await process_frame
	return passed


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _cleanup() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
