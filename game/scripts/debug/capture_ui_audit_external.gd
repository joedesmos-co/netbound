extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const CosmeticVisualsScript := preload("res://scripts/cosmetics/cosmetic_visuals.gd")

const TEST_SAVE := "user://ui_audit_capture.json"
const TEST_TMP := "user://ui_audit_capture.tmp"
const TEST_BAK := "user://ui_audit_capture.bak"
const TEST_CORRUPT := "user://ui_audit_capture.corrupt"
const DESIGN_SIZE := Vector2i(1280, 720)

var app: NetboundApp
var service: NetboundSaveService
var wallet: NetboundWalletService
var screen_name: String = "main_menu"
var output_path: String = "/tmp/netbound-ui-audit.png"
var viewport_size := Vector2i(1280, 720)
var fixture_name: String = "fresh"
var native_canvas_capture: bool = false


func _initialize() -> void:
	_parse_arguments()
	if native_canvas_capture:
		DisplayServer.window_set_size(viewport_size)
	get_root().size = viewport_size
	# Native mode stress-tests responsive containers at exact pixel dimensions.
	# The default preserves the production design canvas and stretch path.
	get_root().content_scale_size = viewport_size if native_canvas_capture else DESIGN_SIZE
	service = get_root().get_node("SaveService") as NetboundSaveService
	wallet = get_root().get_node("WalletService") as NetboundWalletService
	wallet.configure_save_service(service)
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	_configure_capture_save()
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	call_deferred("_run")


func _run() -> void:
	await _wait_frames(4)
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	_configure_capture_save()
	await _show_requested_screen()
	var capture_delay := 0.2 if screen_name.begins_with("gameplay_goal_") else 0.55
	await create_timer(capture_delay, true, false, true).timeout
	await _wait_frames(10)
	_stabilize_animated_previews()
	await _wait_frames(3)
	var image := await _capture_clean_root_image()
	image.convert(Image.FORMAT_RGB8)
	var error := image.save_png(output_path)
	print(
		"UI_AUDIT_CAPTURE screen=", screen_name,
		" size=", viewport_size,
		" captured=", image.get_size(),
		" native=", native_canvas_capture,
		" output=", output_path,
		" error=", error
	)
	await _cleanup()
	quit(0 if error == OK else 1)


func _show_requested_screen() -> void:
	if screen_name.begins_with("cosmetics_ball_"):
		_show_cosmetic_preview("ball", screen_name.trim_prefix("cosmetics_"))
		return
	if screen_name.begins_with("cosmetics_trail_"):
		_show_cosmetic_preview("trail", screen_name.trim_prefix("cosmetics_"))
		return
	if screen_name.begins_with("cosmetics_goal_") and screen_name != "cosmetics_goal_effects":
		_show_cosmetic_preview("goal_effect", screen_name.trim_prefix("cosmetics_"))
		return
	if screen_name.begins_with("gameplay_goal_"):
		app.load_level("level_01")
		await _wait_for_level()
		var effect_id := screen_name.trim_prefix("gameplay_")
		CosmeticVisualsScript.trigger_goal_effect(
			app.current_level,
			app.current_level.get("goal_root") as Node3D,
			app.current_level.get("goal_flash") as ColorRect,
			app.current_level.get("goal_particles") as CPUParticles3D,
			effect_id
		)
		return
	if screen_name == "gameplay_aim":
		app.load_level("level_01")
		await _wait_for_level()
		_show_gameplay_aim()
		return
	if screen_name.begins_with("gameplay_"):
		var level_id := screen_name.trim_prefix("gameplay_")
		if LevelRegistryScript.has_level_id(level_id):
			app.load_level(level_id)
			await _wait_for_level()
			if app.current_screen_name == "pause":
				app.resume_game()
			return
		push_error("Unknown production level for UI audit: %s" % level_id)
		return
	match screen_name:
		"main_menu":
			app.show_main_menu()
		"level_select":
			app.show_level_select()
		"settings":
			app.show_settings("main_menu")
		"cosmetics":
			app.show_cosmetics()
		"cosmetics_balls":
			app.show_cosmetics()
			app._select_cosmetic_category("ball")
		"cosmetics_trails":
			app.show_cosmetics()
			app._select_cosmetic_category("trail")
		"cosmetics_goal_effects":
			app.show_cosmetics()
			app._select_cosmetic_category("goal_effect")
		"cosmetics_ball_gold":
			_show_cosmetic_preview("ball", "ball_gold")
		"cosmetics_ball_candy":
			_show_cosmetic_preview("ball", "ball_candy")
		"cosmetics_ball_comet":
			_show_cosmetic_preview("ball", "ball_comet")
		"cosmetics_insufficient":
			_show_cosmetic_preview("ball", "ball_candy")
			app._purchase_previewed_cosmetic()
		"cosmetics_token_confirmation":
			_show_cosmetic_preview("ball", "ball_comet")
			app._purchase_previewed_cosmetic()
		"cosmetics_trail_rainbow":
			_show_cosmetic_preview("trail", "trail_rainbow")
		"cosmetics_goal_confetti":
			_show_cosmetic_preview("goal_effect", "goal_confetti")
		"cosmetics_goal_shockwave":
			_show_cosmetic_preview("goal_effect", "goal_shockwave")
		"store":
			app.show_store("main_menu")
		"store_token_success":
			app.show_store("main_menu")
			var monetization := get_root().get_node_or_null("MonetizationService")
			monetization.call("configure_simulated_purchases", true, "success", "success", 1, false)
			monetization.call("set_simulated_transaction_id", "ui_audit_token_pack")
			app._start_store_purchase("netbound_tokens_100")
			await _wait_frames(5)
			_scroll_store_to_bottom()
		"store_token_failure":
			app.show_store("main_menu")
			var monetization := get_root().get_node_or_null("MonetizationService")
			monetization.call("configure_simulated_purchases", true, "failure", "success", 1, false)
			app._start_store_purchase("netbound_tokens_100")
			await _wait_frames(5)
			_scroll_store_to_bottom()
		"store_starter_owned":
			app.show_store("main_menu")
			var monetization := get_root().get_node_or_null("MonetizationService")
			monetization.call("configure_simulated_purchases", true, "success", "success", 1, false)
			monetization.call("set_simulated_transaction_id", "ui_audit_starter_pack")
			app._start_store_purchase("netbound_starter_pack")
			await _wait_frames(5)
		"store_owned":
			service.record_purchase("netbound_remove_ads", "ui_audit_remove_ads", "ui_audit")
			service.record_purchase("netbound_starter_pack", "ui_audit_starter", "ui_audit")
			app.show_store("main_menu")
		"store_unavailable":
			var monetization := get_root().get_node_or_null("MonetizationService")
			if monetization:
				monetization.call("set_release_mode_enabled", true)
			app.show_store("main_menu")
		"store_pending":
			app.show_store("main_menu")
			app.store_request_in_progress = true
			app.store_pending_product_id = "netbound_starter_pack"
			app._refresh_store_screen()
		"gameplay":
			app.load_level("level_01")
			await _wait_for_level()
			if app.current_screen_name == "pause":
				app.resume_game()
		"pause":
			app.load_level("level_01")
			await _wait_for_level()
			app.show_pause_menu()
		"success":
			await _show_success("level_01")
		"success_cosmetic_unlock":
			_complete_through_level("level_01")
			await _show_success("level_02")
		"failure":
			app.load_level("level_01")
			await _wait_for_level()
			var definition := LevelRegistryScript.load_definition("level_01")
			app.current_level.set("shots_remaining", 0)
			app.current_level.set("shots_used", definition.shot_limit)
			app.current_level.set("rewarded_continue_used", false)
			app.current_level.set("level_state", app.current_level.LevelState.FAILED)
			app._show_failure_result(LevelResult.failed_result(definition, definition.shot_limit, 0))
		"level_10_result":
			await _show_success("level_10")
		"level_20_result":
			await _show_success("level_20")
		_:
			push_error("Unknown UI audit screen: %s" % screen_name)


func _show_gameplay_aim() -> void:
	if not app.current_level:
		return
	var level := app.current_level
	var ball := level.get_node("Ball") as RigidBody3D
	var camera := level.get_node("Camera3D") as Camera3D
	var start := camera.unproject_position(ball.global_position)
	var offsets := [
		Vector2(0.0, 0.0),
		Vector2(15.0, -22.0),
		Vector2(42.0, -55.0),
		Vector2(82.0, -86.0),
		Vector2(132.0, -105.0),
		Vector2(184.0, -96.0),
	]
	level.call("_begin_swipe", start, -2)
	for offset in offsets:
		level.call("_update_swipe", start + offset)


func _show_cosmetic_preview(category: String, cosmetic_id: String) -> void:
	app.show_cosmetics()
	app._select_cosmetic_category(category)
	app._preview_cosmetic(cosmetic_id)


func _scroll_store_to_bottom() -> void:
	for node in app.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if scroll:
			scroll.scroll_vertical = roundi(scroll.get_v_scroll_bar().max_value)
			return


func _show_success(level_id: String) -> void:
	if not service.is_level_unlocked(level_id):
		_complete_through_level(_previous_level_id(level_id))
	app.load_level(level_id)
	await _wait_for_level()
	var definition := LevelRegistryScript.load_definition(level_id)
	var result := LevelResult.completed_result(definition, definition.par_shots)
	var update := service.record_level_result(result, definition)
	app._show_success_result(result, update)


func _apply_fixture() -> void:
	match fixture_name:
		"partial":
			_complete_through_level("level_04")
		"complete":
			_complete_through_level("level_20")
		"all_unlocked":
			_complete_through_level("level_20")
			service.unlock_all_cosmetics_for_development()
		"coins":
			wallet.grant_coins(6000, "ui_audit", "ui_audit:coins")
		"tokens":
			wallet.grant_tokens(300, "ui_audit", "ui_audit:tokens")
		"purchased":
			wallet.grant_coins(6000, "ui_audit", "ui_audit:coins")
			wallet.purchase_cosmetic("ball_candy")
		"daily_limit":
			for index in 5:
				wallet.claim_rewarded_token_ad("ui_audit:daily:%d" % index)


func _configure_capture_save() -> void:
	service.reset_to_defaults()
	_apply_fixture()
	service.set_setting_value("reduced_motion_enabled", true)


func _complete_through_level(last_level_id: String) -> void:
	if last_level_id.is_empty():
		return
	for level_id in LevelRegistryScript.get_level_ids():
		var definition := LevelRegistryScript.load_definition(level_id)
		service.record_level_result(LevelResult.completed_result(definition, definition.par_shots), definition)
		if level_id == last_level_id:
			break


func _previous_level_id(level_id: String) -> String:
	var level_ids := LevelRegistryScript.get_level_ids()
	var index := level_ids.find(level_id)
	return level_ids[index - 1] if index > 0 else ""


func _wait_for_level() -> void:
	await _wait_frames(4)
	await physics_frame


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _stabilize_animated_previews() -> void:
	for node in get_root().find_children("*", "NetboundCosmeticPreview", true, false):
		var preview := node as NetboundCosmeticPreview
		if not preview:
			continue
		preview.process_mode = Node.PROCESS_MODE_DISABLED
		var preview_viewport := preview.get_node_or_null("PreviewViewport") as SubViewport
		if preview_viewport:
			preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _capture_clean_root_image() -> Image:
	var image: Image
	for attempt in 10:
		await _wait_frames(4)
		image = get_root().get_texture().get_image()
		if image and not _has_black_readback_tiles(image):
			return image
		print("UI_AUDIT_CAPTURE retrying GPU readback attempt=", attempt + 1)
	return image


func _has_black_readback_tiles(image: Image) -> bool:
	if not image or image.is_empty():
		return true
	var sampled := 0
	var black := 0
	for y in range(8, image.get_height(), 24):
		for x in range(8, image.get_width(), 24):
			var color := image.get_pixel(x, y)
			sampled += 1
			if color.a < 0.98 or (color.r < 0.004 and color.g < 0.004 and color.b < 0.004):
				black += 1
	return sampled > 0 and float(black) / float(sampled) > 0.025


func _parse_arguments() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		screen_name = arguments[0]
	if arguments.size() > 1:
		output_path = arguments[1]
	if arguments.size() > 3:
		viewport_size = Vector2i(int(arguments[2]), int(arguments[3]))
	if arguments.size() > 4:
		fixture_name = arguments[4]
	if arguments.size() > 5:
		native_canvas_capture = arguments[5] == "native"


func _cleanup() -> void:
	paused = false
	if app:
		app._clear_result_overlay()
		app._leave_current_level()
		await _wait_frames(3)
		app.queue_free()
		app = null
		await _wait_frames(3)
	service.recording_enabled = false
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
