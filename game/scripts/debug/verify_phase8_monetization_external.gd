extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const SaveServiceScript := preload("res://scripts/services/save_service.gd")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const TEST_SAVE := "user://phase8_monetization_test.json"
const TEST_TMP := "user://phase8_monetization_test.tmp"
const TEST_BAK := "user://phase8_monetization_test.bak"
const TEST_CORRUPT := "user://phase8_monetization_test.corrupt"

const ENTITLEMENT_REMOVE_ADS := "entitlement_remove_ads"
const ENTITLEMENT_STARTER_PACK := "entitlement_starter_pack"
const PRODUCT_REMOVE_ADS := "netbound_remove_ads"
const PRODUCT_STARTER_PACK := "netbound_starter_pack"
const CONTEXT_NEXT_LEVEL := "next_level"

var service: Node
var monetization: Node
var app: NetboundApp
var reward_signal_count: int = 0


func _initialize() -> void:
	service = get_root().get_node("SaveService")
	monetization = get_root().get_node("MonetizationService")
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_ads", true, "success", "success", 1, false)
	monetization.call("configure_simulated_purchases", true, "success", "success", 1, false)
	monetization.call("apply_config_from_save", service)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := true
	passed = await _test_architecture_and_provider_guards() and passed
	passed = await _test_entitlements_and_save_model() and passed
	passed = await _test_free_retry_and_rewarded_tokens() and passed
	passed = await _test_interstitial_policy() and passed
	passed = await _test_store_ui_and_supporter_link() and passed
	passed = await _test_offline_unavailable_behavior() and passed
	passed = await _test_all_production_level_startups() and passed
	_cleanup_test_files()
	print("PHASE8 verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_architecture_and_provider_guards() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_ads", true, "success", "success", 4, false)
	var passed := monetization.call("get_ad_provider") != null \
		and monetization.call("get_purchase_provider") != null \
		and monetization.has_method("request_rewarded_ad") \
		and monetization.has_method("purchase_starter_pack")

	var first: Dictionary = monetization.call("request_rewarded_ad", "phase8_architecture", {})
	var second: Dictionary = monetization.call("request_rewarded_ad", "phase8_architecture", {})
	passed = bool(first.get("accepted", false)) and not bool(second.get("accepted", false)) and passed
	await _wait_frames(8)

	monetization.call("configure_simulated_ads", false, "success", "success", 1, false)
	passed = not bool(monetization.call("is_rewarded_ad_available")) and passed
	var unavailable: Dictionary = monetization.call("request_rewarded_ad", "phase8_architecture", {})
	passed = not bool(unavailable.get("accepted", false)) and passed
	print("PHASE8 architecture ok=", passed)
	return passed


func _test_entitlements_and_save_model() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_purchases", true, "success", "success", 1, true)
	var remove_result: Dictionary = monetization.call("purchase_remove_ads")
	await _wait_frames(4)
	var passed: bool = bool(remove_result.get("accepted", false)) \
		and service.has_entitlement(ENTITLEMENT_REMOVE_ADS) \
		and service.is_product_owned(PRODUCT_REMOVE_ADS)
	var duplicate_remove: Dictionary = monetization.call("purchase_remove_ads")
	passed = not bool(duplicate_remove.get("accepted", false)) and passed

	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.call("reset_session_frequency_for_tests")
	var starter_result: Dictionary = monetization.call("purchase_starter_pack")
	await _wait_frames(4)
	passed = bool(starter_result.get("accepted", false)) and passed
	passed = service.has_entitlement(ENTITLEMENT_REMOVE_ADS) and passed
	passed = service.has_entitlement(ENTITLEMENT_STARTER_PACK) and passed
	passed = service.is_cosmetic_unlocked("ball_supporter") and passed
	passed = service.is_cosmetic_unlocked("trail_supporter") and passed
	passed = service.is_cosmetic_unlocked("goal_supporter") and passed
	passed = service.set_selected_ball("ball_supporter") and passed
	passed = service.set_selected_trail("trail_supporter") and passed
	passed = service.set_selected_goal_effect("goal_supporter") and passed
	var reloaded := _new_service("reload")
	_copy_file(service.get_save_path(), reloaded.get_save_path())
	passed = reloaded.load_or_create() and passed
	passed = reloaded.has_entitlement(ENTITLEMENT_STARTER_PACK) and passed
	passed = reloaded.get_selected_ball() == "ball_supporter" and passed
	reloaded.free()

	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.call("reset_session_frequency_for_tests")
	var restore_products: Array[String] = [PRODUCT_STARTER_PACK]
	monetization.call("set_simulated_restore_products", restore_products)
	var restore_result: Dictionary = monetization.call("restore_purchases")
	await _wait_frames(4)
	passed = bool(restore_result.get("accepted", false)) and service.has_entitlement(ENTITLEMENT_STARTER_PACK) and passed
	var entitlement_count: int = service.get_entitlements().size()
	monetization.call("restore_purchases")
	await _wait_frames(4)
	passed = service.get_entitlements().size() == entitlement_count and passed

	passed = _test_invalid_and_phase7_save_migration() and passed
	print("PHASE8 entitlements ok=", passed)
	return passed


func _test_invalid_and_phase7_save_migration() -> bool:
	var raw: Dictionary = service.get_save_data()
	raw.monetization = {
		"entitlements": ["bad", ENTITLEMENT_STARTER_PACK, ENTITLEMENT_STARTER_PACK],
		"purchases": {
			"bad_product": {"owned": true},
			PRODUCT_REMOVE_ADS: {"owned": true, "provider": "test"},
		},
		"config": {
			"ads_enabled": false,
			"purchases_enabled": true,
		},
	}
	_write_json(TEST_SAVE, raw)
	var normalized := _new_service("invalid")
	_copy_file(TEST_SAVE, normalized.get_save_path())
	var passed: bool = normalized.load_or_create()
	passed = normalized.has_entitlement(ENTITLEMENT_REMOVE_ADS) and passed
	passed = normalized.has_entitlement(ENTITLEMENT_STARTER_PACK) and passed
	passed = normalized.get_entitlements().size() == 2 and passed
	passed = normalized.is_cosmetic_unlocked("ball_supporter") and passed
	normalized.free()

	var phase7_save: Dictionary = service.get_save_data()
	phase7_save.erase("monetization")
	_write_json(TEST_SAVE, phase7_save)
	var migrated := _new_service("phase7")
	_copy_file(TEST_SAVE, migrated.get_save_path())
	passed = migrated.load_or_create() and passed
	passed = migrated.get_monetization_config().has("ads_enabled") and passed
	passed = not migrated.has_entitlement(ENTITLEMENT_REMOVE_ADS) and passed
	migrated.free()
	return passed


func _test_free_retry_and_rewarded_tokens() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.call("reset_session_frequency_for_tests")
	var definition := LevelRegistryScript.load_definition("level_01")
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await _warmup_level(level)
	await level.call("_restart_level")
	level.set("shots_remaining", definition.shot_limit - 1)
	level.set("shots_used", 1)
	await level.call("_on_reset_button_pressed")
	var passed := int(level.get("shots_used")) == 1 \
		and int(level.get("shots_remaining")) == definition.shot_limit - 1 \
		and not level.has_method("grant_rewarded_continue") \
		and not level.has_method("can_use_rewarded_continue")
	await level.call("_restart_level")
	passed = int(level.get("shots_used")) == 0 and passed
	passed = int(level.get("shots_remaining")) == definition.shot_limit and passed

	# Legacy runtime fixtures may still carry the old flag; it no longer caps stars.
	var result := LevelResult.completed_result(
		definition,
		definition.par_shots,
		definition.shot_limit - definition.par_shots,
		true
	)
	var update = service.record_level_result(result, definition)
	passed = int(update.stars_earned) == 3 and passed
	passed = service.get_best_stars("level_01") == 3 and passed
	passed = service.get_fewest_shots("level_01") == definition.par_shots and passed
	passed = service.is_level_unlocked("level_02") and passed

	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await process_frame

	passed = await _test_reward_provider_results() and passed
	passed = await _test_failure_retry_and_token_button_flow() and passed
	print("PHASE8 free_retry_rewarded_tokens ok=", passed)
	return passed


func _test_reward_provider_results() -> bool:
	reward_signal_count = 0
	var callback := Callable(self, "_on_reward_counted")
	if not monetization.is_connected("reward_granted", callback):
		monetization.connect("reward_granted", callback)
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_ads", true, "success", "success", 1, true)
	var success: Dictionary = monetization.call("request_rewarded_ad", "phase8_reward_counter", {})
	await _wait_frames(5)
	var passed := bool(success.get("accepted", false)) and reward_signal_count == 1

	monetization.call("configure_simulated_ads", true, "cancel", "success", 1, false)
	var before_cancel := reward_signal_count
	var cancel: Dictionary = monetization.call("request_rewarded_ad", "phase8_reward_counter", {})
	await _wait_frames(4)
	passed = bool(cancel.get("accepted", false)) and reward_signal_count == before_cancel and passed

	monetization.call("configure_simulated_ads", true, "failure", "success", 1, false)
	var failure: Dictionary = monetization.call("request_rewarded_ad", "phase8_reward_counter", {})
	await _wait_frames(4)
	passed = bool(failure.get("accepted", false)) and reward_signal_count == before_cancel and passed
	if monetization.is_connected("reward_granted", callback):
		monetization.disconnect("reward_granted", callback)
	return passed


func _test_failure_retry_and_token_button_flow() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_ads", true, "success", "success", 1, true)
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await process_frame
	await process_frame
	var launched := app.load_level("level_01")
	await process_frame
	await _warmup_level(app.current_level)
	var level := app.current_level
	await level.call("_restart_level")
	level.set("shots_remaining", 0)
	level.set("shots_used", int(level.get("max_shots")))
	level.set("level_state", level.LevelState.FAILED)
	app.call("_show_failure_result", LevelResult.failed_result(LevelRegistryScript.load_definition("level_01"), int(level.get("max_shots")), 0))
	await process_frame
	var try_again: Button = null
	var has_extra_shot_copy := false
	for node in app.result_overlay.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == "TRY AGAIN":
			try_again = button
		if button.text.contains("SHOT") or button.text.contains("AD"):
			has_extra_shot_copy = true
	var passed := launched and try_again != null and not has_extra_shot_copy
	if try_again:
		try_again.emit_signal("pressed")
	await _wait_frames(5)
	passed = app.current_screen_name == "gameplay" and passed
	passed = int(app.current_level.get("shots_used")) == 0 and passed
	passed = int(app.current_level.get("shots_remaining")) == int(app.current_level.get("max_shots")) and passed
	app.call("show_store", "main_menu")
	await process_frame
	passed = app.store_rewarded_token_button != null and passed
	passed = app.store_rewarded_token_button.text.contains("+2 TOKENS") and passed
	app.queue_free()
	app = null
	await process_frame
	return passed


func _test_interstitial_policy() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.call("reset_session_frequency_for_tests")
	monetization.set("minimum_interstitial_interval_seconds", 0.0)
	monetization.call("configure_simulated_ads", true, "success", "success", 1, false)
	for index in range(1, 4):
		var definition := LevelRegistryScript.load_definition("level_%02d" % index)
		service.record_level_result(LevelResult.completed_result(definition, definition.par_shots), definition)
		monetization.call("record_level_completion_for_ads")
	var passed := not bool(monetization.call("should_show_interstitial", CONTEXT_NEXT_LEVEL))
	var level_04 := LevelRegistryScript.load_definition("level_04")
	service.record_level_result(LevelResult.completed_result(level_04, level_04.par_shots), level_04)
	monetization.call("record_level_completion_for_ads")
	passed = bool(monetization.call("should_show_interstitial", CONTEXT_NEXT_LEVEL)) and passed
	var request: Dictionary = monetization.call("request_interstitial", CONTEXT_NEXT_LEVEL)
	await _wait_frames(4)
	passed = bool(request.get("accepted", false)) and passed
	passed = not bool(monetization.call("should_show_interstitial", CONTEXT_NEXT_LEVEL)) and passed
	monetization.set("last_interstitial_msec", -999999999)
	for count in range(3):
		monetization.call("record_level_completion_for_ads")
	var second_request: Dictionary = monetization.call("request_interstitial", CONTEXT_NEXT_LEVEL)
	await _wait_frames(4)
	passed = bool(second_request.get("accepted", false)) and passed
	monetization.set("last_interstitial_msec", -999999999)
	for count in range(3):
		monetization.call("record_level_completion_for_ads")
	passed = not bool(monetization.call("should_show_interstitial", CONTEXT_NEXT_LEVEL)) and passed

	monetization.call("reset_session_frequency_for_tests")
	monetization.call("record_level_completion_for_ads")
	monetization.call("record_level_completion_for_ads")
	passed = not bool(monetization.call("should_show_interstitial", CONTEXT_NEXT_LEVEL)) and passed
	service.record_purchase(PRODUCT_REMOVE_ADS, "test_remove_ads", "test")
	monetization.call("record_level_completion_for_ads")
	monetization.call("record_level_completion_for_ads")
	monetization.call("record_level_completion_for_ads")
	passed = not bool(monetization.call("should_show_interstitial", CONTEXT_NEXT_LEVEL)) and passed
	if not passed:
		print(
			"PHASE8 interstitial detail completed_count=", service.get_completed_level_count(),
			" session=", int(monetization.get("session_completed_levels_for_ads")),
			" shown=", bool(monetization.get("interstitial_shown_this_session")),
			" request=", request
		)
	print("PHASE8 interstitial_policy ok=", passed)
	return passed


func _test_store_ui_and_supporter_link() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_purchases", true, "success", "success", 2, true)
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await process_frame
	await process_frame
	app.show_cosmetics()
	await process_frame
	app.call("_preview_cosmetic", "ball_supporter")
	await process_frame
	var passed := app.cosmetic_store_button != null and app.cosmetic_store_button.visible
	app.cosmetic_store_button.emit_signal("pressed")
	await process_frame
	passed = app.current_screen_name == "store" and passed
	passed = app.store_starter_pack_button != null and not app.store_starter_pack_button.disabled and passed
	app.store_starter_pack_button.emit_signal("pressed")
	await process_frame
	passed = bool(app.get("store_request_in_progress")) and passed
	await _wait_frames(6)
	passed = service.has_entitlement(ENTITLEMENT_STARTER_PACK) and passed
	passed = service.is_cosmetic_unlocked("ball_supporter") and passed
	passed = app.store_starter_pack_button.disabled and passed

	app.show_cosmetics()
	await process_frame
	app.call("_preview_cosmetic", "ball_supporter")
	await process_frame
	passed = not app.cosmetic_equip_button.disabled and passed
	app.call("_equip_previewed_cosmetic")
	passed = service.get_selected_ball() == "ball_supporter" and passed
	app.queue_free()
	app = null
	await process_frame
	print("PHASE8 store_ui ok=", passed)
	return passed


func _test_offline_unavailable_behavior() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	service.record_purchase(PRODUCT_STARTER_PACK, "offline_owned", "test")
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_ads", false, "success", "success", 1, false)
	monetization.call("configure_simulated_purchases", false, "success", "success", 1, false)
	var passed: bool = not bool(monetization.call("is_rewarded_ad_available")) \
		and service.has_entitlement(ENTITLEMENT_STARTER_PACK) \
		and service.set_selected_ball("ball_supporter")
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await process_frame
	await process_frame
	app.show_store("main_menu")
	await process_frame
	passed = app.current_screen_name == "store" and passed
	passed = app.store_remove_ads_button.disabled and app.store_starter_pack_button.disabled and passed
	passed = app.request_level_launch("level_01") and passed
	await _warmup_level(app.current_level)
	passed = app.current_screen_name == "gameplay" and passed
	var ball: RigidBody3D = app.current_level.get_node("Ball") as RigidBody3D
	passed = is_equal_approx(ball.mass, float(app.current_level.get("ball_mass"))) and passed
	app.queue_free()
	app = null
	await process_frame
	print("PHASE8 offline ok=", passed)
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
	print("PHASE8 level_startups ok=", passed)
	return passed


func _on_reward_counted(context: String, _request_id: int, _metadata: Dictionary) -> void:
	if context == "phase8_reward_counter":
		reward_signal_count += 1


func _warmup_level(level: Node) -> void:
	if not level:
		return
	await process_frame
	await process_frame
	await physics_frame


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _new_service(suffix: String) -> Node:
	var local_service: Node = SaveServiceScript.new()
	var save_path := "user://phase8_%s.json" % suffix
	local_service.configure_storage_paths(
		save_path,
		"%s.tmp" % save_path,
		"%s.bak" % save_path,
		"%s.corrupt" % save_path
	)
	local_service.recording_enabled = true
	return local_service


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t", true))
		file.flush()
		file.close()


func _copy_file(source_path: String, target_path: String) -> void:
	if not FileAccess.file_exists(source_path):
		return
	var text := FileAccess.get_file_as_string(source_path)
	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.flush()
		file.close()


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for suffix in ["reload", "invalid", "phase7"]:
		for extension in [".json", ".json.tmp", ".json.bak", ".json.corrupt"]:
			var path := "user://phase8_%s%s" % [suffix, extension]
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
