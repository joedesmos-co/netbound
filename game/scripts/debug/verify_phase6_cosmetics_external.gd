extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const SaveServiceScript := preload("res://scripts/services/save_service.gd")

const TEST_SAVE := "user://phase6_cosmetics_test.json"
const TEST_TMP := "user://phase6_cosmetics_test.tmp"
const TEST_BAK := "user://phase6_cosmetics_test.bak"
const TEST_CORRUPT := "user://phase6_cosmetics_test.corrupt"

var service: Node
var app: NetboundApp


func _initialize() -> void:
	service = get_root().get_node("SaveService")
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := true
	_cleanup_test_files()
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()

	passed = _test_registry() and passed
	passed = _test_save_selection_and_migration() and passed
	passed = _test_unlock_conditions() and passed
	passed = await _test_gameplay_application() and passed
	passed = await _test_cosmetics_screen() and passed
	passed = await _test_result_unlock_display() and passed
	passed = await _test_all_production_level_startups() and passed
	_cleanup_test_files()
	print("PHASE6 verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_registry() -> bool:
	var validation: Dictionary = CosmeticRegistryScript.validate_registry()
	var all := CosmeticRegistryScript.get_all()
	var passed: bool = bool(validation.ok) and all.size() == 17
	passed = CosmeticRegistryScript.get_by_category("ball").size() == 7 and passed
	passed = CosmeticRegistryScript.get_by_category("trail").size() == 6 and passed
	passed = CosmeticRegistryScript.get_by_category("goal_effect").size() == 4 and passed
	passed = CosmeticRegistryScript.get_default_for_category("ball") == "ball_classic" and passed
	passed = CosmeticRegistryScript.get_default_for_category("trail") == "trail_none" and passed
	passed = CosmeticRegistryScript.get_default_for_category("goal_effect") == "goal_classic" and passed
	var seen := {}
	for definition in all:
		var cosmetic_id := String(definition.get("cosmetic_id", ""))
		passed = not seen.has(cosmetic_id) and passed
		seen[cosmetic_id] = true
		passed = CosmeticRegistryScript.is_valid_category(String(definition.get("category", ""))) and passed
		passed = not CosmeticRegistryScript.get_unlock_requirement_text(cosmetic_id).is_empty() and passed
	print("PHASE6 registry ok=", passed)
	return passed


func _test_save_selection_and_migration() -> bool:
	_cleanup_paths("selection")
	var local_service := _new_service("selection")
	local_service.load_or_create()
	var passed: bool = local_service.get_selected_ball() == "ball_classic" \
		and local_service.get_selected_trail() == "trail_none" \
		and local_service.get_selected_goal_effect() == "goal_classic"
	passed = not local_service.set_selected_cosmetic("ball", "ball_gold") and passed
	passed = local_service.unlock_cosmetic("ball_gold") and passed
	passed = local_service.set_selected_cosmetic("ball", "ball_gold") and passed

	var reloaded := _new_service("selection")
	passed = reloaded.load_or_create() and passed
	passed = reloaded.get_selected_ball() == "ball_gold" and passed

	var save_data: Dictionary = reloaded.get_save_data()
	save_data.cosmetics.selected_ball = "missing_ball"
	save_data.cosmetics.unlocked = ["ball_classic", "trail_none", "goal_classic"]
	_write_text(reloaded.get_save_path(), JSON.stringify(save_data, "\t", true))
	var invalid_reloaded := _new_service("selection")
	passed = invalid_reloaded.load_or_create() and passed
	passed = invalid_reloaded.get_selected_ball() == "ball_classic" and passed

	var legacy := {
		"save_version": 1,
		"progression": {
			"unlocked_levels": ["level_01"],
			"completed_levels": [],
			"best_stars": {},
			"fewest_shots": {},
			"tutorial_completed": {},
			"total_stars": 0,
		},
		"cosmetics": {
			"selected_ball": "gold",
			"selected_trail": "none",
			"selected_goal_effect": "classic",
			"unlocked": ["ball:classic", "ball:gold", "trail:none", "goal_effect:classic"],
		},
		"settings": {},
	}
	_write_text(reloaded.get_save_path(), JSON.stringify(legacy, "\t", true))
	var migrated := _new_service("selection")
	passed = migrated.load_or_create() and passed
	passed = migrated.get_selected_ball() == "ball_gold" and passed
	passed = migrated.get_selected_trail() == "trail_none" and passed
	passed = migrated.get_selected_goal_effect() == "goal_classic" and passed
	passed = migrated.get_save_data().save_version == 1 and passed

	local_service.free()
	reloaded.free()
	invalid_reloaded.free()
	migrated.free()
	print("PHASE6 save_selection ok=", passed)
	return passed


func _test_unlock_conditions() -> bool:
	_cleanup_paths("unlocks")
	var local_service := _new_service("unlocks")
	local_service.load_or_create()
	var passed := true
	var level_01 := LevelRegistryScript.load_definition("level_01")
	var failed_update = local_service.record_level_result(
		LevelResult.failed_result(level_01, level_01.shot_limit),
		level_01
	)
	passed = not local_service.is_cosmetic_unlocked("ball_neon") and passed
	passed = (failed_update.unlocked_cosmetic_ids as Array).is_empty() and passed

	local_service.record_level_result(LevelResult.completed_result(level_01, level_01.par_shots), level_01)
	var level_02 := LevelRegistryScript.load_definition("level_02")
	var level_02_update = local_service.record_level_result(
		LevelResult.completed_result(level_02, level_02.par_shots),
		level_02
	)
	passed = _contains_string(level_02_update.unlocked_cosmetic_ids, "ball_neon") and passed
	passed = _contains_string(level_02_update.unlocked_cosmetic_ids, "ball_fire") and passed

	var level_04_update = null
	for index in range(3, 5):
		var definition := LevelRegistryScript.load_definition("level_%02d" % index)
		level_04_update = local_service.record_level_result(
			LevelResult.completed_result(definition, definition.par_shots),
			definition
		)
	passed = _contains_string(level_04_update.unlocked_cosmetic_ids, "trail_blue") and passed
	passed = _contains_string(level_04_update.unlocked_cosmetic_ids, "trail_flame") and passed

	var level_06_update = null
	for index in range(5, 7):
		var definition := LevelRegistryScript.load_definition("level_%02d" % index)
		level_06_update = local_service.record_level_result(
			LevelResult.completed_result(definition, definition.par_shots),
			definition
		)
	passed = _contains_string(level_06_update.unlocked_cosmetic_ids, "ball_ice") and passed
	passed = _contains_string(level_06_update.unlocked_cosmetic_ids, "goal_confetti") and passed

	var level_08_update = null
	for index in range(7, 9):
		var definition := LevelRegistryScript.load_definition("level_%02d" % index)
		level_08_update = local_service.record_level_result(
			LevelResult.completed_result(definition, definition.par_shots),
			definition
		)
	passed = _contains_string(level_08_update.unlocked_cosmetic_ids, "trail_spark") and passed
	passed = _contains_string(level_08_update.unlocked_cosmetic_ids, "trail_rainbow") and passed

	var level_09 := LevelRegistryScript.load_definition("level_09")
	local_service.record_level_result(LevelResult.completed_result(level_09, level_09.par_shots), level_09)
	var level_10 := LevelRegistryScript.load_definition("level_10")
	var level_10_update = local_service.record_level_result(
		LevelResult.completed_result(level_10, level_10.par_shots),
		level_10
	)
	passed = _contains_string(level_10_update.unlocked_cosmetic_ids, "ball_galaxy") and passed
	passed = _contains_string(level_10_update.unlocked_cosmetic_ids, "ball_gold") and passed
	passed = _contains_string(level_10_update.unlocked_cosmetic_ids, "goal_shockwave") and passed
	passed = local_service.get_total_stars() == 30 and passed
	passed = local_service.evaluate_cosmetic_unlocks().is_empty() and passed
	passed = local_service.record_level_result(
		LevelResult.completed_result(level_10, level_10.shot_limit),
		level_10
	).unlocked_cosmetic_ids.is_empty() and passed

	var all_unlocked := _new_service("all_unlocked")
	all_unlocked.load_or_create()
	all_unlocked.unlock_all_cosmetics_for_development()
	passed = all_unlocked.get_unlocked_cosmetics().size() == 17 and passed
	local_service.free()
	all_unlocked.free()
	print("PHASE6 unlock_conditions ok=", passed)
	return passed


func _test_gameplay_application() -> bool:
	service.reset_to_defaults()
	service.unlock_all_cosmetics_for_development()
	service.set_selected_ball("ball_gold")
	service.set_selected_trail("trail_blue")
	service.set_selected_goal_effect("goal_shockwave")

	var scene: PackedScene = load("res://levels/level_01.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	await physics_frame
	await level.call("_restart_level")
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var shape := (ball.get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D
	var mass_before := ball.mass
	var radius_before := shape.radius
	var max_speed_before := float(level.get("maximum_launch_speed"))
	var main_mesh := ball.get_node("MeshInstance3D") as MeshInstance3D
	var trail = ball.get_node_or_null("NetboundBallTrail")
	var passed := main_mesh.material_override != null and trail != null
	passed = is_equal_approx(ball.mass, mass_before) and passed
	passed = is_equal_approx(shape.radius, radius_before) and passed
	passed = is_equal_approx(float(level.get("maximum_launch_speed")), max_speed_before) and passed

	for i in 5:
		ball.global_position += Vector3(0.4, 0.0, -0.1)
		ball.linear_velocity = Vector3(9.0, 0.0, -2.0)
		await physics_frame
	var any_trail_visible := false
	for child in trail.get_children():
		any_trail_visible = bool(child.visible) or any_trail_visible
	passed = any_trail_visible and passed

	level.set("selected_goal_effect_id", "goal_shockwave")
	level.call("_show_goal_feedback")
	await process_frame
	passed = _count_goal_effect_nodes(level) > 0 and passed
	level.call("_hide_overlays")
	await process_frame
	passed = _count_goal_effect_nodes(level) == 0 and passed
	Engine.time_scale = 1.0
	level.queue_free()
	await process_frame
	print("PHASE6 gameplay_application ok=", passed)
	return passed


func _test_cosmetics_screen() -> bool:
	service.reset_to_defaults()
	app.show_cosmetics()
	await process_frame
	var passed := app.current_screen_name == "cosmetics" \
		and app.cosmetic_category_buttons.size() == 3 \
		and app.cosmetic_card_buttons.size() == 7
	app._preview_cosmetic("ball_gold")
	await process_frame
	passed = app.previewed_cosmetic_id == "ball_gold" and passed
	passed = app.cosmetic_equip_button.disabled and passed
	passed = service.get_selected_ball() == "ball_classic" and passed
	app._equip_previewed_cosmetic()
	passed = service.get_selected_ball() == "ball_classic" and passed

	service.unlock_cosmetic("ball_gold")
	app._refresh_cosmetics_screen()
	await process_frame
	app._preview_cosmetic("ball_gold")
	app._equip_previewed_cosmetic()
	passed = service.get_selected_ball() == "ball_gold" and passed

	app._select_cosmetic_category("trail")
	await process_frame
	passed = app.cosmetic_card_buttons.size() == 6 and passed
	app._select_cosmetic_category("goal_effect")
	await process_frame
	passed = app.cosmetic_card_buttons.size() == 4 and passed
	app._handle_back_navigation()
	await process_frame
	passed = app.current_screen_name == "main_menu" or app.current_screen_name == "level_select" and passed
	print("PHASE6 cosmetics_screen ok=", passed)
	return passed


func _test_result_unlock_display() -> bool:
	service.reset_to_defaults()
	var level_01 := LevelRegistryScript.load_definition("level_01")
	service.record_level_result(LevelResult.completed_result(level_01, level_01.par_shots), level_01)
	var level_02 := LevelRegistryScript.load_definition("level_02")
	var result := LevelResult.completed_result(level_02, level_02.par_shots)
	var update = service.record_level_result(result, level_02)
	app._show_success_result(result, update)
	await process_frame
	var passed := _find_label_containing(app.result_overlay, "New Cosmetics Unlocked") != null
	passed = _find_label_containing(app.result_overlay, "Neon") != null and passed

	var repeat_update = service.record_level_result(result, level_02)
	app._show_success_result(result, repeat_update)
	await process_frame
	passed = _find_label_containing(app.result_overlay, "New Cosmetic") == null and passed
	print("PHASE6 result_unlock_display ok=", passed)
	return passed


func _test_all_production_level_startups() -> bool:
	service.reset_to_defaults()
	service.unlock_all_cosmetics_for_development()
	service.set_selected_ball("ball_galaxy")
	service.set_selected_trail("trail_rainbow")
	service.set_selected_goal_effect("goal_confetti")
	var passed := true
	for level_id in LevelRegistryScript.get_level_ids():
		var scene: PackedScene = load(LevelRegistryScript.get_scene_path(level_id))
		var level := scene.instantiate()
		get_root().add_child(level)
		await process_frame
		await process_frame
		passed = level.has_node("Ball") and level.has_node("Goal") and passed
		if level.has_method("prepare_for_unload"):
			level.call("prepare_for_unload")
		level.queue_free()
		await process_frame
	print("PHASE6 level_startups ok=", passed)
	return passed


func _new_service(suffix: String) -> Node:
	var local_service: Node = SaveServiceScript.new()
	var save_path := "user://phase6_%s.json" % suffix
	local_service.configure_storage_paths(
		save_path,
		"%s.tmp" % save_path,
		"%s.bak" % save_path,
		"%s.corrupt" % save_path
	)
	local_service.recording_enabled = true
	return local_service


func _contains_string(values: Array, needle: String) -> bool:
	for value in values:
		if String(value) == needle:
			return true
	return false


func _count_goal_effect_nodes(root: Node) -> int:
	var count := 0
	for child in root.find_children("*", "", true, false):
		if child.is_in_group("netbound_cosmetic_goal_effect"):
			count += 1
	return count


func _find_label_containing(root: Node, needle: String) -> Label:
	if not root:
		return null
	for child in root.find_children("*", "Label", true, false):
		var label := child as Label
		if label and label.text.contains(needle):
			return label
	return null


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.flush()
		file.close()


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for suffix in ["selection", "unlocks", "all_unlocked"]:
		_cleanup_paths(suffix)


func _cleanup_paths(suffix: String) -> void:
	var save_path := "user://phase6_%s.json" % suffix
	for path in [save_path, "%s.tmp" % save_path, "%s.bak" % save_path, "%s.corrupt" % save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
