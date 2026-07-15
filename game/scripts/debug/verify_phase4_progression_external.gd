extends SceneTree

const SaveServiceScript := preload("res://scripts/services/save_service.gd")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const TEST_SAVE := "user://phase4_progression_test.json"
const TEST_TMP := "user://phase4_progression_test.tmp"
const TEST_BAK := "user://phase4_progression_test.bak"
const TEST_CORRUPT := "user://phase4_progression_test.corrupt"

var _integration_level: Node


func _initialize() -> void:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	_integration_level = scene.instantiate()
	_integration_level.name = "Phase4IntegrationLevel"
	get_root().add_child(_integration_level)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := true
	_cleanup_test_files()
	passed = _test_defaults() and passed
	passed = _test_registry() and passed
	passed = _test_star_rules() and passed
	passed = _test_recording() and passed
	passed = _test_persistence() and passed
	passed = _test_corruption() and passed
	passed = _test_backup_recovery() and passed
	passed = _test_atomic_write() and passed
	var integration_ok := false
	var autoload_service = get_root().get_node_or_null("SaveService")
	if not autoload_service:
		print("PHASE4 integration ok=false missing_autoload")
	else:
		_cleanup_paths("integration")
		autoload_service.configure_storage_paths(
			"user://phase4_integration.json",
			"user://phase4_integration.tmp",
			"user://phase4_integration.bak",
			"user://phase4_integration.corrupt"
		)
		autoload_service.recording_enabled = true
		autoload_service.reset_to_defaults()

		var level := _integration_level
		await process_frame
		await process_frame
		await physics_frame
		await level._restart_level()
		var target: GoalTarget = level.get_node("Goal") as GoalTarget
		level.set("shots_remaining", 1)
		level.set("shots_used", int(level.get("max_shots")) - 1)
		var launched := await _shoot_real(level, Vector2(170.0, -20.0))
		var active_shot_id: int = level.get("active_shot_id")
		target.reset_shot_tracking()
		target.begin_shot_tracking(active_shot_id, Vector3(0.0, 2.5, -8.0))
		var scored := target.process_ball(Vector3(0.0, 2.5, -12.0), 0.49, active_shot_id)
		await physics_frame
		integration_ok = launched \
			and scored \
			and int(level.get("level_state")) == level.LevelState.GOAL \
			and autoload_service.is_level_completed("level_01") \
			and autoload_service.is_level_unlocked("level_02") \
			and autoload_service.get_best_stars("level_01") == 1 \
			and autoload_service.get_fewest_shots("level_01") == 3

		await level._restart_level()
		integration_ok = autoload_service.get_best_stars("level_01") == 1 and integration_ok
		if is_instance_valid(level):
			level.queue_free()
		await process_frame
		autoload_service.recording_enabled = false
		print("PHASE4 integration ok=", integration_ok)
	passed = integration_ok and passed
	_cleanup_test_files()
	print("PHASE4 verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _new_service(suffix: String = "") -> Node:
	var service: Node = SaveServiceScript.new()
	var save_path := TEST_SAVE if suffix.is_empty() else "user://phase4_%s.json" % suffix
	service.configure_storage_paths(
		save_path,
		"%s.tmp" % save_path,
		"%s.bak" % save_path,
		"%s.corrupt" % save_path
	)
	service.recording_enabled = true
	return service


func _test_defaults() -> bool:
	_cleanup_test_files()
	var service = _new_service()
	var loaded: bool = service.load_or_create()
	var passed: bool = loaded and FileAccess.file_exists(TEST_SAVE)
	passed = service.is_level_unlocked("level_01") and passed
	for level_id in LevelRegistryScript.get_level_ids():
		if level_id != "level_01":
			passed = not service.is_level_unlocked(level_id) and passed
		passed = not service.is_level_completed(level_id) and passed
		passed = service.get_best_stars(level_id) == 0 and passed
	passed = service.get_total_stars() == 0 and passed
	passed = service.get_selected_ball() == "ball_classic" and passed
	passed = service.get_selected_trail() == "trail_none" and passed
	passed = service.get_selected_goal_effect() == "goal_classic" and passed
	passed = bool(service.get_setting_value("haptics_enabled", false)) and passed
	service.free()
	print("PHASE4 defaults ok=", passed)
	return passed


func _test_registry() -> bool:
	var validation: Dictionary = LevelRegistryScript.validate_registry()
	var passed: bool = bool(validation.ok) \
		and LevelRegistryScript.get_entries().size() == 20 \
		and LevelRegistryScript.get_level_ids()[0] == "level_01" \
		and LevelRegistryScript.get_level_ids()[-1] == "level_20" \
		and LevelRegistryScript.get_next_level_id("level_09") == "level_10" \
		and LevelRegistryScript.get_next_level_id("level_10") == "level_11" \
		and LevelRegistryScript.get_next_level_id("level_19") == "level_20" \
		and LevelRegistryScript.get_next_level_id("level_20").is_empty()
	for level_id in LevelRegistryScript.get_level_ids():
		passed = ResourceLoader.exists(LevelRegistryScript.get_scene_path(level_id)) and passed
		passed = ResourceLoader.exists(LevelRegistryScript.get_definition_path(level_id)) and passed
	print("PHASE4 registry ok=", passed)
	return passed


func _test_star_rules() -> bool:
	var service = _new_service("stars")
	service.reset_to_defaults(false)
	var definition := LevelRegistryScript.load_definition("level_05")
	var passed: bool = true
	passed = service.calculate_stars(
		LevelResult.completed_result(definition, definition.par_shots),
		definition
	) == 3 and passed
	passed = service.calculate_stars(
		LevelResult.completed_result(definition, definition.par_shots + 1),
		definition
	) == 2 and passed
	passed = service.calculate_stars(
		LevelResult.completed_result(definition, definition.par_shots + 2),
		definition
	) == 1 and passed
	passed = service.calculate_stars(LevelResult.failed_result(definition, definition.shot_limit), definition) == 0 and passed

	var malformed := LevelDefinition.new()
	malformed.level_id = "bad_level"
	malformed.shot_limit = 2
	malformed.par_shots = 5
	var malformed_result := LevelResult.completed_result(malformed, 2)
	passed = service.calculate_stars(malformed_result, malformed) == 3 and passed
	passed = service.get_diagnostics().size() > 0 and passed
	service.free()
	print("PHASE4 stars ok=", passed)
	return passed


func _test_recording() -> bool:
	_cleanup_test_files()
	var service = _new_service()
	service.load_or_create()
	var level_01 := LevelRegistryScript.load_definition("level_01")
	var passed: bool = true

	var failure_total_before: int = service.get_total_stars()
	var failure = service.record_level_result(LevelResult.failed_result(level_01, 3), level_01)
	passed = service.get_total_stars() == failure_total_before and passed
	passed = not service.is_level_completed("level_01") and passed
	passed = not bool(failure.changed) and passed

	var locked_level_03 := LevelRegistryScript.load_definition("level_03")
	var locked_update = service.record_level_result(
		LevelResult.completed_result(locked_level_03, 1),
		locked_level_03
	)
	passed = not service.is_level_completed("level_03") and passed
	passed = not bool(locked_update.changed) and passed

	var first = service.record_level_result(LevelResult.completed_result(level_01, 1), level_01)
	passed = service.is_level_completed("level_01") and passed
	passed = service.is_level_unlocked("level_02") and passed
	passed = service.get_best_stars("level_01") == 3 and passed
	passed = service.get_fewest_shots("level_01") == 1 and passed
	passed = bool(first.did_unlock_new_level) and String(first.unlocked_level_id) == "level_02" and passed

	service.record_level_result(LevelResult.completed_result(level_01, 3), level_01)
	passed = service.get_best_stars("level_01") == 3 and passed
	passed = service.get_fewest_shots("level_01") == 1 and passed

	var level_02 := LevelRegistryScript.load_definition("level_02")
	service.record_level_result(LevelResult.completed_result(level_02, 2), level_02)
	passed = service.get_best_stars("level_02") == 2 and passed
	passed = service.get_total_stars() == 5 and passed

	var final_update = null
	for index in range(3, 21):
		var level_id := "level_%02d" % index
		var definition := LevelRegistryScript.load_definition(level_id)
		final_update = service.record_level_result(
			LevelResult.completed_result(definition, definition.par_shots),
			definition
		)
	passed = not bool(final_update.did_unlock_new_level) and passed
	passed = String(final_update.unlocked_level_id).is_empty() and passed
	passed = service.is_level_completed("level_20") and passed
	passed = service.get_save_data().progression.unlocked_levels.size() <= 20 and passed
	service.free()
	print("PHASE4 recording ok=", passed)
	return passed


func _test_persistence() -> bool:
	_cleanup_paths("persist")
	var service = _new_service("persist")
	service.load_or_create()
	service.set_setting_value("master_volume", 0.42)
	service.unlock_cosmetic("ball_gold")
	service.set_selected_ball("gold")
	service.mark_tutorial_complete("level_03")
	var level_01 := LevelRegistryScript.load_definition("level_01")
	service.record_level_result(LevelResult.completed_result(level_01, 1), level_01)

	var reloaded = _new_service("persist")
	var passed: bool = reloaded.load_or_create()
	passed = is_equal_approx(float(reloaded.get_setting_value("master_volume", 1.0)), 0.42) and passed
	passed = reloaded.get_selected_ball() == "ball_gold" and passed
	passed = reloaded.is_tutorial_complete("level_03") and passed
	passed = reloaded.is_level_completed("level_01") and passed
	passed = reloaded.is_level_unlocked("level_02") and passed
	passed = reloaded.get_best_stars("level_01") == 3 and passed
	service.free()
	reloaded.free()
	print("PHASE4 persistence ok=", passed)
	return passed


func _test_corruption() -> bool:
	_cleanup_paths("corrupt")
	var service = _new_service("corrupt")
	var save_path: String = service.get_save_path()
	_write_text(save_path, "{not json")
	var passed: bool = service.load_or_create()
	passed = FileAccess.file_exists(service.get_corrupt_path()) and passed
	passed = service.is_level_unlocked("level_01") and passed

	var partial := {
		"save_version": 1,
		"progression": {
			"unlocked_levels": ["level_99"],
			"completed_levels": ["level_02", "bogus"],
			"best_stars": {"level_02": 9, "bogus": 3},
			"fewest_shots": {"level_02": 99},
			"tutorial_completed": {"level_03": true, "bad": true},
			"total_stars": 99,
		},
		"cosmetics": {
			"selected_ball": "gold",
			"selected_trail": "spark",
			"selected_goal_effect": "confetti",
			"unlocked": ["ball:classic"],
		},
		"settings": {
			"master_volume": 2.0,
			"music_volume": -1.0,
			"sfx_volume": 0.5,
			"haptics_enabled": false,
			"developer_debug": true,
		},
		"future_field": {"keep": true},
	}
	_write_text(save_path, JSON.stringify(partial, "\t", true))
	var normalized = _new_service("corrupt")
	passed = normalized.load_or_create() and passed
	passed = normalized.is_level_unlocked("level_01") and passed
	passed = normalized.is_level_completed("level_02") and passed
	passed = not normalized.is_level_unlocked("level_99") and passed
	passed = normalized.get_best_stars("level_02") == 3 and passed
	var level_02_limit := LevelRegistryScript.load_definition("level_02").shot_limit
	passed = normalized.get_fewest_shots("level_02") == level_02_limit + 1 and passed
	passed = normalized.get_selected_ball() == "ball_classic" and passed
	passed = is_equal_approx(float(normalized.get_setting_value("master_volume", 0.0)), 1.0) and passed
	passed = is_equal_approx(float(normalized.get_setting_value("music_volume", 1.0)), 0.0) and passed
	passed = bool(normalized.get_save_data().has("future_field")) and passed
	service.free()
	normalized.free()
	print("PHASE4 corruption ok=", passed)
	return passed


func _test_backup_recovery() -> bool:
	_cleanup_paths("backup_recovery")
	var source = _new_service("backup_recovery")
	source.load_or_create()
	var level_01 := LevelRegistryScript.load_definition("level_01")
	source.record_level_result(LevelResult.completed_result(level_01, 1), level_01)
	source.set_setting_value("master_volume", 0.42)
	var save_path: String = source.get_save_path()
	var backup_path: String = source.get_backup_path()
	_write_text(backup_path, FileAccess.get_file_as_string(save_path))
	_write_text(save_path, "{broken primary")

	var recovered = _new_service("backup_recovery")
	var passed: bool = recovered.load_or_create()
	passed = recovered.is_level_completed("level_01") and passed
	passed = recovered.is_level_unlocked("level_02") and passed
	passed = recovered.get_best_stars("level_01") == 3 and passed
	passed = is_equal_approx(float(recovered.get_setting_value("master_volume", 1.0)), 0.42) and passed
	passed = FileAccess.file_exists(recovered.get_corrupt_path()) and passed
	source.free()
	recovered.free()
	print("PHASE4 backup_recovery ok=", passed)
	return passed


func _test_atomic_write() -> bool:
	_cleanup_paths("atomic")
	var service = _new_service("atomic")
	service.load_or_create()
	var original_text := FileAccess.get_file_as_string(service.get_save_path())
	service.unlock_cosmetic("ball_gold")
	var passed: bool = FileAccess.file_exists(service.get_save_path()) \
		and FileAccess.file_exists(service.get_backup_path()) \
		and not FileAccess.file_exists(service.get_temp_path())
	passed = FileAccess.get_file_as_string(service.get_backup_path()) == original_text and passed

	service.simulate_next_write_failure_for_tests()
	var failed: bool = service.set_setting_value("master_volume", 0.25)
	passed = not failed and passed
	passed = FileAccess.file_exists(service.get_save_path()) and passed
	var reload = _new_service("atomic")
	passed = reload.load_or_create() and passed
	service.free()
	reload.free()
	print("PHASE4 atomic ok=", passed)
	return passed


func _shoot_real(level: Node, offset: Vector2) -> bool:
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var camera: Camera3D = level.get_node("Camera3D") as Camera3D
	var state_before: int = level.get("level_state")
	var shots_before: int = level.get("shots_remaining")
	_send_mouse_swipe(level, camera, ball, _line_offsets(offset, 8))
	await physics_frame
	await physics_frame
	return state_before == level.LevelState.READY \
		and int(level.get("level_state")) == level.LevelState.SHOT_ACTIVE \
		and int(level.get("shots_remaining")) == shots_before - 1 \
		and ball.linear_velocity.length() > 0.5


func _send_mouse_swipe(
	level: Node,
	camera: Camera3D,
	ball: RigidBody3D,
	offset_points: PackedVector2Array
) -> void:
	var start := camera.unproject_position(ball.global_position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	level._unhandled_input(press)
	for point_offset in offset_points:
		var motion := InputEventMouseMotion.new()
		motion.position = start + point_offset
		level._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start + offset_points[-1]
	level._unhandled_input(release)


func _line_offsets(offset: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(offset * (float(i + 1) / float(count)))
	return points


func _cleanup_test_files() -> void:
	for path in [
		TEST_SAVE,
		TEST_TMP,
		TEST_BAK,
		TEST_CORRUPT,
		"%s.tmp" % TEST_SAVE,
		"%s.bak" % TEST_SAVE,
		"%s.corrupt" % TEST_SAVE,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for suffix in ["stars", "persist", "corrupt", "backup_recovery", "atomic", "integration"]:
		_cleanup_paths(suffix)


func _cleanup_paths(suffix: String) -> void:
	var save_path := "user://phase4_%s.json" % suffix
	for path in [save_path, "%s.tmp" % save_path, "%s.bak" % save_path, "%s.corrupt" % save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.flush()
		file.close()
