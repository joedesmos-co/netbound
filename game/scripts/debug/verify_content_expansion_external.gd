extends SceneTree

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const SaveServiceScript := preload("res://scripts/services/save_service.gd")

const TEST_SAVE := "user://content_expansion_v2.json"
const TEST_TMP := "user://content_expansion_v2.tmp"
const TEST_BAK := "user://content_expansion_v2.bak"
const TEST_CORRUPT := "user://content_expansion_v2.corrupt"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := true
	passed = _verify_registry() and passed
	passed = await _verify_moving_goal_sync() and passed
	passed = await _verify_visual_language() and passed
	passed = _verify_version_two_expansion_migration() and passed
	_cleanup()
	print("CONTENT_EXPANSION verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _verify_registry() -> bool:
	var ids := LevelRegistryScript.get_level_ids()
	var validation := LevelRegistryScript.validate_registry()
	var passed := bool(validation.ok) and ids.size() == 20
	for index in ids.size():
		var expected_id := "level_%02d" % (index + 1)
		var expected_next := "level_%02d" % (index + 2) if index < 19 else ""
		passed = ids[index] == expected_id and passed
		passed = LevelRegistryScript.get_next_level_id(expected_id) == expected_next and passed
		passed = ResourceLoader.exists(LevelRegistryScript.get_scene_path(expected_id)) and passed
		passed = ResourceLoader.exists(LevelRegistryScript.get_definition_path(expected_id)) and passed
	print("CONTENT_EXPANSION registry count=", ids.size(), " ok=", passed)
	return passed


func _verify_moving_goal_sync() -> bool:
	var scene: PackedScene = load("res://levels/level_17.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	await physics_frame
	await level._restart_level()
	var goal := level.get_node("Goal") as GoalTarget
	var ball := level.get_node("Ball") as RigidBody3D
	var start_position := goal.global_position
	goal.begin_shot_tracking(7001, ball.global_position)
	for _frame in 36:
		await physics_frame
	var moved := goal.global_position.distance_to(start_position) > 0.1
	goal.process_ball(ball.global_position, 0.49, 7001)
	var passed := moved and goal.geometry_matches_detector()
	print(
		"CONTENT_EXPANSION moving_goal moved=", moved,
		" start=", start_position,
		" current=", goal.global_position,
		" synced=", goal.geometry_matches_detector(),
		" ok=", passed
	)
	level.queue_free()
	await process_frame
	return passed


func _verify_visual_language() -> bool:
	var scene: PackedScene = load("res://levels/level_20.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	await physics_frame
	var goal_mesh := level.get_node("Goal/LeftPost/MeshInstance3D") as MeshInstance3D
	var mover_mesh := level.get_node("CrossSlider/MeshInstance3D") as MeshInstance3D
	var static_mesh := level.get_node("FrontShield/MeshInstance3D") as MeshInstance3D
	var placeholder := level.get_node("Obstacle") as StaticBody3D
	var goal_material := goal_mesh.material_override as StandardMaterial3D
	var mover_material := mover_mesh.material_override as StandardMaterial3D
	var static_material := static_mesh.material_override as StandardMaterial3D
	var goal_color := goal_material.albedo_color if goal_material else Color.BLACK
	var mover_color := mover_material.albedo_color if mover_material else Color.BLACK
	var static_color := static_material.albedo_color if static_material else Color.BLACK
	var color_distance := Vector3(mover_color.r, mover_color.g, mover_color.b).distance_to(
		Vector3(static_color.r, static_color.g, static_color.b)
	)
	var colors_distinct: bool = (
		mover_material
		and static_material
		and color_distance > 0.25
	)
	var passed: bool = (
		goal_color.r >= 0.95
		and goal_color.g >= 0.95
		and goal_color.b >= 0.95
		and colors_distinct
		and not placeholder.visible
		and placeholder.collision_layer == 0
	)
	print(
		"CONTENT_EXPANSION visuals goal=", goal_color,
		" mechanics_distinct=", colors_distinct,
		" placeholder_hidden=", not placeholder.visible,
		" ok=", passed
	)
	level.queue_free()
	await process_frame
	return passed


func _verify_version_two_expansion_migration() -> bool:
	_cleanup()
	var completed: Array = []
	var unlocked: Array = []
	var best_stars: Dictionary = {}
	var fewest_shots: Dictionary = {}
	var star_rewards: Dictionary = {}
	var best_rewards: Dictionary = {}
	for index in range(1, 11):
		var level_id := "level_%02d" % index
		completed.append(level_id)
		unlocked.append(level_id)
		best_stars[level_id] = 3
		fewest_shots[level_id] = 1
		star_rewards[level_id] = 3
		best_rewards[level_id] = 1
	var legacy_v2 := {
		"save_version": 2,
		"progression": {
			"unlocked_levels": unlocked,
			"completed_levels": completed,
			"best_stars": best_stars,
			"fewest_shots": fewest_shots,
			"tutorial_completed": {},
			"total_stars": 30,
		},
		"cosmetics": {
			"selected_ball": "ball_neon",
			"selected_trail": "trail_none",
			"selected_goal_effect": "goal_classic",
			"unlocked": ["ball_classic", "ball_neon", "trail_none", "goal_classic"],
			"purchased": [],
		},
		"settings": {},
		"monetization": {},
		"economy": {
			"arcade_coins": 4321,
			"net_tokens": 87,
			"processed_transaction_ids": ["legacy_tx"],
			"transaction_history": [],
			"daily_rewarded_tokens": {},
			"first_completion_rewards": completed,
			"rewarded_star_milestones": star_rewards,
			"rewarded_best_shots": best_rewards,
			"next_transaction_sequence": 12,
		},
	}
	_write_json(TEST_SAVE, legacy_v2)
	var service = SaveServiceScript.new()
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	var loaded := service.load_or_create()
	var data: Dictionary = service.get_save_data()
	var economy: Dictionary = data.economy
	var passed := (
		loaded
		and int(data.save_version) == 2
		and service.is_level_completed("level_10")
		and service.is_level_unlocked("level_11")
		and not service.is_level_unlocked("level_12")
		and service.get_total_stars() == 30
		and service.get_selected_ball() == "ball_neon"
		and int(economy.arcade_coins) == 4321
		and int(economy.net_tokens) == 87
		and (economy.first_completion_rewards as Array).size() == 10
		and (economy.rewarded_star_milestones as Dictionary).size() == 10
		and (economy.rewarded_best_shots as Dictionary).size() == 10
	)
	print(
		"CONTENT_EXPANSION migration unlocked11=", service.is_level_unlocked("level_11"),
		" stars=", service.get_total_stars(),
		" coins=", economy.arcade_coins,
		" tokens=", economy.net_tokens,
		" ok=", passed
	)
	service.free()
	return passed


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t", true))
	file.flush()
	file.close()


func _cleanup() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
