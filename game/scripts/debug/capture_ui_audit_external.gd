extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const TEST_SAVE := "user://ui_audit_capture.json"
const TEST_TMP := "user://ui_audit_capture.tmp"
const TEST_BAK := "user://ui_audit_capture.bak"
const TEST_CORRUPT := "user://ui_audit_capture.corrupt"

var app: NetboundApp
var service: NetboundSaveService
var screen_name: String = "main_menu"
var output_path: String = "/tmp/netbound-ui-audit.png"
var viewport_size := Vector2i(1280, 720)
var fixture_name: String = "fresh"


func _initialize() -> void:
	_parse_arguments()
	get_root().size = viewport_size
	get_root().content_scale_size = viewport_size
	service = get_root().get_node("SaveService") as NetboundSaveService
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
	await create_timer(0.55, true, false, true).timeout
	await _wait_frames(4)
	var image := get_root().get_texture().get_image()
	var error := image.save_png(output_path)
	print("UI_AUDIT_CAPTURE screen=", screen_name, " size=", viewport_size, " output=", output_path, " error=", error)
	await _cleanup()
	quit(0 if error == OK else 1)


func _show_requested_screen() -> void:
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
		"store":
			app.show_store("main_menu")
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
		_:
			push_error("Unknown UI audit screen: %s" % screen_name)


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
			_complete_through_level("level_10")
		"all_unlocked":
			_complete_through_level("level_10")
			service.unlock_all_cosmetics_for_development()


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
