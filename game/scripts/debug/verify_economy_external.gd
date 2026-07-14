extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const SaveServiceScript := preload("res://scripts/services/save_service.gd")
const WalletServiceScript := preload("res://scripts/services/wallet_service.gd")
const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const CosmeticVisualsScript := preload("res://scripts/cosmetics/cosmetic_visuals.gd")
const CurrencyProductsScript := preload("res://scripts/monetization/currency_product_registry.gd")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const TEST_SAVE := "user://economy_test.json"
const TEST_TMP := "user://economy_test.tmp"
const TEST_BAK := "user://economy_test.bak"
const TEST_CORRUPT := "user://economy_test.corrupt"

var service: NetboundSaveService
var wallet: NetboundWalletService
var monetization: NetboundMonetizationService


func _initialize() -> void:
	service = get_root().get_node("SaveService") as NetboundSaveService
	wallet = get_root().get_node("WalletService") as NetboundWalletService
	monetization = get_root().get_node("MonetizationService") as NetboundMonetizationService
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	wallet.configure_save_service(service)
	service.reset_to_defaults()
	monetization.call("set_release_mode_enabled", false)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := true
	passed = _test_catalog() and passed
	passed = _test_wallet_basics() and passed
	passed = _test_completion_rewards() and passed
	passed = _test_save_migration_and_normalization() and passed
	passed = await _test_rewarded_token_ads() and passed
	passed = _test_cosmetic_purchases() and passed
	passed = await _test_token_products() and passed
	passed = await _test_starter_pack_bonus() and passed
	passed = await _test_shop_ui() and passed
	passed = await _test_cosmetics_are_visual_only() and passed
	_cleanup_test_files()
	print("ECONOMY verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_catalog() -> bool:
	var validation := CosmeticRegistryScript.validate_registry()
	var product_validation := CurrencyProductsScript.validate_registry()
	var passed: bool = bool(validation.ok) and bool(product_validation.ok)
	passed = CosmeticRegistryScript.get_all().size() == 38 and passed
	passed = CosmeticRegistryScript.get_by_category("ball").size() == 18 and passed
	passed = CosmeticRegistryScript.get_by_category("trail").size() == 12 and passed
	passed = CosmeticRegistryScript.get_by_category("goal_effect").size() == 8 and passed
	passed = CurrencyProductsScript.get_product_ids().size() == 5 and passed
	for definition in CosmeticRegistryScript.get_all():
		passed = not String(definition.get("rarity", "")).is_empty() and passed
		passed = not String(definition.get("acquisition_method", "")).is_empty() and passed
		passed = ResourceLoader.exists(String(definition.get("preview_resource", ""))) and passed
		passed = ResourceLoader.exists(String(definition.get("gameplay_visual_resource", ""))) and passed
	print("ECONOMY catalog ok=", passed)
	return passed


func _test_wallet_basics() -> bool:
	service.reset_to_defaults()
	var passed := wallet.get_coin_balance() == 0 and wallet.get_token_balance() == 0
	passed = wallet.grant_coins(500, "test", "coins:test:1") and passed
	passed = wallet.get_coin_balance() == 500 and passed
	passed = not wallet.grant_coins(500, "duplicate", "coins:test:1") and passed
	passed = wallet.get_coin_balance() == 500 and passed
	passed = wallet.spend_coins(125, "test_spend") and passed
	passed = wallet.get_coin_balance() == 375 and passed
	passed = not wallet.spend_coins(500, "insufficient") and passed
	passed = wallet.get_coin_balance() == 375 and passed
	passed = wallet.grant_tokens(12, "test", "tokens:test:1") and passed
	passed = wallet.spend_tokens(2, "test_spend") and passed
	passed = wallet.get_token_balance() == 10 and passed
	var before_failed_write := wallet.get_coin_balance()
	service.simulate_next_write_failure_for_tests()
	passed = not wallet.grant_coins(10, "failed_write", "coins:failed_write") and passed
	passed = wallet.get_coin_balance() == before_failed_write and passed
	passed = not wallet.has_processed_transaction("coins:failed_write") and passed
	passed = wallet.grant_coins(10, "write_retry", "coins:failed_write") and passed
	for index in 70:
		wallet.grant_coins(1, "history_bound", "history:%d" % index)
	passed = wallet.get_transaction_history().size() == 64 and passed
	var reload := _new_service("wallet_reload")
	_copy_file(service.get_save_path(), reload.get_save_path())
	passed = reload.load_or_create() and passed
	var reload_wallet := WalletServiceScript.new()
	reload_wallet.configure_save_service(reload)
	passed = reload_wallet.get_coin_balance() == wallet.get_coin_balance() and passed
	passed = reload_wallet.get_token_balance() == wallet.get_token_balance() and passed
	reload_wallet.free()
	reload.free()
	print("ECONOMY wallet ok=", passed)
	return passed


func _test_completion_rewards() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	var level_01 := LevelRegistryScript.load_definition("level_01")
	var first = service.record_level_result(LevelResult.completed_result(level_01, 1), level_01)
	var passed := int(first.coins_earned) == 475
	passed = int(first.completion_coins) == 100 and passed
	passed = int(first.first_completion_coins) == 150 and passed
	passed = int(first.new_star_coins) == 225 and passed
	passed = int(first.personal_best_coins) == 0 and passed
	passed = wallet.get_coin_balance() == 475 and passed
	var before_failure := wallet.get_coin_balance()
	service.record_level_result(LevelResult.failed_result(level_01, 3), level_01)
	passed = wallet.get_coin_balance() == before_failure and passed
	var replay = service.record_level_result(LevelResult.completed_result(level_01, 3), level_01)
	passed = int(replay.coins_earned) == 100 and wallet.get_coin_balance() == before_failure + 100 and passed

	var level_02 := LevelRegistryScript.load_definition("level_02")
	var level_02_first = service.record_level_result(LevelResult.completed_result(level_02, 2), level_02)
	passed = int(level_02_first.coins_earned) == 400 and passed
	var improved = service.record_level_result(LevelResult.completed_result(level_02, 1), level_02)
	passed = int(improved.completion_coins) == 100 and passed
	passed = int(improved.new_star_coins) == 75 and passed
	passed = int(improved.personal_best_coins) == 50 and passed
	passed = int(improved.coins_earned) == 225 and passed
	var balance_before_result_reopen := wallet.get_coin_balance()
	var app := AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	app.call("_show_success_result", LevelResult.completed_result(level_02, 1), improved)
	app.call("_show_success_result", LevelResult.completed_result(level_02, 1), improved)
	passed = wallet.get_coin_balance() == balance_before_result_reopen and passed
	app.queue_free()
	if not passed:
		print(
			"ECONOMY rewards detail first=", first.to_dictionary(),
			" replay=", replay.to_dictionary(),
			" level02_first=", level_02_first.to_dictionary(),
			" improved=", improved.to_dictionary(),
			" balance=", wallet.get_coin_balance(),
			" reopen_before=", balance_before_result_reopen
		)
	print("ECONOMY rewards ok=", passed)
	return passed


func _test_save_migration_and_normalization() -> bool:
	var legacy_path := "user://economy_legacy_source.json"
	var legacy := {
		"save_version": 1,
		"progression": {
			"unlocked_levels": ["level_01", "level_02"],
			"completed_levels": ["level_01"],
			"best_stars": {"level_01": 3},
			"fewest_shots": {"level_01": 1},
			"tutorial_completed": {},
			"total_stars": 3,
		},
		"cosmetics": {
			"selected_ball": "ball_neon",
			"selected_trail": "trail_none",
			"selected_goal_effect": "goal_classic",
			"unlocked": ["ball_classic", "ball_neon", "trail_none", "goal_classic"],
		},
		"settings": {},
		"monetization": {},
	}
	_write_json(legacy_path, legacy)
	var migrated := _new_service("legacy")
	_copy_file(legacy_path, migrated.get_save_path())
	var migrated_wallet := WalletServiceScript.new()
	migrated_wallet.configure_save_service(migrated)
	var passed := migrated.load_or_create()
	passed = int(migrated.get_save_data().save_version) == 2 and passed
	passed = migrated.is_level_completed("level_01") and migrated.get_selected_ball() == "ball_neon" and passed
	passed = migrated_wallet.get_coin_balance() == 0 and passed
	var economy: Dictionary = migrated.get_economy_state()
	passed = (economy.first_completion_rewards as Array).has("level_01") and passed
	passed = int((economy.rewarded_star_milestones as Dictionary).get("level_01", 0)) == 3 and passed
	var legacy_replay = migrated.record_level_result(
		LevelResult.completed_result(LevelRegistryScript.load_definition("level_01"), 1),
		LevelRegistryScript.load_definition("level_01")
	)
	passed = int(legacy_replay.coins_earned) == 100 and passed
	migrated_wallet.free()
	migrated.free()

	var malformed := legacy.duplicate(true)
	malformed.save_version = 2
	malformed.economy = {"arcade_coins": -50, "net_tokens": -9, "processed_transaction_ids": ["same", "same"]}
	_write_json(legacy_path, malformed)
	var normalized := _new_service("malformed")
	_copy_file(legacy_path, normalized.get_save_path())
	passed = normalized.load_or_create() and passed
	passed = int(normalized.get_economy_state().arcade_coins) == 0 and passed
	passed = int(normalized.get_economy_state().net_tokens) == 0 and passed
	passed = (normalized.get_economy_state().processed_transaction_ids as Array).size() == 1 and passed
	normalized.free()
	_cleanup_path(legacy_path)
	if not passed:
		print(
			"ECONOMY migration detail migrated_version=", int(migrated.get_save_data().save_version) if is_instance_valid(migrated) else -1,
			" economy=", economy,
			" replay=", legacy_replay.to_dictionary(),
			" malformed=", normalized.get_economy_state() if is_instance_valid(normalized) else {}
		)
	print("ECONOMY migration ok=", passed)
	return passed


func _test_rewarded_token_ads() -> bool:
	service.reset_to_defaults()
	var passed := true
	for index in 5:
		var claim: Dictionary = wallet.claim_rewarded_token_ad("daily:%d" % index, "2026-07-14")
		passed = bool(claim.granted) and int(claim.amount) == 2 and passed
	passed = wallet.get_token_balance() == 10 and passed
	passed = not bool(wallet.claim_rewarded_token_ad("daily:5", "2026-07-14").granted) and passed
	passed = not bool(wallet.claim_rewarded_token_ad("daily:4", "2026-07-14").granted) and passed
	passed = bool(wallet.get_rewarded_token_status("2026-07-15").available) and passed
	passed = not bool(wallet.get_rewarded_token_status("2026-07-13").available) and passed

	service.reset_to_defaults()
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_ads", true, "success", "success", 1, true)
	var reward_request := monetization.call("request_rewarded_tokens") as Dictionary
	await _wait_frames(5)
	passed = bool(reward_request.accepted) and wallet.get_token_balance() == 2 and passed
	service.record_purchase("netbound_remove_ads", "remove_ads_for_reward_test", "test")
	passed = bool(monetization.call("is_rewarded_ad_available")) and passed
	monetization.call("configure_simulated_ads", true, "cancel", "success", 1, false)
	var before_cancel := wallet.get_token_balance()
	monetization.call("request_rewarded_tokens")
	await _wait_frames(4)
	passed = wallet.get_token_balance() == before_cancel and passed
	monetization.call("configure_simulated_ads", true, "failure", "success", 1, false)
	monetization.call("request_rewarded_tokens")
	await _wait_frames(4)
	passed = wallet.get_token_balance() == before_cancel and passed
	print("ECONOMY rewarded_tokens ok=", passed)
	return passed


func _test_cosmetic_purchases() -> bool:
	service.reset_to_defaults()
	var passed := wallet.grant_coins(20000, "shop_fixture", "shop:coins")
	passed = wallet.grant_tokens(600, "shop_fixture", "shop:tokens") and passed
	var coins_before := wallet.get_coin_balance()
	var coin_purchase: Dictionary = wallet.purchase_cosmetic("ball_candy")
	passed = bool(coin_purchase.purchased) and service.is_cosmetic_purchased("ball_candy") and passed
	passed = wallet.get_coin_balance() == coins_before - 1000 and passed
	var after_coin_purchase := wallet.get_coin_balance()
	passed = not bool(wallet.purchase_cosmetic("ball_candy").purchased) and passed
	passed = wallet.get_coin_balance() == after_coin_purchase and passed
	var tokens_before := wallet.get_token_balance()
	passed = bool(wallet.purchase_cosmetic("ball_comet").purchased) and passed
	passed = wallet.get_token_balance() == tokens_before - 50 and passed
	passed = not bool(wallet.purchase_cosmetic("ball_neon").purchased) and passed
	passed = service.set_selected_ball("ball_comet") and service.get_selected_ball() == "ball_comet" and passed
	var reload := _new_service("purchase_reload")
	_copy_file(service.get_save_path(), reload.get_save_path())
	passed = reload.load_or_create() and reload.is_cosmetic_purchased("ball_candy") and passed
	passed = reload.get_selected_ball() == "ball_comet" and passed
	reload.free()
	print("ECONOMY cosmetic_purchases ok=", passed)
	return passed


func _test_token_products() -> bool:
	service.reset_to_defaults()
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_purchases", true, "success", "success", 1, true)
	var passed := true
	var expected := 0
	for product_id in CurrencyProductsScript.get_product_ids():
		monetization.call("set_simulated_transaction_id", "transaction:%s" % product_id)
		var request := monetization.call("purchase_token_pack", product_id) as Dictionary
		await _wait_frames(5)
		expected += CurrencyProductsScript.get_token_amount(product_id)
		passed = bool(request.accepted) and wallet.get_token_balance() == expected and passed
	var duplicate_id := "duplicate_token_transaction"
	monetization.call("set_simulated_transaction_id", duplicate_id)
	monetization.call("purchase_token_pack", "netbound_tokens_100")
	await _wait_frames(4)
	var after_first := wallet.get_token_balance()
	monetization.call("purchase_token_pack", "netbound_tokens_100")
	await _wait_frames(4)
	passed = wallet.get_token_balance() == after_first and passed
	passed = not bool((monetization.call("purchase_token_pack", "invalid_product") as Dictionary).accepted) and passed
	var before_restore := wallet.get_token_balance()
	monetization.call("set_simulated_restore_products", ["netbound_tokens_3000", "netbound_remove_ads"] as Array[String])
	monetization.call("restore_purchases")
	await _wait_frames(5)
	passed = wallet.get_token_balance() == before_restore and service.has_entitlement("entitlement_remove_ads") and passed
	monetization.call("set_simulated_transaction_id", "")
	print("ECONOMY token_products ok=", passed)
	return passed


func _test_starter_pack_bonus() -> bool:
	service.reset_to_defaults()
	monetization.call("reset_session_frequency_for_tests")
	monetization.call("configure_simulated_purchases", true, "success", "success", 1, true)
	monetization.call("set_simulated_transaction_id", "starter_pack_transaction")
	var request := monetization.call("purchase_starter_pack") as Dictionary
	await _wait_frames(5)
	var passed := bool(request.accepted)
	passed = service.has_entitlement("entitlement_starter_pack") and passed
	passed = wallet.get_coin_balance() == 2500 and wallet.get_token_balance() == 300 and passed
	passed = service.is_cosmetic_unlocked("ball_supporter") and passed
	var coins_before_restore := wallet.get_coin_balance()
	var tokens_before_restore := wallet.get_token_balance()
	monetization.call("set_simulated_restore_products", ["netbound_starter_pack"] as Array[String])
	monetization.call("restore_purchases")
	await _wait_frames(5)
	passed = wallet.get_coin_balance() == coins_before_restore and passed
	passed = wallet.get_token_balance() == tokens_before_restore and passed
	monetization.call("set_simulated_transaction_id", "")
	print("ECONOMY starter_pack ok=", passed)
	return passed


func _test_shop_ui() -> bool:
	service.reset_to_defaults()
	wallet.grant_coins(2000, "ui_fixture", "ui:coins")
	wallet.grant_tokens(100, "ui_fixture", "ui:tokens")
	monetization.call("configure_simulated_ads", true, "success", "success", 1, false)
	monetization.call("configure_simulated_purchases", true, "success", "success", 1, false)
	var app := AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(2)
	app.show_cosmetics()
	await _wait_frames(2)
	var passed := app.cosmetic_card_buttons.size() == 18
	passed = app.cosmetic_rarity_filter != null and app.cosmetic_ownership_filter != null and passed
	app.call("_preview_cosmetic", "ball_candy")
	passed = app.cosmetic_purchase_button.visible and not app.cosmetic_purchase_button.disabled and passed
	app.call("_purchase_previewed_cosmetic")
	passed = service.is_cosmetic_purchased("ball_candy") and passed
	app.call("_preview_cosmetic", "ball_comet")
	app.call("_purchase_previewed_cosmetic")
	passed = app.token_purchase_confirmation != null and not service.is_cosmetic_purchased("ball_comet") and passed
	app.call("_confirm_token_purchase")
	passed = service.is_cosmetic_purchased("ball_comet") and passed
	app.show_store("cosmetics")
	await _wait_frames(2)
	passed = app.store_token_pack_buttons.size() == 5 and app.store_rewarded_token_button != null and passed
	app.queue_free()
	await process_frame
	print("ECONOMY shop_ui ok=", passed)
	return passed


func _test_cosmetics_are_visual_only() -> bool:
	service.reset_to_defaults()
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var level := scene.instantiate()
	get_root().add_child(level)
	await _wait_frames(2)
	await physics_frame
	var ball := level.get_node("Ball") as RigidBody3D
	var shape := (ball.get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D
	var mass_before := ball.mass
	var radius_before := shape.radius
	var speed_before := float(level.get("maximum_launch_speed"))
	var passed := true
	for definition in CosmeticRegistryScript.get_by_category("ball"):
		CosmeticVisualsScript.apply_ball_skin(ball, String(definition.cosmetic_id))
		passed = is_equal_approx(ball.mass, mass_before) and is_equal_approx(shape.radius, radius_before) and passed
	for definition in CosmeticRegistryScript.get_by_category("trail"):
		CosmeticVisualsScript.apply_ball_trail(ball, String(definition.cosmetic_id))
		passed = is_equal_approx(ball.mass, mass_before) and passed
	passed = is_equal_approx(float(level.get("maximum_launch_speed")), speed_before) and passed
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await process_frame
	print("ECONOMY visual_only ok=", passed)
	return passed


func _new_service(suffix: String) -> NetboundSaveService:
	var local := SaveServiceScript.new() as NetboundSaveService
	var path := "user://economy_%s.json" % suffix
	local.configure_storage_paths(path, "%s.tmp" % path, "%s.bak" % path, "%s.corrupt" % path)
	local.recording_enabled = true
	return local


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t", true))
		file.close()


func _copy_file(source: String, target: String) -> void:
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file:
		file.store_string(FileAccess.get_file_as_string(source))
		file.close()


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		_cleanup_path(path)
	for suffix in ["wallet_reload", "legacy", "malformed", "purchase_reload"]:
		for extension in ["", ".tmp", ".bak", ".corrupt"]:
			_cleanup_path("user://economy_%s.json%s" % [suffix, extension])


func _cleanup_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
