extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const TEST_SAVE := "user://phase9_mobile_test.json"
const TEST_TMP := "user://phase9_mobile_test.tmp"
const TEST_BAK := "user://phase9_mobile_test.bak"
const TEST_CORRUPT := "user://phase9_mobile_test.corrupt"

var service: NetboundSaveService
var runtime: Node
var audio_service: NetboundAudioService
var monetization: Node
var app: NetboundApp


func _initialize() -> void:
	service = get_root().get_node("SaveService") as NetboundSaveService
	runtime = get_root().get_node("MobileRuntimeService")
	audio_service = get_root().get_node("AudioService") as NetboundAudioService
	monetization = get_root().get_node("MonetizationService")
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()
	runtime.set_release_mode_override_for_tests(0)
	runtime.clear_safe_area_override_for_tests()
	monetization.set_release_mode_enabled(false)
	monetization.configure_simulated_ads(true, "success", "success", 1, false)
	monetization.configure_simulated_purchases(true, "success", "success", 1, false)
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := true
	passed = _test_project_and_export_config() and passed
	passed = _test_save_quality_and_dirty_flush() and passed
	passed = _test_runtime_quality_and_release_mode() and passed
	passed = await _test_safe_area_layouts() and passed
	passed = await _test_touch_and_lifecycle() and passed
	passed = await _test_bounded_release_samples() and passed
	passed = await _test_audio_lifecycle() and passed
	passed = await _test_quality_is_presentation_only() and passed
	passed = await _test_release_ui_filters() and passed
	passed = await _test_all_production_level_startups() and passed
	_cleanup()
	print("PHASE9 verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_project_and_export_config() -> bool:
	var export_text := FileAccess.get_file_as_string("res://export_presets.cfg")
	var passed := String(ProjectSettings.get_setting("application/run/main_scene", "")) == "res://app/netbound_app.tscn" \
		and String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) == "mobile" \
		and String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) == "expand" \
		and int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1280 \
		and int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 720 \
		and FileAccess.file_exists("res://export_presets.cfg")
	passed = export_text.contains("Android Debug") and export_text.contains("Android Release") and passed
	passed = export_text.contains("iOS Debug") and export_text.contains("iOS Release") and passed
	passed = export_text.contains("com.netbound.game") and passed
	passed = export_text.contains("netbound_development") and export_text.contains("netbound_release") and passed
	passed = export_text.contains("permissions/internet=false") and export_text.contains("permissions/vibrate=true") and passed
	var development_excludes := 'exclude_filter="scripts/debug/*,levels/debug/*,scenes/prototype.tscn,levels/definitions/level_architecture_test.tres"'
	passed = export_text.count(development_excludes) == 5 and passed
	passed = export_text.count('application/min_ios_version="16.0"') == 2 and passed
	print("PHASE9 project_export_config ok=", passed)
	return passed


func _test_save_quality_and_dirty_flush() -> bool:
	service.reset_to_defaults()
	var passed := String(service.get_setting_value("quality_tier", "")) == "auto"
	passed = service.set_setting_value("quality_tier", "bad-tier") and passed
	passed = String(service.get_setting_value("quality_tier", "")) == "auto" and passed
	service.simulate_next_write_failure_for_tests()
	var write_ok := service.set_setting_value("quality_tier", "low")
	passed = not write_ok and service.is_dirty() and passed
	passed = service.flush_if_dirty() and not service.is_dirty() and passed
	passed = String(service.get_setting_value("quality_tier", "")) == "low" and passed
	print("PHASE9 save_quality_dirty ok=", passed)
	return passed


func _test_runtime_quality_and_release_mode() -> bool:
	service.set_setting_value("quality_tier", "medium")
	var config: Dictionary = runtime.apply_quality_from_save(service)
	var passed := String(config.get("selected_tier", "")) == "medium" \
		and int(config.get("trail_point_limit", 0)) == 12
	service.set_setting_value("quality_tier", "high")
	config = runtime.apply_quality_from_save(service)
	passed = bool(config.get("dynamic_shadows_enabled", false)) and int(config.get("trail_point_limit", 0)) == 16 and passed

	runtime.set_release_mode_override_for_tests(1)
	runtime.apply_release_configuration(monetization)
	passed = runtime.is_release_mode() and not runtime.allow_development_controls() and passed
	passed = monetization.is_release_mode_enabled() and not monetization.is_rewarded_ad_available() and not monetization.is_purchase_available() and passed

	runtime.set_release_mode_override_for_tests(0)
	runtime.apply_release_configuration(monetization)
	monetization.configure_simulated_ads(true, "success", "success", 1, false)
	monetization.configure_simulated_purchases(true, "success", "success", 1, false)
	passed = not runtime.is_release_mode() and monetization.is_rewarded_ad_available() and monetization.is_purchase_available() and passed
	print("PHASE9 runtime_quality_release ok=", passed)
	return passed


func _test_safe_area_layouts() -> bool:
	var sizes := [
		Vector2i(1280, 720),
		Vector2i(1600, 720),
		Vector2i(1920, 864),
		Vector2i(2340, 1080),
		Vector2i(1024, 768),
		Vector2i(1366, 1024),
	]
	var passed := true
	runtime.set_safe_area_override_for_tests(44.0, 32.0, 76.0, 64.0)
	for size in sizes:
		get_root().size = size
		get_root().content_scale_size = size
		await process_frame
		passed = await _show_and_check_safe_screen("main_menu") and passed
		passed = await _show_and_check_safe_screen("level_select") and passed
		passed = await _show_and_check_safe_screen("settings") and passed
		passed = await _show_and_check_safe_screen("cosmetics") and passed
		passed = await _show_and_check_safe_screen("store") and passed
	runtime.clear_safe_area_override_for_tests()
	print("PHASE9 safe_area_layouts ok=", passed)
	return passed


func _show_and_check_safe_screen(screen_name: String) -> bool:
	match screen_name:
		"main_menu":
			app.show_main_menu()
		"level_select":
			app.show_level_select()
		"settings":
			app.show_settings("main_menu")
		"cosmetics":
			app.show_cosmetics()
		"store":
			app.show_store("main_menu")
	await process_frame
	await process_frame
	var buttons_ok := _buttons_are_inside_viewport(app.screen_root, screen_name)
	var scroll_ok := _screen_has_scroll_where_expected(screen_name)
	if not buttons_ok or not scroll_ok:
		print("PHASE9 safe screen fail screen=", screen_name, " buttons=", buttons_ok, " scroll=", scroll_ok, " size=", get_root().size)
	return buttons_ok and scroll_ok


func _buttons_are_inside_viewport(root_node: Node, screen_name: String) -> bool:
	var viewport_rect := get_root().get_visible_rect()
	for node in root_node.find_children("*", "Button", true, false):
		var button := node as Button
		if not button or not button.is_visible_in_tree():
			continue
		var rect := button.get_global_rect()
		if rect.size.x < 48.0 or rect.size.y < 48.0:
			print("PHASE9 button too small screen=", screen_name, " path=", button.get_path(), " rect=", rect)
			return false
		if rect.position.x < -1.0 or rect.position.y < -1.0:
			if _has_scroll_ancestor(button):
				continue
			print("PHASE9 button outside min screen=", screen_name, " path=", button.get_path(), " rect=", rect)
			return false
		if rect.end.x > viewport_rect.end.x + 1.0 or rect.end.y > viewport_rect.end.y + 1.0:
			if _has_scroll_ancestor(button):
				continue
			print("PHASE9 button outside max screen=", screen_name, " path=", button.get_path(), " rect=", rect, " viewport=", viewport_rect)
			return false
	return true


func _has_scroll_ancestor(node: Node) -> bool:
	var current := node.get_parent()
	while current:
		if current is ScrollContainer:
			return true
		current = current.get_parent()
	return false


func _screen_has_scroll_where_expected(screen_name: String) -> bool:
	if not ["level_select", "cosmetics", "store"].has(screen_name):
		return true
	return app.screen_root.find_children("*", "ScrollContainer", true, false).size() > 0


func _test_touch_and_lifecycle() -> bool:
	service.reset_to_defaults()
	var launched := app.load_level("level_01")
	await _warmup_level()
	var level := app.current_level
	var ball := level.get_node("Ball") as RigidBody3D
	var camera := level.get_node("Camera3D") as Camera3D
	var ball_screen := camera.unproject_position(ball.global_position)
	var passed := launched and level != null

	var button := level.get_node("UI/TopLeftUI/ResetButton") as Button
	var ui_touch := InputEventScreenTouch.new()
	ui_touch.index = 0
	ui_touch.pressed = true
	ui_touch.position = button.get_global_rect().get_center()
	level._unhandled_input(ui_touch)
	passed = not bool(level.get("is_swiping")) and passed

	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = ball_screen
	level._unhandled_input(touch)
	passed = bool(level.get("is_swiping")) and int(level.get("active_pointer_id")) == 0 and passed

	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.pressed = true
	second_touch.position = ball_screen + Vector2(12.0, -12.0)
	level._unhandled_input(second_touch)
	passed = int(level.get("active_pointer_id")) == 0 and passed

	var cancel := InputEventScreenTouch.new()
	cancel.index = 0
	cancel.pressed = false
	cancel.canceled = true
	cancel.position = ball_screen
	level._unhandled_input(cancel)
	passed = not bool(level.get("is_swiping")) and passed

	touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = ball_screen
	level._unhandled_input(touch)
	passed = bool(level.get("is_swiping")) and passed
	runtime.simulate_background_for_tests("phase9_touch")
	await process_frame
	passed = not bool(level.get("is_swiping")) and app.current_screen_name == "pause" and paused and passed
	app.resume_game()
	await process_frame
	passed = not paused and app.current_screen_name == "gameplay" and passed
	print("PHASE9 touch_lifecycle ok=", passed)
	return passed


func _test_bounded_release_samples() -> bool:
	service.reset_to_defaults()
	var launched := app.load_level("level_01")
	await _warmup_level()
	var level := app.current_level
	var ball := level.get_node("Ball") as RigidBody3D
	var camera := level.get_node("Camera3D") as Camera3D
	var start := camera.unproject_position(ball.global_position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	level._unhandled_input(press)
	for index in range(int(level.get("maximum_swipe_samples")) + 20):
		var motion := InputEventMouseMotion.new()
		motion.position = start + Vector2(float(index % 7), -float(index + 1) * 4.0)
		level._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start + Vector2(40.0, -300.0)
	level._commit_swipe_release_sample(release.position)
	var sample_count := (level.get("swipe_screen_points") as PackedVector2Array).size()
	var passed := launched and sample_count <= int(level.get("maximum_swipe_samples"))
	level._cancel_swipe()
	print("PHASE9 bounded_release_samples ok=", passed, " count=", sample_count)
	return passed


func _test_audio_lifecycle() -> bool:
	var passed := audio_service.play_music(NetboundAudioService.MUSIC_MENU)
	await process_frame
	audio_service.play_sfx("impact_ground")
	audio_service.handle_app_backgrounded()
	passed = audio_service.is_music_paused_for_lifecycle() and audio_service.get_active_sfx_count() == 0 and passed
	audio_service.handle_app_foregrounded()
	passed = not audio_service.is_music_paused_for_lifecycle() and passed
	var music_players := 0
	for child in audio_service.get_children():
		if child is AudioStreamPlayer and child.name == "MusicPlayer":
			music_players += 1
	audio_service.play_music(NetboundAudioService.MUSIC_MENU)
	passed = music_players == 1 and audio_service.get_current_music_id() == NetboundAudioService.MUSIC_MENU and passed
	print("PHASE9 audio_lifecycle ok=", passed)
	return passed


func _test_quality_is_presentation_only() -> bool:
	var scene: PackedScene = load("res://levels/level_05.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await _warmup_standalone_level(level)
	var ball := level.get_node("Ball") as RigidBody3D
	var signature_before := _gameplay_signature(level, ball)
	level.apply_quality_settings(runtime.get_quality_config("low"))
	var signature_low := _gameplay_signature(level, ball)
	service.unlock_cosmetic("trail_blue")
	service.set_selected_trail("trail_blue")
	level.call("_refresh_selected_cosmetics")
	var trail = ball.get_node_or_null("NetboundBallTrail")
	var low_limit := int(trail.call("get_point_limit")) if trail else -1
	level.apply_quality_settings(runtime.get_quality_config("high"))
	var signature_high := _gameplay_signature(level, ball)
	trail = ball.get_node_or_null("NetboundBallTrail")
	var high_limit := int(trail.call("get_point_limit")) if trail else -1
	var passed := signature_before == signature_low and signature_before == signature_high
	passed = low_limit == 8 and high_limit == 16 and passed
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await process_frame
	print("PHASE9 quality_visual_only ok=", passed)
	return passed


func _gameplay_signature(level: Node, ball: RigidBody3D) -> Dictionary:
	return {
		"mass": ball.mass,
		"radius": float(level.get("ball_radius")),
		"min_speed": float(level.get("minimum_launch_speed")),
		"max_speed": float(level.get("maximum_launch_speed")),
		"max_curve": float(level.get("maximum_curve_heading_degrees")),
		"shot_limit": int(level.get("max_shots")),
		"shot_timeout": float(level.get("shot_timeout")),
	}


func _test_release_ui_filters() -> bool:
	runtime.set_release_mode_override_for_tests(1)
	app._apply_saved_settings()
	app.show_settings("main_menu")
	await process_frame
	var passed := not app.settings_widgets.has("developer_debug")
	app.show_store("main_menu")
	await process_frame
	passed = app.store_status_label != null and app.store_status_label.text.to_lower().contains("unavailable") and passed
	passed = monetization.is_release_mode_enabled() and not monetization.is_purchase_available() and passed
	runtime.set_release_mode_override_for_tests(0)
	app._apply_saved_settings()
	monetization.configure_simulated_ads(true, "success", "success", 1, false)
	monetization.configure_simulated_purchases(true, "success", "success", 1, false)
	print("PHASE9 release_ui_filters ok=", passed)
	return passed


func _test_all_production_level_startups() -> bool:
	var passed := true
	for level_id in LevelRegistryScript.get_level_ids():
		var scene: PackedScene = load(LevelRegistryScript.get_scene_path(level_id))
		var level := scene.instantiate()
		get_root().add_child(level)
		await _warmup_standalone_level(level)
		passed = int(level.get("level_state")) == level.LevelState.READY and passed
		passed = level.has_method("apply_quality_settings") and level.has_method("handle_app_backgrounded") and passed
		if level.has_method("prepare_for_unload"):
			level.call("prepare_for_unload")
		level.queue_free()
		await process_frame
	print("PHASE9 level_startups ok=", passed)
	return passed


func _warmup_level() -> void:
	await process_frame
	await process_frame
	await physics_frame


func _warmup_standalone_level(level: Node) -> void:
	await process_frame
	await process_frame
	await physics_frame
	if level.has_method("_restart_level"):
		await level.call("_restart_level")


func _cleanup() -> void:
	runtime.set_release_mode_override_for_tests(-1)
	runtime.clear_safe_area_override_for_tests()
	monetization.set_release_mode_enabled(false)
	if app:
		app.queue_free()
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
