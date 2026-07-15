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
	passed = await _test_curve_gesture_intent() and passed
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


func _test_curve_gesture_intent() -> bool:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await _wait_frames(3)
	await physics_frame
	var start := Vector2(420.0, 600.0)
	var end := Vector2(420.0, 380.0)
	var straight := _measure_curve(level, _bowed_gesture(start, end, 0.0, 13))
	var wobble := _measure_curve(level, _wobble_gesture(start, end, 1.4, 17))
	var mild_right := _measure_curve(level, _bowed_gesture(start, end, 10.0, 13))
	var mild_left := _measure_curve(level, _bowed_gesture(start, end, -10.0, 13))
	var strong_right := _measure_curve(level, _bowed_gesture(start, end, 38.0, 13))
	var strong_left := _measure_curve(level, _bowed_gesture(start, end, -38.0, 13))
	var start_hook := _measure_curve(
		level,
		_cubic_gesture(start, start + Vector2(48.0, -18.0), start + Vector2(8.0, -145.0), end, 13)
	)
	var end_hook := _measure_curve(
		level,
		_cubic_gesture(start, start + Vector2(8.0, -75.0), end + Vector2(48.0, 18.0), end, 13)
	)
	var sparse := _measure_curve(level, PackedVector2Array([start, (start + end) * 0.5 + Vector2(14.0, 0.0), end]))
	var short_curve := _measure_curve(level, _bowed_gesture(start, start + Vector2(0.0, -80.0), 8.0, 9))
	var long_curve := _measure_curve(level, _bowed_gesture(start, start + Vector2(0.0, -240.0), 24.0, 21))

	var passed := absf(straight) <= 0.02 \
		and absf(wobble) <= 0.02 \
		and mild_right >= 0.12 and mild_right <= 0.6 \
		and mild_left <= -0.12 and mild_left >= -0.6 \
		and strong_right > mild_right + 0.22 \
		and strong_left < mild_left - 0.22 \
		and absf(strong_right) <= float(level.get("maximum_curve_amount")) \
		and absf(strong_left) <= float(level.get("maximum_curve_amount")) \
		and start_hook >= 0.12 \
		and end_hook >= 0.12 \
		and sparse >= 0.12 \
		and absf(short_curve - long_curve) <= 0.14

	level.set("swipe_screen_points", _bowed_gesture(start, end, 10.0, 13))
	level.set("is_swiping", true)
	level.call("_recalculate_swipe_state")
	level.call("_update_swipe_visuals")
	var overlay := level.get_node("UI/SwipeOverlay") as SwipeOverlay
	passed = is_equal_approx(
		overlay.curve_strength,
		absf(float(level.get("current_curve_amount")))
	) and passed
	var diagnostics: Dictionary = level.get("current_curve_diagnostics")
	passed = int(diagnostics.get("sample_count", 0)) == 14 and passed
	passed = float(diagnostics.get("path_length", 0.0)) >= float(diagnostics.get("chord_length", 0.0)) and passed
	passed = String(diagnostics.get("direction", "")) == "RIGHT" and passed
	var ball := level.get_node("Ball") as RigidBody3D
	var camera := level.get_node("Camera3D") as Camera3D
	var input_start := camera.unproject_position(ball.global_position)
	var input_points := _bowed_gesture(input_start, input_start + Vector2(0.0, -180.0), 12.0, 13)
	var mouse_curve := _measure_input_curve(level, input_points, false)
	var touch_curve := _measure_input_curve(level, input_points, true)
	passed = mouse_curve >= 0.12 and touch_curve >= 0.12 and passed
	passed = absf(mouse_curve - touch_curve) <= 0.08 and passed

	level.call("cancel_active_gesture_for_lifecycle")
	level.call("prepare_for_unload")
	level.queue_free()
	await _wait_frames(3)
	print(
		"PLAYER_FEEL curve_intent ok=", passed,
		" straight=", straight,
		" wobble=", wobble,
		" mild=", [mild_left, mild_right],
		" strong=", [strong_left, strong_right],
		" hooks=", [start_hook, end_hook],
		" sparse=", sparse,
		" normalized=", [short_curve, long_curve],
		" mouse_touch=", [mouse_curve, touch_curve]
	)
	return passed


func _measure_curve(level: Node, points: PackedVector2Array) -> float:
	level.set("swipe_screen_points", points)
	return float(level.call("_calculate_curve_amount", points[0], points[-1]))


func _measure_input_curve(level: Node, points: PackedVector2Array, touch: bool) -> float:
	level.call("cancel_active_gesture_for_lifecycle")
	if touch:
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.pressed = true
		press.position = points[0]
		level._unhandled_input(press)
		for index in range(1, points.size()):
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = points[index]
			level._unhandled_input(drag)
	else:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = points[0]
		level._unhandled_input(press)
		for index in range(1, points.size()):
			var motion := InputEventMouseMotion.new()
			motion.position = points[index]
			level._unhandled_input(motion)
	var amount := float(level.get("current_curve_amount"))
	level.call("cancel_active_gesture_for_lifecycle")
	return amount


func _bowed_gesture(start: Vector2, end: Vector2, bend: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var direction := (end - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	for index in range(1, segments + 1):
		var t := float(index) / float(segments)
		points.append(start.lerp(end, t) + perpendicular * sin(t * PI) * bend)
	return points


func _wobble_gesture(start: Vector2, end: Vector2, amplitude: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var direction := (end - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	for index in range(1, segments + 1):
		var t := float(index) / float(segments)
		points.append(start.lerp(end, t) + perpendicular * sin(t * PI * 4.0) * amplitude)
	return points


func _cubic_gesture(
	start: Vector2,
	control_a: Vector2,
	control_b: Vector2,
	end: Vector2,
	segments: int
) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	for index in range(1, segments + 1):
		var t := float(index) / float(segments)
		var inverse := 1.0 - t
		points.append(
			start * inverse * inverse * inverse
			+ control_a * 3.0 * inverse * inverse * t
			+ control_b * 3.0 * inverse * t * t
			+ end * t * t * t
		)
	return points


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
