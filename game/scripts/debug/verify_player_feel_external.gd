extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const TEST_SAVE := "user://player_feel_test.json"
const TEST_TMP := "user://player_feel_test.tmp"
const TEST_BAK := "user://player_feel_test.bak"
const TEST_CORRUPT := "user://player_feel_test.corrupt"

var service: NetboundSaveService
var audio_service: NetboundAudioService


func _initialize() -> void:
	service = get_root().get_node("SaveService") as NetboundSaveService
	audio_service = get_root().get_node("AudioService") as NetboundAudioService
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := true
	passed = await _test_shot_and_retry_language() and passed
	passed = await _test_success_color_language() and passed
	passed = await _test_success_audio_hierarchy() and passed
	await create_timer(0.8, true, false, true).timeout
	_cleanup()
	print("PLAYER_FEEL verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_shot_and_retry_language() -> bool:
	var app := AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)
	var launched := app.load_level("level_01")
	await _wait_frames(4)
	var level := app.current_level
	var definition := LevelRegistryScript.load_definition("level_01")
	var passed := launched and level != null
	passed = String(level.get_node("UI/TopBar/ShotsLabel").text).contains("SHOTS  00") and passed
	passed = String(level.get_node("UI/TopBar/ShotsLabel").text).contains("PAR  01") and passed

	level.set("shots_used", 1)
	level.set("shots_remaining", definition.shot_limit - 1)
	await level.call("_on_reset_button_pressed")
	passed = int(level.get("shots_used")) == 1 and passed
	passed = int(level.get("shots_remaining")) == definition.shot_limit - 1 and passed
	await level.call("_restart_level")
	passed = int(level.get("shots_used")) == 0 and passed
	passed = int(level.get("shots_remaining")) == definition.shot_limit and passed

	level.set("shots_used", definition.shot_limit)
	level.set("shots_remaining", 0)
	level.set("level_state", level.LevelState.FAILED)
	app.call("_show_failure_result", LevelResult.failed_result(definition, definition.shot_limit, 0))
	await process_frame
	var result_text := _collect_control_text(app.result_overlay)
	passed = result_text.contains("TRY AGAIN") and passed
	passed = not result_text.contains("+1 SHOT") and passed
	passed = not level.has_method("grant_rewarded_continue") and passed

	app.show_store("main_menu")
	await process_frame
	passed = app.store_rewarded_token_button != null and passed
	passed = app.store_rewarded_token_button.text.contains("+2 TOKENS") and passed
	app.queue_free()
	await _wait_frames(3)
	print("PLAYER_FEEL shots_retry ok=", passed)
	return passed


func _test_success_color_language() -> bool:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await _wait_frames(3)
	await physics_frame
	var flash := level.get_node("UI/GoalFlash") as ColorRect
	var visual = level.get_node("LevelVisualPolish")
	var goal_material := visual.get("_goal_material") as StandardMaterial3D

	service.set_setting_value("reduced_motion_enabled", false)
	level.call("_show_goal_feedback")
	var passed := flash.visible \
		and flash.color.g > flash.color.r * 2.0 \
		and flash.color.g > flash.color.b \
		and flash.modulate.a <= 0.3
	passed = goal_material != null and goal_material.albedo_color.is_equal_approx(Color.WHITE) and passed
	level.call("_hide_overlays")

	service.set_setting_value("reduced_motion_enabled", true)
	level.call("_show_goal_feedback")
	passed = not flash.visible and passed
	passed = goal_material.albedo_color.is_equal_approx(Color.WHITE) and passed
	level.call("prepare_for_unload")
	level.queue_free()
	await _wait_frames(3)
	service.set_setting_value("reduced_motion_enabled", false)
	print("PLAYER_FEEL success_color ok=", passed)
	return passed


func _test_success_audio_hierarchy() -> bool:
	var goal_stream := load("res://audio/generated/goal_scored.wav") as AudioStreamWAV
	var result_stream := load("res://audio/generated/result_success.wav") as AudioStreamWAV
	var passed := goal_stream != null and result_stream != null
	passed = goal_stream.get_length() <= 0.35 and passed
	passed = result_stream.get_length() <= 0.6 and passed
	passed = NetboundApp.RESULT_REVEAL_DELAY >= goal_stream.get_length() and passed

	service.set_setting_value("sfx_volume", 0.0)
	audio_service.apply_settings_from_save(service)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	passed = AudioServer.get_bus_volume_db(sfx_bus) <= -79.0 and passed
	service.set_setting_value("sfx_volume", 1.0)
	audio_service.apply_settings_from_save(service)
	audio_service.cleanup_scene_audio()
	var first_goal := audio_service.play_sfx("goal_scored", 0.82)
	var duplicate_goal := audio_service.play_sfx("goal_scored", 0.82)
	passed = first_goal and not duplicate_goal and passed
	audio_service.cleanup_scene_audio()
	print("PLAYER_FEEL success_audio ok=", passed)
	return passed


func _collect_control_text(root: Node) -> String:
	var text := ""
	if not root:
		return text
	for node in root.find_children("*", "Control", true, false):
		if node is Label:
			text += (node as Label).text + "\n"
		elif node is Button:
			text += (node as Button).text + "\n"
	return text


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _cleanup() -> void:
	service.recording_enabled = false
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
