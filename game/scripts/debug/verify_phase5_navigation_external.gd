extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const TEST_SAVE := "user://phase5_navigation_test.json"
const TEST_TMP := "user://phase5_navigation_test.tmp"
const TEST_BAK := "user://phase5_navigation_test.bak"
const TEST_CORRUPT := "user://phase5_navigation_test.corrupt"

var app: NetboundApp
var service: Node


func _initialize() -> void:
	service = get_root().get_node("SaveService")
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()
	var passed := true
	passed = _test_app_startup() and passed
	passed = await _test_play_resolution() and passed
	passed = await _test_level_select() and passed
	passed = await _test_level_launch_and_pause() and passed
	passed = await _test_results() and passed
	passed = await _test_settings() and passed
	passed = await _test_responsive_structure() and passed
	_cleanup_test_files()
	print("PHASE5 verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_app_startup() -> bool:
	var main_scene := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	var passed := main_scene == "res://app/netbound_app.tscn" \
		and app.current_screen_name == "main_menu"
	app.navigation_in_progress = true
	var blocked := not app.load_level("level_01")
	app.navigation_in_progress = false
	passed = blocked and passed
	print("PHASE5 startup ok=", passed)
	return passed


func _test_play_resolution() -> bool:
	service.reset_to_defaults()
	await process_frame
	var first := app.get_play_resolution()
	app.show_main_menu()
	await process_frame
	var passed := String(first.get("action", "")) == "level" \
		and String(first.get("level_id", "")) == "level_01" \
		and String(first.get("button_text", "")) == "Play" \
		and not String(first.get("subtitle", "")).begins_with("Continue") \
		and app.play_button.text == "Play" \
		and app.play_button.size.x <= 400.0 \
		and app.get_app_version_label() == "v0.9.0 RC"
	_record_completion("level_01", 1)
	var second := app.get_play_resolution()
	passed = String(second.get("action", "")) == "level" \
		and String(second.get("level_id", "")) == "level_02" \
		and String(second.get("button_text", "")) == "Continue" \
		and passed
	for level_id in LevelRegistryScript.get_level_ids():
		if not service.is_level_completed(level_id):
			_record_completion(level_id, LevelRegistryScript.load_definition(level_id).par_shots)
	var complete := app.get_play_resolution()
	passed = String(complete.get("action", "")) == "level_select" \
		and String(complete.get("button_text", "")) == "Level Select" \
		and passed
	if not passed:
		print("PHASE5 play_resolution detail first=", first, " second=", second, " complete=", complete)
	service.reset_to_defaults()
	print("PHASE5 play_resolution ok=", passed)
	return passed


func _test_level_select() -> bool:
	service.reset_to_defaults()
	app.show_level_select()
	await process_frame
	var passed := app.current_screen_name == "level_select" \
		and app.get_registered_level_card_count() == 20
	var first_card := app.level_card_buttons.get("level_01") as Button
	var second_card := app.level_card_buttons.get("level_02") as Button
	passed = first_card and not first_card.disabled and passed
	passed = second_card and second_card.disabled and passed
	passed = app.total_stars_label.text == "Stars: 0 / 60" and passed
	passed = not app.request_level_launch("level_02") and passed
	await process_frame
	passed = app.current_screen_name == "level_select" and passed
	print("PHASE5 level_select ok=", passed)
	return passed


func _test_level_launch_and_pause() -> bool:
	service.reset_to_defaults()
	var launched := app.request_level_launch("level_01")
	await _warmup_level()
	var passed := launched \
		and app.current_level != null \
		and app.current_level_id == "level_01" \
		and app.current_screen_name == "gameplay"
	passed = not bool(app.current_level.get_node("UI/TopLeftUI/PowerLabel").visible) and passed
	passed = not bool(app.current_level.get_node("UI/TopLeftUI/RetryLevelButton").visible) and passed
	passed = app.show_pause_menu() and passed
	passed = paused and app.current_screen_name == "pause" and passed
	app.resume_game()
	await process_frame
	passed = not paused and app.current_screen_name == "gameplay" and passed
	await app.restart_current_level()
	await process_frame
	passed = int(app.current_level.get("level_state")) == app.current_level.LevelState.READY and passed
	print("PHASE5 launch_pause ok=", passed)
	return passed


func _test_results() -> bool:
	service.reset_to_defaults()
	app.load_level("level_01")
	await _warmup_level()
	var level := app.current_level
	await level.call("_restart_level")
	level.set("shots_remaining", 0)
	level.set("shots_used", int(level.get("max_shots")))
	level.set("level_state", 1)
	level.call("_on_goal_scored")
	await create_timer(0.65, false, false, true).timeout
	var passed: bool = app.current_screen_name == "result" \
		and app.result_title_label.text == "Goal Complete" \
		and app.result_next_button \
		and not app.result_next_button.disabled \
		and service.is_level_completed("level_01") \
		and service.is_level_unlocked("level_02")
	passed = int(level.get("level_state")) == level.LevelState.GOAL and passed
	if not passed:
		print(
			"PHASE5 result detail screen=", app.current_screen_name,
			" title=", app.result_title_label.text if app.result_title_label else "<none>",
			" next=", app.result_next_button != null,
			" next_disabled=", app.result_next_button.disabled if app.result_next_button else true,
			" complete01=", service.is_level_completed("level_01"),
			" unlocked02=", service.is_level_unlocked("level_02"),
			" state=", int(level.get("level_state"))
		)

	app.load_level("level_02")
	await _warmup_level()
	var total_before: int = service.get_total_stars()
	var fail_result := LevelResult.failed_result(LevelRegistryScript.load_definition("level_02"), 3, 0)
	app._show_failure_result(fail_result)
	passed = app.result_title_label.text == "Out of Shots" and service.get_total_stars() == total_before and passed

	for level_id in LevelRegistryScript.get_level_ids():
		if not service.is_level_completed(level_id):
			_record_completion(level_id, LevelRegistryScript.load_definition(level_id).par_shots)
	var final_definition := LevelRegistryScript.load_definition("level_20")
	var final_update = service.record_level_result(
		LevelResult.completed_result(final_definition, final_definition.par_shots),
		final_definition
	)
	app._show_success_result(
		LevelResult.completed_result(final_definition, final_definition.par_shots),
		final_update
	)
	passed = app.result_next_button.disabled and passed
	print("PHASE5 results ok=", passed)
	return passed


func _test_settings() -> bool:
	app.show_settings("main_menu")
	await process_frame
	var passed := app.current_screen_name == "settings"
	passed = app.set_setting_value("master_volume", 0.37) and passed
	passed = is_equal_approx(float(service.get_setting_value("master_volume", 1.0)), 0.37) and passed
	app.show_main_menu()
	await process_frame
	app.show_settings("main_menu")
	await process_frame
	var slider := (app.settings_widgets.master_volume as Dictionary).slider as HSlider
	passed = is_equal_approx(slider.value, 0.37) and passed
	if not OS.is_debug_build():
		passed = not app.settings_widgets.has("developer_debug") and passed
	print("PHASE5 settings ok=", passed)
	return passed


func _test_responsive_structure() -> bool:
	app.show_level_select()
	await process_frame
	var passed := true
	for button in app.level_card_buttons.values():
		var card := button as Button
		passed = card.custom_minimum_size.x >= 48.0 and card.custom_minimum_size.y >= 48.0 and passed
	app.show_cosmetics()
	await process_frame
	passed = app.current_screen_name == "cosmetics" and passed
	app._handle_back_navigation()
	await process_frame
	passed = app.current_screen_name == "level_select" or app.current_screen_name == "main_menu" and passed
	print("PHASE5 responsive ok=", passed)
	return passed


func _record_completion(level_id: String, shots_used: int) -> void:
	var definition := LevelRegistryScript.load_definition(level_id)
	service.record_level_result(LevelResult.completed_result(definition, shots_used), definition)


func _warmup_level() -> void:
	await process_frame
	await process_frame
	await physics_frame


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
