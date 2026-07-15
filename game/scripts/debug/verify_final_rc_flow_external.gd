extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")

const TEST_SAVE := "user://final_rc_flow_test.json"
const TEST_TMP := "user://final_rc_flow_test.tmp"
const TEST_BAK := "user://final_rc_flow_test.bak"
const TEST_CORRUPT := "user://final_rc_flow_test.corrupt"

var service: NetboundSaveService
var monetization: Node
var app: NetboundApp


func _initialize() -> void:
	service = get_root().get_node("SaveService") as NetboundSaveService
	monetization = get_root().get_node("MonetizationService")
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_cleanup_test_files()
	_configure_isolated_save()
	service.reset_to_defaults()
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_ads", true, "success", "success", 1, false)
	monetization.call("apply_config_from_save", service)
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)

	var passed := _verify_fresh_state()
	passed = await _play_fail_restart_and_score() and passed
	passed = await _equip_cosmetic_change_settings_and_pause() and passed
	passed = await _relaunch_and_verify() and passed

	if app:
		app.queue_free()
		app = null
	await process_frame
	service.recording_enabled = false
	_cleanup_test_files()
	print("FINAL_RC_FLOW verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _verify_fresh_state() -> bool:
	var resolution := app.get_play_resolution()
	var passed := app.current_screen_name == "main_menu" \
		and service.get_completed_level_count() == 0 \
		and service.is_level_unlocked("level_01") \
		and not service.is_level_unlocked("level_02") \
		and String(resolution.get("level_id", "")) == "level_01" \
		and String(resolution.get("button_text", "")) == "Play"
	print("FINAL_RC_FLOW fresh ok=", passed)
	return passed


func _play_fail_restart_and_score() -> bool:
	var launched := app.request_continue()
	await _wait_frames(3)
	var level := app.current_level
	if not launched or not level or not await _wait_for_ready(level):
		print("FINAL_RC_FLOW gameplay ok=false launch_or_ready")
		return false

	var passed := true
	for miss_index in range(3):
		var missed := await _shoot_and_force_miss(level)
		passed = missed and passed
		if miss_index < 2:
			passed = await _wait_for_ready(level, 180) and passed
	var failure_state_ok: bool = int(level.get("level_state")) == level.LevelState.FAILED
	var failure_screen_ok := app.current_screen_name == "result"
	var try_again := _find_button_with_text(app.result_overlay, "TRY AGAIN")
	var free_try_again_ok := try_again != null
	passed = failure_state_ok and failure_screen_ok and free_try_again_ok and passed
	if try_again:
		try_again.emit_signal("pressed")
	await _wait_frames(6)
	level = app.current_level
	var restart_state_ok: bool = app.current_screen_name == "gameplay" \
		and level != null \
		and int(level.get("level_state")) == level.LevelState.READY \
		and int(level.get("shots_used")) == 0 \
		and int(level.get("shots_remaining")) == int(level.get("max_shots"))
	passed = restart_state_ok and passed

	var shot_started := await _send_production_swipe(level)
	var active_shot_id: int = level.get("active_shot_id")
	var goal: GoalTarget = level.get_node("Goal") as GoalTarget
	goal.reset_shot_tracking()
	goal.begin_shot_tracking(active_shot_id, Vector3(0.0, 2.5, -8.0))
	var scored := goal.process_ball(Vector3(0.0, 2.5, -12.0), 0.49, active_shot_id)
	await create_timer(0.5).timeout
	passed = shot_started and scored and passed
	passed = int(level.get("level_state")) == level.LevelState.GOAL and passed
	passed = service.is_level_completed("level_01") and passed
	passed = service.is_level_unlocked("level_02") and passed
	passed = service.get_best_stars("level_01") == 3 and passed
	passed = service.get_fewest_shots("level_01") == 1 and passed
	passed = app.current_screen_name == "result" and passed
	passed = app.result_next_button != null and not app.result_next_button.disabled and passed
	print(
		"FINAL_RC_FLOW gameplay ok=", passed,
		" failure_state=", failure_state_ok,
		" failure_screen=", failure_screen_ok,
		" free_try_again=", free_try_again_ok,
		" restart_state=", restart_state_ok,
		" shot=", shot_started,
		" scored=", scored,
		" final_state=", int(level.get("level_state")),
		" final_screen=", app.current_screen_name,
		" next_button=", app.result_next_button != null and not app.result_next_button.disabled,
		" completed=", service.is_level_completed("level_01"),
		" stars=", service.get_best_stars("level_01"),
		" fewest=", service.get_fewest_shots("level_01"),
		" level02=", service.is_level_unlocked("level_02")
	)
	return passed


func _equip_cosmetic_change_settings_and_pause() -> bool:
	# This is an isolated debug save; unlock the catalog so the flow can exercise
	# the real preview/equip UI without changing production progression rules.
	var passed := service.unlock_all_cosmetics_for_development()
	passed = app.show_cosmetics() and passed
	await _wait_frames(2)
	app.call("_preview_cosmetic", "ball_neon")
	await process_frame
	passed = app.cosmetic_equip_button != null \
		and not app.cosmetic_equip_button.disabled \
		and passed
	if app.cosmetic_equip_button:
		app.cosmetic_equip_button.emit_signal("pressed")
	await process_frame
	passed = service.get_selected_ball() == "ball_neon" and passed

	passed = app.show_settings("cosmetics") and passed
	await process_frame
	passed = app.set_setting_value("master_volume", 0.42) and passed
	passed = app.set_setting_value("quality_tier", "low") and passed
	passed = app.set_setting_value("reduced_motion_enabled", true) and passed
	await process_frame

	passed = app.load_level("level_02") and passed
	await _wait_frames(3)
	passed = app.current_level != null and await _wait_for_ready(app.current_level) and passed
	passed = app.show_pause_menu() and passed
	passed = paused and app.current_screen_name == "pause" and passed
	app.resume_game()
	passed = not paused and app.current_screen_name == "gameplay" and passed
	print("FINAL_RC_FLOW customize_pause ok=", passed)
	return passed


func _relaunch_and_verify() -> bool:
	app.queue_free()
	app = null
	await _wait_frames(2)
	_configure_isolated_save()
	var loaded := service.load_or_create()
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)
	var resolution := app.get_play_resolution()
	var passed := loaded \
		and service.is_level_completed("level_01") \
		and service.is_level_unlocked("level_02") \
		and service.get_best_stars("level_01") == 3 \
		and service.get_fewest_shots("level_01") == 1 \
		and service.get_selected_ball() == "ball_neon" \
		and is_equal_approx(float(service.get_setting_value("master_volume", 0.0)), 0.42) \
		and String(service.get_setting_value("quality_tier", "")) == "low" \
		and bool(service.get_setting_value("reduced_motion_enabled", false)) \
		and String(resolution.get("level_id", "")) == "level_02" \
		and String(resolution.get("button_text", "")) == "Continue"
	print("FINAL_RC_FLOW relaunch ok=", passed)
	return passed


func _shoot_and_force_miss(level: Node) -> bool:
	var shot_started := await _send_production_swipe(level)
	if not shot_started:
		return false
	var shot_id: int = level.get("active_shot_id")
	level.call("_resolve_miss", shot_id, "final_rc_flow_miss")
	await physics_frame
	return int(level.get("level_state")) in [level.LevelState.AUTO_RESETTING, level.LevelState.FAILED]


func _send_production_swipe(level: Node) -> bool:
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var camera: Camera3D = level.get_node("Camera3D") as Camera3D
	var shots_before: int = level.get("shots_remaining")
	var start := camera.unproject_position(ball.global_position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	level._unhandled_input(press)
	for index in range(13):
		var motion := InputEventMouseMotion.new()
		motion.position = start + Vector2(170.0, -20.0) * (float(index + 1) / 13.0)
		level._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start + Vector2(170.0, -20.0)
	level._unhandled_input(release)
	await physics_frame
	await physics_frame
	return int(level.get("level_state")) == level.LevelState.SHOT_ACTIVE \
		and int(level.get("shots_remaining")) == shots_before - 1 \
		and not ball.freeze \
		and ball.linear_velocity.length() > 0.5


func _wait_for_ready(level: Node, max_frames: int = 120) -> bool:
	for _index in range(max_frames):
		if int(level.get("level_state")) == level.LevelState.READY \
			and not bool(level.get("reset_in_progress")):
			return true
		await physics_frame
	return false


func _wait_frames(frame_count: int) -> void:
	for _index in range(frame_count):
		await process_frame


func _find_button_with_text(root: Node, text: String) -> Button:
	if not root:
		return null
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button and button.text == text:
			return button
	return null


func _configure_isolated_save() -> void:
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
