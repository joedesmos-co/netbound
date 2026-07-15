extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const TEST_SAVE := "user://rewarded_level_skip_test.json"
const TEST_TMP := "user://rewarded_level_skip_test.tmp"
const TEST_BAK := "user://rewarded_level_skip_test.bak"
const TEST_CORRUPT := "user://rewarded_level_skip_test.corrupt"

var service: NetboundSaveService
var wallet: NetboundWalletService
var monetization: NetboundMonetizationService
var app: NetboundApp


func _initialize() -> void:
	service = get_root().get_node("SaveService") as NetboundSaveService
	wallet = get_root().get_node("WalletService") as NetboundWalletService
	monetization = get_root().get_node("MonetizationService") as NetboundMonetizationService
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_cleanup_test_files()
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	wallet.configure_save_service(service)
	monetization.set_release_mode_enabled(false)

	var passed := await _test_production_failed_shot_tracking()
	passed = await _test_counter_boundaries() and passed
	passed = await _test_success_duplicate_and_later_normal_clear() and passed
	passed = await _test_cancel_failure_and_unavailable() and passed
	passed = await _test_delayed_navigation_and_normal_completion_race() and passed
	passed = await _test_atomic_rollback_and_v2_compatibility() and passed
	passed = await _test_level_20_assisted_result() and passed

	await _free_app()
	service.recording_enabled = false
	_cleanup_test_files()
	print("REWARDED_LEVEL_SKIP verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_counter_boundaries() -> bool:
	await _fresh_app()
	var passed := app.load_level("level_01")
	await _wait_frames(3)
	var level := app.current_level
	passed = level != null and await _wait_for_ready(level) and passed
	passed = await _send_production_swipe(level) and passed
	passed = _score_active_shot(level) and passed
	await _wait_frames(3)
	passed = app.get_session_failed_shot_count("level_01") == 0 and service.is_level_completed("level_01") and passed
	app.call("_on_shot_resolved_without_goal", "level_01", 999)
	passed = app.get_session_failed_shot_count("level_01") == 0 and passed

	passed = app.load_level("level_02") and passed
	await _wait_frames(3)
	level = app.current_level
	passed = level != null and await _wait_for_ready(level) and passed
	app.call("_on_shot_resolved_without_goal", "level_01", 1000)
	passed = app.get_session_failed_shot_count("level_02") == 0 and passed
	passed = await _send_production_swipe(level) and passed
	var shot_id := int(level.get("active_shot_id"))
	level.call("_resolve_miss", shot_id, "rewarded_skip_duplicate_test")
	level.call("_resolve_miss", shot_id, "rewarded_skip_duplicate_test")
	await physics_frame
	passed = app.get_session_failed_shot_count("level_02") == 1 and passed
	await app.restart_current_level()
	passed = await _wait_for_ready(level) and app.get_session_failed_shot_count("level_02") == 1 and passed
	for index in range(4):
		app.call("_on_shot_resolved_without_goal", "level_02", 2000 + index)
	passed = app.is_level_skip_eligible("level_02") and passed
	passed = await _send_production_swipe(level) and _score_active_shot(level) and passed
	await _wait_frames(3)
	passed = app.get_session_failed_shot_count("level_02") == 0 and not app.is_level_skip_eligible("level_02") and passed

	await _free_app()
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)
	passed = app.get_session_failed_shot_count("level_02") == 0 and passed
	print("REWARDED_LEVEL_SKIP counter_boundaries ok=", passed)
	return passed


func _test_production_failed_shot_tracking() -> bool:
	await _fresh_app()
	var passed := app.load_level("level_01")
	await _wait_frames(3)
	var level := app.current_level
	passed = level != null and await _wait_for_ready(level) and passed
	var shots_before := int(level.get("shots_remaining"))
	await _send_invalid_swipe(level)
	passed = int(level.get("shots_remaining")) == shots_before and app.get_session_failed_shot_count("level_01") == 0 and passed
	var counts: Array[int] = [app.get_session_failed_shot_count("level_01")]

	for miss_index in range(3):
		passed = await _shoot_and_force_miss(level) and passed
		counts.append(app.get_session_failed_shot_count("level_01"))
		if miss_index < 2:
			passed = await _wait_for_ready(level, 180) and passed
	passed = app.get_session_failed_shot_count("level_01") == 3 and not app.is_level_skip_eligible("level_01") and passed
	passed = _find_button(app.result_overlay, "WATCH & SKIP") == null and passed

	passed = app.load_level("level_01") and passed
	await _wait_frames(3)
	for _startup_frame in range(4):
		await physics_frame
	level = app.current_level
	passed = level != null and await _wait_for_ready(level) and passed
	for miss_index in range(3):
		passed = await _shoot_and_force_miss(level) and passed
		counts.append(app.get_session_failed_shot_count("level_01"))
		if miss_index < 2:
			passed = await _wait_for_ready(level, 180) and passed
	passed = app.get_session_failed_shot_count("level_01") == 6 and app.is_level_skip_eligible("level_01") and passed
	passed = _find_button(app.result_overlay, "WATCH & SKIP") != null and _find_button(app.result_overlay, "KEEP TRYING") != null and passed
	print("REWARDED_LEVEL_SKIP failed_tracking ok=", passed, " count=", app.get_session_failed_shot_count("level_01"), " sequence=", counts)
	return passed


func _test_success_duplicate_and_later_normal_clear() -> bool:
	await _fresh_app()
	await _prepare_failure_offer("level_01")
	monetization.configure_simulated_ads(true, "success", "success", 1, true)
	app.call("_show_failure_result", _failed_result("level_01"))
	var button := _find_button(app.result_overlay, "WATCH & SKIP")
	var passed := button != null
	if button:
		button.emit_signal("pressed")
	await _wait_frames(5)
	var assisted_text := _collect_text(app.result_overlay)
	passed = service.is_level_completed("level_01") and service.is_level_assisted("level_01") and not service.is_level_normally_completed("level_01") and passed
	passed = service.get_best_stars("level_01") == 1 and service.get_fewest_shots("level_01") == -1 and service.is_level_unlocked("level_02") and passed
	passed = wallet.get_coin_balance() == 0 and wallet.get_token_balance() == 0 and app.get_session_failed_shot_count("level_01") == 0 and passed
	passed = assisted_text.contains("ASSISTED CLEAR") and assisted_text.contains("NO BEST-SHOT RECORD") and not assisted_text.contains("ARCADE COINS") and passed

	var definition := LevelRegistryScript.load_definition("level_01")
	var normal_result := LevelResult.completed_result(definition, 1)
	var normal_update := service.record_level_result(normal_result, definition)
	passed = bool(normal_update.get("save_succeeded")) and bool(normal_update.get("first_completion")) and passed
	passed = service.is_level_normally_completed("level_01") and not service.is_level_assisted("level_01") and passed
	passed = service.get_best_stars("level_01") == 3 and service.get_fewest_shots("level_01") == 1 and wallet.get_coin_balance() == 475 and passed
	print("REWARDED_LEVEL_SKIP success_duplicate_normal ok=", passed, " coins=", wallet.get_coin_balance())
	return passed


func _test_cancel_failure_and_unavailable() -> bool:
	var passed := true
	for mode in ["cancel", "failure"]:
		await _fresh_app()
		await _prepare_failure_offer("level_01")
		monetization.configure_simulated_ads(true, mode, "success", 1, false)
		app.call("_show_failure_result", _failed_result("level_01"))
		var button := _find_button(app.result_overlay, "WATCH & SKIP")
		passed = button != null and passed
		if button:
			button.emit_signal("pressed")
		await _wait_frames(4)
		passed = not service.is_level_completed("level_01") and wallet.get_coin_balance() == 0 and passed
		passed = _find_button(app.result_overlay, "KEEP TRYING") != null and passed

	await _fresh_app()
	await _prepare_failure_offer("level_01")
	monetization.configure_simulated_ads(false, "unavailable", "success", 1, false)
	app.call("_show_failure_result", _failed_result("level_01"))
	passed = _find_button(app.result_overlay, "WATCH & SKIP") == null and _find_button(app.result_overlay, "TRY AGAIN") != null and passed
	passed = not service.is_level_completed("level_01") and wallet.get_coin_balance() == 0 and passed

	await _fresh_app()
	service.record_purchase("netbound_remove_ads", "rewarded_skip:remove_ads", "test")
	await _prepare_failure_offer("level_01")
	app.call("_show_failure_result", _failed_result("level_01"))
	passed = _find_button(app.result_overlay, "WATCH & SKIP") != null and passed
	print("REWARDED_LEVEL_SKIP cancel_failure_unavailable ok=", passed)
	return passed


func _test_delayed_navigation_and_normal_completion_race() -> bool:
	await _fresh_app()
	await _prepare_failure_offer("level_01")
	monetization.configure_simulated_ads(true, "success", "success", 8, false)
	app.call("_show_failure_result", _failed_result("level_01"))
	var button := _find_button(app.result_overlay, "WATCH & SKIP")
	var passed := button != null
	if button:
		button.emit_signal("pressed")
	passed = app.show_main_menu() and passed
	await _wait_frames(12)
	passed = app.current_screen_name == "main_menu" and service.is_level_assisted("level_01") and service.get_best_stars("level_01") == 1 and passed

	await _fresh_app()
	await _prepare_failure_offer("level_01")
	monetization.configure_simulated_ads(true, "success", "success", 12, false)
	app.call("_show_failure_result", _failed_result("level_01"))
	button = _find_button(app.result_overlay, "WATCH & SKIP")
	if button:
		button.emit_signal("pressed")
	passed = app.load_level("level_01") and passed
	await _wait_frames(4)
	passed = app.show_pause_menu() and passed
	app.resume_game()
	await _wait_frames(14)
	passed = app.current_screen_name == "gameplay" and service.is_level_assisted("level_01") and passed

	await _fresh_app()
	await _prepare_failure_offer("level_01")
	monetization.configure_simulated_ads(true, "success", "success", 8, false)
	app.call("_show_failure_result", _failed_result("level_01"))
	button = _find_button(app.result_overlay, "WATCH & SKIP")
	if button:
		button.emit_signal("pressed")
	var definition := LevelRegistryScript.load_definition("level_01")
	var normal_update := service.record_level_result(LevelResult.completed_result(definition, 1), definition)
	await _wait_frames(12)
	passed = bool(normal_update.get("save_succeeded")) and service.is_level_normally_completed("level_01") and not service.is_level_assisted("level_01") and passed
	passed = service.get_best_stars("level_01") == 3 and service.get_fewest_shots("level_01") == 1 and wallet.get_coin_balance() == 475 and passed
	print("REWARDED_LEVEL_SKIP delayed_races ok=", passed)
	return passed


func _test_atomic_rollback_and_v2_compatibility() -> bool:
	await _free_app()
	service.reset_to_defaults()
	var definition := LevelRegistryScript.load_definition("level_01")
	service.simulate_next_write_failure_for_tests()
	var failed_update := service.record_assisted_clear("level_01", definition, "rollback:1")
	var passed := not bool(failed_update.get("save_succeeded")) and not service.is_level_completed("level_01") and service.get_best_stars("level_01") == 0
	passed = wallet.get_coin_balance() == 0 and service.get_fewest_shots("level_01") == -1 and passed

	var normal_update := service.record_level_result(LevelResult.completed_result(definition, 1), definition)
	passed = bool(normal_update.get("save_succeeded")) and passed
	var legacy_v2 := service.get_save_data()
	var progression := legacy_v2.progression as Dictionary
	progression.erase("normal_completed_levels")
	progression.erase("assisted_levels")
	progression.erase("assisted_fulfillment_ids")
	_write_json(TEST_SAVE, legacy_v2)
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	passed = service.load_or_create() and service.is_level_normally_completed("level_01") and not service.is_level_assisted("level_01") and passed
	passed = service.get_best_stars("level_01") == 3 and service.get_fewest_shots("level_01") == 1 and passed
	var downgrade := service.record_assisted_clear("level_01", definition, "must-not-downgrade")
	passed = not bool(downgrade.get("save_succeeded")) and service.get_best_stars("level_01") == 3 and not service.is_level_assisted("level_01") and passed
	print("REWARDED_LEVEL_SKIP rollback_v2 ok=", passed)
	return passed


func _test_level_20_assisted_result() -> bool:
	await _free_app()
	service.reset_to_defaults()
	for level_id in LevelRegistryScript.get_level_ids():
		if level_id == "level_20":
			break
		var definition := LevelRegistryScript.load_definition(level_id)
		service.record_level_result(LevelResult.completed_result(definition, definition.par_shots), definition)
	var level_20 := LevelRegistryScript.load_definition("level_20")
	var coins_before := wallet.get_coin_balance()
	var update := service.record_assisted_clear("level_20", level_20, "level20:assisted:1")
	var passed := bool(update.get("save_succeeded")) and service.is_level_assisted("level_20") and not service.is_level_normally_completed("level_20")
	passed = service.get_best_stars("level_20") == 1 and service.get_fewest_shots("level_20") == -1 and wallet.get_coin_balance() == coins_before and passed
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)
	app.call("_show_success_result", LevelResult.assisted_result(level_20), update)
	var text := _collect_text(app.result_overlay)
	passed = text.contains("ASSISTED CLEAR") and text.contains("REPLAY FOR A FULL FINALE CLEAR") and not text.contains("ALL PRODUCTION LEVELS COMPLETE") and passed
	print("REWARDED_LEVEL_SKIP level20 ok=", passed)
	return passed


func _fresh_app() -> void:
	await _free_app()
	_cleanup_test_files()
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()
	wallet.configure_save_service(service)
	monetization.set_release_mode_enabled(false)
	monetization.reset_session_frequency_for_tests()
	monetization.configure_simulated_ads(true, "success", "success", 1, false)
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)


func _prepare_failure_offer(level_id: String) -> void:
	app.load_level(level_id)
	await _wait_frames(3)
	for shot_id in range(1, 6):
		app.call("_on_shot_resolved_without_goal", level_id, shot_id)


func _failed_result(level_id: String) -> LevelResult:
	var definition := LevelRegistryScript.load_definition(level_id)
	return LevelResult.failed_result(definition, definition.shot_limit, 0)


func _shoot_and_force_miss(level: Node) -> bool:
	var started := await _send_production_swipe(level)
	if not started:
		return false
	level.call("_resolve_miss", int(level.get("active_shot_id")), "rewarded_skip_test")
	await physics_frame
	return int(level.get("level_state")) in [level.LevelState.AUTO_RESETTING, level.LevelState.FAILED]


func _score_active_shot(level: Node) -> bool:
	var shot_id := int(level.get("active_shot_id"))
	var goal := level.get_node("Goal") as GoalTarget
	goal.reset_shot_tracking()
	goal.begin_shot_tracking(shot_id, Vector3(0.0, 2.5, -8.0))
	return goal.process_ball(Vector3(0.0, 2.5, -12.0), 0.49, shot_id)


func _send_production_swipe(level: Node) -> bool:
	var ball := level.get_node("Ball") as RigidBody3D
	var camera := level.get_node("Camera3D") as Camera3D
	var before := int(level.get("shots_remaining"))
	var start := camera.unproject_position(ball.global_position)
	_send_mouse_button(level, start, true)
	for index in range(13):
		var motion := InputEventMouseMotion.new()
		motion.position = start + Vector2(170.0, -20.0) * (float(index + 1) / 13.0)
		level._unhandled_input(motion)
	_send_mouse_button(level, start + Vector2(170.0, -20.0), false)
	await physics_frame
	await physics_frame
	return int(level.get("level_state")) == level.LevelState.SHOT_ACTIVE and int(level.get("shots_remaining")) == before - 1


func _send_invalid_swipe(level: Node) -> void:
	var ball := level.get_node("Ball") as RigidBody3D
	var camera := level.get_node("Camera3D") as Camera3D
	var start := camera.unproject_position(ball.global_position)
	_send_mouse_button(level, start, true)
	_send_mouse_button(level, start + Vector2(2.0, 0.0), false)
	await physics_frame


func _send_mouse_button(level: Node, position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	level._unhandled_input(event)


func _wait_for_ready(level: Node, max_frames: int = 120) -> bool:
	for _index in range(max_frames):
		if int(level.get("level_state")) == level.LevelState.READY and not bool(level.get("reset_in_progress")):
			return true
		await physics_frame
	return false


func _find_button(root: Node, text_value: String) -> Button:
	if not root:
		return null
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button and button.text == text_value:
			return button
	return null


func _collect_text(root: Node) -> String:
	var parts: Array[String] = []
	if not root:
		return ""
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label and not label.text.is_empty():
			parts.append(label.text)
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button and not button.text.is_empty():
			parts.append(button.text)
	return "\n".join(parts)


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", true))
	file.flush()
	file.close()


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _free_app() -> void:
	paused = false
	if app:
		app.queue_free()
		app = null
		await _wait_frames(3)


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
