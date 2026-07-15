extends SceneTree

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const CameraFeedbackScript := preload("res://scripts/presentation/camera_feedback.gd")
const CosmeticVisualsScript := preload("res://scripts/cosmetics/cosmetic_visuals.gd")

const TEST_SAVE := "user://phase7_presentation_test.json"
const TEST_TMP := "user://phase7_presentation_test.tmp"
const TEST_BAK := "user://phase7_presentation_test.bak"
const TEST_CORRUPT := "user://phase7_presentation_test.corrupt"

var service: Node
var audio_service: NetboundAudioService
var haptics_service: NetboundHapticsService


func _initialize() -> void:
	service = get_root().get_node("SaveService")
	audio_service = get_root().get_node("AudioService") as NetboundAudioService
	haptics_service = get_root().get_node("HapticsService") as NetboundHapticsService
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()
	audio_service.apply_settings_from_save(service)
	haptics_service.apply_settings_from_save(service)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := true
	passed = _test_audio_assets_and_buses() and passed
	passed = await _test_audio_playback_controls() and passed
	passed = _test_haptics() and passed
	passed = _test_save_settings_defaults() and passed
	passed = await _test_shot_presentation_does_not_change_launch() and passed
	passed = await _test_near_miss_and_camera_feedback() and passed
	passed = await _test_visual_polish_and_budgets() and passed
	passed = await _test_cosmetic_resource_reuse() and passed
	passed = await _test_ui_motion_and_reduced_motion() and passed
	passed = await _test_all_production_level_startups() and passed
	_cleanup_test_files()
	print("PHASE7 verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_audio_assets_and_buses() -> bool:
	var validation: Dictionary = audio_service.validate_assets()
	var passed := bool(validation.ok) \
		and audio_service.get_registered_sound_ids().size() >= 23 \
		and AudioServer.get_bus_index("Music") >= 0 \
		and AudioServer.get_bus_index("SFX") >= 0 \
		and AudioServer.get_bus_index("UI") >= 0 \
		and audio_service.get_sfx_player_count() == 10 \
		and audio_service.get_ui_player_count() == 4
	print("PHASE7 audio_assets ok=", passed)
	return passed


func _test_audio_playback_controls() -> bool:
	service.set_setting_value("master_volume", 1.0)
	service.set_setting_value("music_volume", 0.0)
	service.set_setting_value("sfx_volume", 0.0)
	audio_service.apply_settings_from_save(service)
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var passed := AudioServer.get_bus_volume_db(music_bus) <= -79.0 \
		and AudioServer.get_bus_volume_db(sfx_bus) <= -79.0

	service.set_setting_value("music_volume", 1.0)
	service.set_setting_value("sfx_volume", 1.0)
	audio_service.apply_settings_from_save(service)
	passed = audio_service.play_music(NetboundAudioService.MUSIC_MENU) and passed
	await process_frame
	passed = audio_service.get_current_music_id() == NetboundAudioService.MUSIC_MENU and passed
	passed = audio_service.play_music(NetboundAudioService.MUSIC_GAMEPLAY) and passed
	passed = audio_service.get_current_music_id() == NetboundAudioService.MUSIC_GAMEPLAY and passed

	audio_service.cleanup_scene_audio()
	var first_impact := audio_service.play_impact("ground", 1.0)
	var second_impact := audio_service.play_impact("ground", 1.0)
	passed = first_impact and not second_impact and passed
	var active_players := 0
	for child in audio_service.get_children():
		var player := child as AudioStreamPlayer
		if player and player.playing and player.bus == "SFX":
			active_players += 1
	passed = active_players <= audio_service.get_sfx_player_count() and passed
	audio_service.stop_music()
	print("PHASE7 audio_playback ok=", passed)
	return passed


func _test_haptics() -> bool:
	haptics_service.reset_for_tests()
	service.set_setting_value("haptics_enabled", false)
	haptics_service.apply_settings_from_save(service)
	var disabled_emit := haptics_service.emit_event("ui_tap")
	var passed := not disabled_emit and haptics_service.get_emitted_count() == 0
	service.set_setting_value("haptics_enabled", true)
	haptics_service.apply_settings_from_save(service)
	var first_emit := haptics_service.emit_event("obstacle_impact")
	var second_emit := haptics_service.emit_event("obstacle_impact")
	passed = first_emit and not second_emit and haptics_service.get_emitted_count() == 1 and passed
	print("PHASE7 haptics ok=", passed)
	return passed


func _test_save_settings_defaults() -> bool:
	service.reset_to_defaults()
	var passed := bool(service.get_setting_value("haptics_enabled", false)) \
		and not bool(service.get_setting_value("reduced_motion_enabled", true)) \
		and is_equal_approx(float(service.get_setting_value("camera_effects_intensity", 0.0)), 1.0)
	print("PHASE7 settings_defaults ok=", passed)
	return passed


func _test_shot_presentation_does_not_change_launch() -> bool:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	await physics_frame
	await level.call("_restart_level")
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var camera: Camera3D = level.get_node("Camera3D") as Camera3D
	var feedback = level.get_node_or_null("GameplayFeedback")
	var passed := feedback != null

	var start := camera.unproject_position(ball.global_position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	level._unhandled_input(press)
	for point in _line_offsets(Vector2(0.0, -220.0), 8):
		var motion := InputEventMouseMotion.new()
		motion.position = start + point
		level._unhandled_input(motion)
	await process_frame
	var visible_dots := 0
	for child in feedback.get_children():
		if child is MeshInstance3D and child.name.begins_with("AimPreviewDot") and child.visible:
			visible_dots += 1
	var swipe_overlay := level.get_node("UI/SwipeOverlay") as SwipeOverlay
	passed = visible_dots == 0 and swipe_overlay.is_active and not level.get_node("AimGuide").visible and passed

	level.call("cancel_active_gesture_for_lifecycle")
	level.set("developer_debug_enabled", true)
	level.call("_update_debug_ui")
	level._unhandled_input(press)
	for point in _line_offsets(Vector2(0.0, -220.0), 8):
		var debug_motion := InputEventMouseMotion.new()
		debug_motion.position = start + point
		level._unhandled_input(debug_motion)
	await process_frame
	visible_dots = 0
	for child in feedback.get_children():
		if child is MeshInstance3D and child.name.begins_with("AimPreviewDot") and child.visible:
			visible_dots += 1
	passed = visible_dots > 4 and level.get_node("AimGuide").visible and passed

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start + Vector2(0.0, -220.0)
	level._unhandled_input(release)
	await physics_frame
	var last_launch: Vector3 = level.get("last_launch_velocity")
	passed = ball.linear_velocity.distance_to(last_launch) <= 0.08 and passed
	passed = is_equal_approx(ball.mass, float(level.get("ball_mass"))) and passed
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await process_frame
	print("PHASE7 shot_presentation ok=", passed)
	return passed


func _test_near_miss_and_camera_feedback() -> bool:
	var camera_feedback = CameraFeedbackScript.new()
	get_root().add_child(camera_feedback)
	camera_feedback.configure(false, 1.0)
	camera_feedback.add_impulse("goal", 1.0)
	var offset := camera_feedback.get_offset(0.016)
	var passed := offset.length() > 0.0
	camera_feedback.clear()
	passed = camera_feedback.get_offset(0.016).length() == 0.0 and passed
	camera_feedback.configure(false, 0.0)
	camera_feedback.add_impulse("goal", 1.0)
	passed = camera_feedback.get_offset(0.016).length() == 0.0 and passed
	camera_feedback.queue_free()

	var scene: PackedScene = load("res://levels/level_01.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	await physics_frame
	await level.call("_restart_level")
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var goal: GoalTarget = level.get_node("Goal") as GoalTarget
	var shot_id := 7
	level.set("active_shot_id", shot_id)
	level.set("level_state", level.LevelState.SHOT_ACTIVE)
	level.set("shots_remaining", 1)
	ball.global_position = goal.global_position + Vector3(goal.opening_half_width + 0.35, 2.8, 0.0)
	level.call("_resolve_miss", shot_id, "presentation_test")
	await process_frame
	passed = int(level.get("near_miss_presented_shot_id")) == shot_id and passed
	var first_presented := int(level.get("near_miss_presented_shot_id"))
	level.call("_maybe_present_near_miss", shot_id)
	passed = int(level.get("near_miss_presented_shot_id")) == first_presented and passed
	passed = int(level.get("level_state")) != level.LevelState.GOAL and passed
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await process_frame
	print("PHASE7 near_miss_camera ok=", passed)
	return passed


func _test_visual_polish_and_budgets() -> bool:
	var passed := true
	for level_id in LevelRegistryScript.get_level_ids():
		var scene: PackedScene = load(LevelRegistryScript.get_scene_path(level_id))
		var level := scene.instantiate()
		get_root().add_child(level)
		await process_frame
		await process_frame
		await physics_frame
		var visual = level.get_node_or_null("LevelVisualPolish")
		passed = visual != null and passed
		if visual:
			var snapshot: Dictionary = visual.call("get_budget_snapshot")
			passed = int(snapshot.get("collision_nodes", -1)) == 0 and passed
			passed = int(snapshot.get("visual_nodes", 999)) <= 24 and passed
			visual.call("on_goal_scored")
			visual.call("clear_feedback")
			passed = int(visual.call("get_budget_snapshot").get("active_tweens", 999)) == 0 and passed
		var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
		passed = is_equal_approx(ball.mass, float(level.get("ball_mass"))) and passed
		passed = _all_goal_targets_still_synced(level) and passed
		if level.has_method("prepare_for_unload"):
			level.call("prepare_for_unload")
		level.queue_free()
		await process_frame
	print("PHASE7 visual_polish ok=", passed)
	return passed


func _test_cosmetic_resource_reuse() -> bool:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await process_frame
	await process_frame
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var main_mesh := ball.get_node("MeshInstance3D") as MeshInstance3D
	CosmeticVisualsScript.apply_ball_skin(ball, "ball_fire")
	var first_skin_material := main_mesh.material_override
	CosmeticVisualsScript.apply_ball_skin(ball, "ball_fire")
	var passed := first_skin_material == main_mesh.material_override
	CosmeticVisualsScript.apply_ball_trail(ball, "trail_blue")
	var trail := ball.get_node_or_null("NetboundBallTrail")
	var first_trail_material: Material = trail.get_child(0).material_override if trail and trail.get_child_count() > 0 else null
	CosmeticVisualsScript.apply_ball_trail(ball, "trail_blue")
	var second_trail_material: Material = trail.get_child(0).material_override if trail and trail.get_child_count() > 0 else null
	passed = first_trail_material == second_trail_material and passed
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await process_frame
	print("PHASE7 cosmetic_reuse ok=", passed)
	return passed


func _test_ui_motion_and_reduced_motion() -> bool:
	service.reset_to_defaults()
	service.set_setting_value("reduced_motion_enabled", true)
	var scene: PackedScene = load("res://app/netbound_app.tscn")
	var app := scene.instantiate()
	get_root().add_child(app)
	await process_frame
	await process_frame
	var passed := String(app.get("current_screen_name")) == "main_menu"
	passed = int(app.get("active_ui_tweens").size()) == 0 and passed
	passed = app.call("show_level_select") and passed
	await process_frame
	passed = String(app.get("current_screen_name")) == "level_select" and passed
	passed = int(app.get("active_ui_tweens").size()) == 0 and passed
	passed = int(app.call("get_registered_level_card_count")) == 10 and passed
	passed = app.call("show_cosmetics") and passed
	await process_frame
	passed = String(app.get("current_screen_name")) == "cosmetics" and passed
	passed = int(app.get("active_ui_tweens").size()) == 0 and passed
	app.queue_free()
	await process_frame
	service.reset_to_defaults()
	print("PHASE7 ui_motion ok=", passed)
	return passed


func _test_all_production_level_startups() -> bool:
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
	print("PHASE7 level_startups ok=", passed)
	return passed


func _all_goal_targets_still_synced(level: Node) -> bool:
	var targets := level.find_children("*", "GoalTarget", true, false)
	if targets.is_empty():
		return false
	for node in targets:
		var target := node as GoalTarget
		if not target or not target.geometry_matches_detector():
			return false
	return true


func _line_offsets(offset: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(offset * (float(i + 1) / float(count)))
	return points


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
