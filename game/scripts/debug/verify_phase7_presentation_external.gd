extends SceneTree

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

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


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
