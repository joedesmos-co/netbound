extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const SaveServiceScript := preload("res://scripts/services/save_service.gd")
const WalletServiceScript := preload("res://scripts/services/wallet_service.gd")
const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const CosmeticVisualsScript := preload("res://scripts/cosmetics/cosmetic_visuals.gd")
const CurrencyProductsScript := preload("res://scripts/monetization/currency_product_registry.gd")
const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const TEST_SAVE := "user://economy_rc_test.json"
const TEST_TMP := "user://economy_rc_test.tmp"
const TEST_BAK := "user://economy_rc_test.bak"
const TEST_CORRUPT := "user://economy_rc_test.corrupt"

const EXPECTED_COSMETIC_PRICES := {
	"ball_candy": [1000, 0],
	"ball_mint": [1800, 0],
	"ball_watermelon": [2200, 0],
	"ball_sunset": [4000, 0],
	"ball_checker": [5500, 0],
	"ball_cloud": [9000, 0],
	"ball_comet": [0, 50],
	"ball_lava": [0, 80],
	"ball_prism": [0, 150],
	"ball_void": [0, 320],
	"trail_chalk": [1200, 0],
	"trail_bubble": [2000, 0],
	"trail_streamers": [4500, 0],
	"trail_comet": [0, 60],
	"trail_pixel": [0, 140],
	"trail_starfall": [0, 300],
	"goal_ribbons": [1800, 0],
	"goal_splash": [5000, 0],
	"goal_fireworks": [0, 150],
	"goal_portal": [0, 350],
}

const EXPECTED_TOKEN_PRODUCTS := {
	"netbound_tokens_100": 100,
	"netbound_tokens_275": 275,
	"netbound_tokens_600": 600,
	"netbound_tokens_1300": 1300,
	"netbound_tokens_3000": 3000,
}

var service: NetboundSaveService
var wallet: NetboundWalletService
var monetization: NetboundMonetizationService
var mobile_runtime: NetboundMobileRuntimeService


func _initialize() -> void:
	service = get_root().get_node("SaveService") as NetboundSaveService
	wallet = get_root().get_node("WalletService") as NetboundWalletService
	monetization = get_root().get_node("MonetizationService") as NetboundMonetizationService
	mobile_runtime = get_root().get_node("MobileRuntimeService") as NetboundMobileRuntimeService
	_configure_isolated_save()
	service.recording_enabled = true
	wallet.configure_save_service(service)
	service.reset_to_defaults()
	monetization.set_release_mode_enabled(false)
	monetization.reset_session_frequency_for_tests()
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := true
	passed = _test_catalog_contract() and passed
	passed = await _test_production_reward_and_result_flow() and passed
	passed = await _test_shop_interaction_contract() and passed
	passed = await _test_delayed_provider_lifecycle() and passed
	passed = await _test_hostile_save_contract() and passed
	passed = await _test_low_quality_catalog_and_lifecycle() and passed
	await _cleanup()
	print("ECONOMY_RC verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_catalog_contract() -> bool:
	var validation := CosmeticRegistryScript.validate_registry()
	var product_validation := CurrencyProductsScript.validate_registry()
	var all_cosmetics := CosmeticRegistryScript.get_all()
	var seen: Dictionary = {}
	var passed: bool = bool(validation.ok) and bool(product_validation.ok)
	passed = all_cosmetics.size() == 38 and passed
	passed = CosmeticRegistryScript.get_by_category("ball").size() == 18 and passed
	passed = CosmeticRegistryScript.get_by_category("trail").size() == 12 and passed
	passed = CosmeticRegistryScript.get_by_category("goal_effect").size() == 8 and passed
	for definition in all_cosmetics:
		var cosmetic_id := String(definition.get("cosmetic_id", ""))
		passed = not cosmetic_id.is_empty() and not seen.has(cosmetic_id) and passed
		seen[cosmetic_id] = true
		passed = CosmeticRegistryScript.VALID_ACQUISITIONS.has(
			String(definition.get("acquisition_method", ""))
		) and passed
		if EXPECTED_COSMETIC_PRICES.has(cosmetic_id):
			var expected := EXPECTED_COSMETIC_PRICES[cosmetic_id] as Array
			passed = int(definition.get("coin_price", -1)) == int(expected[0]) and passed
			passed = int(definition.get("token_price", -1)) == int(expected[1]) and passed
		else:
			passed = int(definition.get("coin_price", -1)) == 0 and passed
			passed = int(definition.get("token_price", -1)) == 0 and passed
	passed = seen.size() == 38 and EXPECTED_COSMETIC_PRICES.size() == 20 and passed
	passed = CurrencyProductsScript.get_product_ids().size() == EXPECTED_TOKEN_PRODUCTS.size() and passed
	for product_id in EXPECTED_TOKEN_PRODUCTS:
		passed = CurrencyProductsScript.is_token_product(product_id) and passed
		passed = CurrencyProductsScript.get_token_amount(product_id) == int(EXPECTED_TOKEN_PRODUCTS[product_id]) and passed
	print("ECONOMY_RC catalog ok=", passed)
	return passed


func _test_production_reward_and_result_flow() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.reset_session_frequency_for_tests()
	monetization.configure_simulated_ads(true, "success", "success", 1, false)
	var app := AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)
	var passed := wallet.get_coin_balance() == 0 and wallet.get_token_balance() == 0

	passed = app.load_level("level_01") and passed
	await _wait_frames(3)
	var level := app.current_level
	passed = level != null and await _wait_for_ready(level) and passed
	var shot_started := await _send_production_swipe(level)
	passed = shot_started and wallet.get_coin_balance() == 0 and passed
	await level.call("_on_reset_button_pressed")
	passed = await _wait_for_ready(level) and wallet.get_coin_balance() == 0 and passed

	shot_started = await _send_production_swipe(level)
	var auto_reset_shot_id := int(level.get("active_shot_id"))
	level.call("_resolve_miss", auto_reset_shot_id, "economy_rc_auto_reset")
	passed = shot_started and await _wait_for_ready(level, 180) and passed
	passed = wallet.get_coin_balance() == 0 and passed
	await level.call("_on_retry_level_pressed")
	passed = await _wait_for_ready(level) and int(level.get("shots_used")) == 0 and passed
	passed = wallet.get_coin_balance() == 0 and passed

	for miss_index in range(3):
		passed = await _shoot_and_force_miss(level) and passed
		if miss_index < 2:
			passed = await _wait_for_ready(level, 180) and passed
	await _wait_frames(2)
	passed = int(level.get("level_state")) == level.LevelState.FAILED and passed
	passed = app.current_screen_name == "result" and wallet.get_coin_balance() == 0 and passed
	var failure_retry := _find_button_with_text(app.result_overlay, "RETRY")
	passed = failure_retry != null and passed
	if failure_retry:
		failure_retry.emit_signal("pressed")
	await _wait_frames(5)
	level = app.current_level
	passed = level != null and await _wait_for_ready(level) and wallet.get_coin_balance() == 0 and passed

	shot_started = await _send_production_swipe(level)
	var scored := _score_active_shot_through_goal(level)
	await create_timer(0.5, false, false, true).timeout
	var first_result_text := _collect_control_text(app.result_overlay)
	passed = shot_started and scored and wallet.get_coin_balance() == 475 and passed
	passed = service.is_level_completed("level_01") and service.is_level_unlocked("level_02") and passed
	passed = first_result_text.contains("ARCADE COINS  +475") and passed
	passed = first_result_text.contains("FINISH +100") and passed
	passed = first_result_text.contains("FIRST CLEAR +150") and passed
	passed = first_result_text.contains("NEW STARS +225") and passed
	passed = first_result_text.contains("BALANCE 475") and passed

	var balance_before_reopen := wallet.get_coin_balance()
	app.call("_show_success_result", level.get("last_level_result"), level.get("last_progression_update"))
	await process_frame
	passed = wallet.get_coin_balance() == balance_before_reopen and passed
	var success_retry := _find_button_with_text(app.result_overlay, "RETRY")
	passed = success_retry != null and passed
	if success_retry:
		success_retry.emit_signal("pressed")
	await _wait_frames(4)
	passed = wallet.get_coin_balance() == balance_before_reopen and passed

	passed = app.load_level("level_02") and passed
	await _wait_frames(3)
	passed = await _force_production_goal(app, 2, false) and passed
	passed = wallet.get_coin_balance() == 875 and passed
	passed = _collect_control_text(app.result_overlay).contains("ARCADE COINS  +400") and passed
	passed = app.load_level("level_02") and passed
	await _wait_frames(3)
	passed = await _force_production_goal(app, 1, false) and passed
	var improvement_text := _collect_control_text(app.result_overlay)
	passed = wallet.get_coin_balance() == 1100 and passed
	passed = improvement_text.contains("NEW STARS +75") and passed
	passed = improvement_text.contains("NEW BEST +50") and passed

	passed = app.load_level("level_03") and passed
	await _wait_frames(3)
	passed = await _force_production_goal(app, 1, true) and passed
	passed = service.get_best_stars("level_03") == 1 and passed
	passed = _collect_control_text(app.result_overlay).contains("CONTINUE CAP: 1 STAR") and passed

	if app.current_level:
		app.current_level.call("prepare_for_unload")
	if not passed:
		print(
			"ECONOMY_RC production detail balance=", wallet.get_coin_balance(),
			" completed=", service.get_completed_level_count(),
			" stars_l1=", service.get_best_stars("level_01"),
			" stars_l2=", service.get_best_stars("level_02"),
			" stars_l3=", service.get_best_stars("level_03"),
			" screen=", app.current_screen_name,
			" first_text=", first_result_text.replace("\n", " | "),
			" improvement_text=", improvement_text.replace("\n", " | "),
			" final_text=", _collect_control_text(app.result_overlay).replace("\n", " | ")
		)
	app.queue_free()
	await _wait_frames(3)
	print("ECONOMY_RC production_rewards ok=", passed)
	return passed


func _test_shop_interaction_contract() -> bool:
	service.reset_to_defaults()
	monetization.reset_session_frequency_for_tests()
	monetization.set_release_mode_enabled(false)
	monetization.configure_simulated_ads(true, "success", "success", 1, false)
	monetization.configure_simulated_purchases(true, "success", "success", 1, false)
	var app := AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)
	app.show_cosmetics()
	await _wait_frames(3)
	var initial_ok := app.cosmetic_card_buttons.size() == 18
	var passed := initial_ok

	app.call("_preview_cosmetic", "ball_candy")
	await _wait_frames(2)
	var coins_before_insufficient := wallet.get_coin_balance()
	app.cosmetic_purchase_button.emit_signal("pressed")
	await process_frame
	passed = wallet.get_coin_balance() == coins_before_insufficient and passed
	passed = not service.is_cosmetic_purchased("ball_candy") and passed
	passed = app.cosmetic_status_label.text == "NOT ENOUGH CURRENCY" and passed
	var insufficient_ok := wallet.get_coin_balance() == coins_before_insufficient \
		and not service.is_cosmetic_purchased("ball_candy") \
		and app.cosmetic_status_label.text == "NOT ENOUGH CURRENCY"

	passed = wallet.grant_coins(25000, "economy_rc_fixture", "economy_rc:coins") and passed
	passed = wallet.grant_tokens(1500, "economy_rc_fixture", "economy_rc:tokens") and passed
	app.call("_refresh_cosmetics_screen")
	await _wait_frames(2)
	var balances_before_preview := Vector2i(wallet.get_coin_balance(), wallet.get_token_balance())
	var candy_card := app.cosmetic_card_buttons.get("ball_candy") as Button
	passed = candy_card != null and passed
	if candy_card:
		candy_card.emit_signal("pressed")
	await process_frame
	passed = app.previewed_cosmetic_id == "ball_candy" and passed
	passed = Vector2i(wallet.get_coin_balance(), wallet.get_token_balance()) == balances_before_preview and passed
	var preview_ok := app.previewed_cosmetic_id == "ball_candy" \
		and Vector2i(wallet.get_coin_balance(), wallet.get_token_balance()) == balances_before_preview

	app.cosmetic_rarity_filter.emit_signal("item_selected", 2)
	await _wait_frames(2)
	passed = app.current_cosmetic_rarity_filter == "rare" and passed
	passed = app.cosmetic_card_buttons.size() == _expected_filtered_count("ball", "rare", "all") and passed
	app.cosmetic_ownership_filter.emit_signal("item_selected", 1)
	await _wait_frames(2)
	passed = app.current_cosmetic_ownership_filter == "owned" and passed
	passed = app.cosmetic_card_buttons.size() == _expected_filtered_count("ball", "rare", "owned") and passed
	var filter_ok := app.current_cosmetic_rarity_filter == "rare" \
		and app.current_cosmetic_ownership_filter == "owned" \
		and app.cosmetic_card_buttons.size() == _expected_filtered_count("ball", "rare", "owned")
	app.cosmetic_rarity_filter.emit_signal("item_selected", 0)
	app.cosmetic_ownership_filter.emit_signal("item_selected", 0)
	await _wait_frames(3)

	var preview_before_drag := app.previewed_cosmetic_id
	var mint_card := app.cosmetic_card_buttons.get("ball_mint") as Button
	passed = mint_card != null and passed
	if mint_card:
		await _drag_over_control(mint_card)
	passed = app.previewed_cosmetic_id == preview_before_drag and passed
	passed = Vector2i(wallet.get_coin_balance(), wallet.get_token_balance()) == balances_before_preview and passed
	var drag_ok := app.previewed_cosmetic_id == preview_before_drag \
		and Vector2i(wallet.get_coin_balance(), wallet.get_token_balance()) == balances_before_preview

	app.call("_preview_cosmetic", "ball_candy")
	await process_frame
	var coin_price := int(CosmeticRegistryScript.get_definition("ball_candy").coin_price)
	var coins_before_purchase := wallet.get_coin_balance()
	var coin_purchase_button := app.cosmetic_purchase_button
	coin_purchase_button.emit_signal("pressed")
	coin_purchase_button.emit_signal("pressed")
	await _wait_frames(2)
	passed = service.is_cosmetic_purchased("ball_candy") and passed
	passed = wallet.get_coin_balance() == coins_before_purchase - coin_price and passed
	var coin_purchase_ok := service.is_cosmetic_purchased("ball_candy") \
		and wallet.get_coin_balance() == coins_before_purchase - coin_price

	app.call("_preview_cosmetic", "ball_comet")
	await process_frame
	var tokens_before_purchase := wallet.get_token_balance()
	app.cosmetic_purchase_button.emit_signal("pressed")
	await process_frame
	passed = app.token_purchase_confirmation != null and passed
	passed = wallet.get_token_balance() == tokens_before_purchase and passed
	var confirm := _find_button_with_text(app.token_purchase_confirmation, "CONFIRM")
	passed = confirm != null and passed
	if confirm:
		confirm.emit_signal("pressed")
	await _wait_frames(2)
	passed = service.is_cosmetic_purchased("ball_comet") and passed
	passed = wallet.get_token_balance() == tokens_before_purchase - 50 and passed
	var token_purchase_ok := service.is_cosmetic_purchased("ball_comet") \
		and wallet.get_token_balance() == tokens_before_purchase - 50

	app.call("_preview_cosmetic", "ball_neon")
	await process_frame
	var before_locked_intent := Vector2i(wallet.get_coin_balance(), wallet.get_token_balance())
	passed = not app.cosmetic_purchase_button.visible and passed
	app.call("_purchase_previewed_cosmetic")
	passed = Vector2i(wallet.get_coin_balance(), wallet.get_token_balance()) == before_locked_intent and passed
	passed = not service.is_cosmetic_unlocked("ball_neon") and passed
	var locked_ok := Vector2i(wallet.get_coin_balance(), wallet.get_token_balance()) == before_locked_intent \
		and not service.is_cosmetic_unlocked("ball_neon")

	app.call("_preview_cosmetic", "ball_candy")
	await process_frame
	passed = app.cosmetic_equip_button != null and not app.cosmetic_equip_button.disabled and passed
	app.cosmetic_equip_button.emit_signal("pressed")
	await process_frame
	passed = service.get_selected_ball() == "ball_candy" and passed
	var equip_ok := service.get_selected_ball() == "ball_candy"

	mobile_runtime.set_release_mode_override_for_tests(1)
	mobile_runtime.apply_release_configuration(monetization)
	await process_frame
	app.show_store("cosmetics")
	await _wait_frames(3)
	var release_text := _collect_control_text(app.screen_root)
	passed = app.current_screen_name == "store" and passed
	passed = app.store_restore_button.disabled and app.store_rewarded_token_button.disabled and passed
	for button in app.store_token_pack_buttons.values():
		passed = (button as Button).disabled and passed
	passed = release_text.contains("Purchases are unavailable in this offline build") and passed
	passed = not release_text.contains("DEV $") and not release_text.contains("purchases are simulated") and passed
	var release_ok := app.current_screen_name == "store" \
		and app.store_restore_button.disabled \
		and app.store_rewarded_token_button.disabled \
		and release_text.contains("Purchases are unavailable in this offline build") \
		and not release_text.contains("DEV $") \
		and not release_text.contains("purchases are simulated")
	for button in app.store_token_pack_buttons.values():
		release_ok = (button as Button).disabled and release_ok

	mobile_runtime.set_release_mode_override_for_tests(0)
	mobile_runtime.apply_release_configuration(monetization)
	if not passed:
		print(
			"ECONOMY_RC shop detail preview=", app.previewed_cosmetic_id,
			" filters=", app.current_cosmetic_rarity_filter, "/", app.current_cosmetic_ownership_filter,
			" coins=", wallet.get_coin_balance(),
			" tokens=", wallet.get_token_balance(),
			" selected=", service.get_selected_ball(),
			" release_screen=", app.current_screen_name,
			" sections=", [initial_ok, insufficient_ok, preview_ok, filter_ok, drag_ok, coin_purchase_ok, token_purchase_ok, locked_ok, equip_ok, release_ok],
			" release_text=", release_text.replace("\n", " | ")
		)
	app.queue_free()
	await _wait_frames(3)
	print("ECONOMY_RC shop_interactions ok=", passed)
	return passed


func _test_delayed_provider_lifecycle() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	monetization.set_release_mode_enabled(false)
	monetization.reset_session_frequency_for_tests()
	monetization.configure_simulated_purchases(true, "success", "success", 8, true)
	monetization.set_simulated_transaction_id("economy_rc_delayed_product")
	var app := AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)
	app.show_store("main_menu")
	await _wait_frames(3)
	var product_button := app.store_token_pack_buttons.get("netbound_tokens_100") as Button
	var passed := product_button != null
	if product_button:
		product_button.emit_signal("pressed")
	await process_frame
	passed = app.store_request_in_progress and passed
	passed = app.show_main_menu() and passed
	mobile_runtime.simulate_background_for_tests("economy_rc_delayed_purchase")
	await process_frame
	mobile_runtime.simulate_foreground_for_tests("economy_rc_delayed_purchase")
	await _wait_frames(12)
	passed = wallet.get_token_balance() == 100 and passed
	passed = app.current_screen_name == "main_menu" and not app.store_request_in_progress and passed

	monetization.configure_simulated_purchases(true, "success", "success", 1, true)
	monetization.set_simulated_transaction_id("economy_rc_delayed_product")
	var duplicate_request := monetization.purchase_token_pack("netbound_tokens_100")
	await _wait_frames(5)
	passed = bool(duplicate_request.accepted) and wallet.get_token_balance() == 100 and passed

	monetization.set_simulated_transaction_id("")
	app.queue_free()
	await _wait_frames(3)
	print("ECONOMY_RC delayed_provider ok=", passed)
	return passed


func _test_hostile_save_contract() -> bool:
	var passed := true
	var hostile_path := "user://economy_rc_hostile_source.json"
	var processed: Array = []
	var history: Array = []
	for index in 2300:
		processed.append("processed:%04d" % index)
	for index in 90:
		history.append({
			"transaction_id": "history:%03d" % index,
			"currency": "arcade_coins",
			"delta": 1,
			"reason": "hostile_fixture",
			"unix_time": index,
		})
	var hostile_save := {
		"save_version": 2,
		"progression": {"unlocked_levels": ["level_01"]},
		"cosmetics": {
			"selected_ball": "ball_does_not_exist",
			"selected_trail": "trail_does_not_exist",
			"selected_goal_effect": "goal_does_not_exist",
			"unlocked": ["bad_cosmetic", "ball_classic"],
			"purchased": ["bad_purchase", "ball_neon"],
		},
		"settings": {},
		"monetization": {},
		"economy": {
			"arcade_coins": -999,
			"net_tokens": 3000000000,
			"processed_transaction_ids": processed,
			"transaction_history": history,
			"daily_rewarded_tokens": {
				"local_date": "2026-07-14",
				"completed_rewards": 99,
				"tokens_granted": 999,
			},
		},
	}
	_write_json(hostile_path, hostile_save)
	var hostile := _new_service("hostile")
	_copy_file(hostile_path, hostile.get_save_path())
	passed = hostile.load_or_create() and passed
	var hostile_economy := hostile.get_economy_state()
	passed = int(hostile_economy.arcade_coins) == 0 and passed
	passed = int(hostile_economy.net_tokens) == 2000000000 and passed
	passed = (hostile_economy.processed_transaction_ids as Array).size() == 2048 and passed
	passed = (hostile_economy.transaction_history as Array).size() == 64 and passed
	passed = int((hostile_economy.daily_rewarded_tokens as Dictionary).completed_rewards) == 5 and passed
	passed = int((hostile_economy.daily_rewarded_tokens as Dictionary).tokens_granted) == 10 and passed
	passed = hostile.get_selected_ball() == "ball_classic" and passed
	passed = hostile.get_selected_trail() == "trail_none" and passed
	passed = hostile.get_selected_goal_effect() == "goal_classic" and passed
	passed = not hostile.is_cosmetic_unlocked("bad_cosmetic") and passed
	passed = not hostile.is_cosmetic_purchased("ball_neon") and passed
	var hostile_ok := passed
	hostile.free()

	var backup := _new_service("backup")
	var backup_wallet := WalletServiceScript.new() as NetboundWalletService
	backup_wallet.configure_save_service(backup)
	passed = backup.reset_to_defaults() and passed
	passed = backup_wallet.grant_coins(500, "backup_fixture", "backup:500") and passed
	passed = backup_wallet.grant_coins(100, "backup_fixture", "backup:600") and passed
	_write_text(backup.get_save_path(), "{corrupted primary")
	var recovered := _new_service("backup")
	var recovered_wallet := WalletServiceScript.new() as NetboundWalletService
	recovered_wallet.configure_save_service(recovered)
	passed = recovered.load_or_create() and passed
	passed = recovered_wallet.get_coin_balance() == 500 and passed
	passed = recovered_wallet.has_processed_transaction("backup:500") and passed
	passed = not recovered_wallet.has_processed_transaction("backup:600") and passed
	var backup_ok := passed
	backup_wallet.free()
	backup.free()
	recovered_wallet.free()
	recovered.free()

	var purchase := _new_service("purchase_failure")
	var purchase_wallet := WalletServiceScript.new() as NetboundWalletService
	purchase_wallet.configure_save_service(purchase)
	passed = purchase.reset_to_defaults() and passed
	passed = purchase_wallet.grant_coins(2000, "purchase_fixture", "purchase:funds") and passed
	var purchase_balance := purchase_wallet.get_coin_balance()
	purchase.simulate_next_write_failure_for_tests()
	var failed_purchase := purchase_wallet.purchase_cosmetic("ball_candy")
	passed = not bool(failed_purchase.purchased) and passed
	passed = purchase_wallet.get_coin_balance() == purchase_balance and passed
	passed = not purchase.is_cosmetic_purchased("ball_candy") and passed
	passed = bool(purchase_wallet.purchase_cosmetic("ball_candy").purchased) and passed
	passed = purchase_wallet.get_coin_balance() == purchase_balance - 1000 and passed
	var purchase_ok := passed
	purchase_wallet.free()
	purchase.free()

	var completion := _new_service("completion_failure")
	var completion_wallet := WalletServiceScript.new() as NetboundWalletService
	completion_wallet.configure_save_service(completion)
	passed = completion.reset_to_defaults() and passed
	completion.simulate_next_write_failure_for_tests()
	var definition := LevelRegistryScript.load_definition("level_01")
	var failed_completion := completion.record_level_result(
		LevelResult.completed_result(definition, 1),
		definition
	)
	passed = not bool(failed_completion.save_succeeded) and passed
	passed = completion_wallet.get_coin_balance() == 0 and passed
	passed = not completion.is_level_completed("level_01") and passed
	passed = not completion.is_level_unlocked("level_02") and passed
	passed = int(failed_completion.coins_earned) == 0 and passed
	var save_failure_app := AppScene.instantiate() as NetboundApp
	get_root().add_child(save_failure_app)
	await _wait_frames(2)
	save_failure_app.call(
		"_show_success_result",
		LevelResult.completed_result(definition, 1),
		failed_completion
	)
	await process_frame
	var failed_result_text := _collect_control_text(save_failure_app.result_overlay)
	passed = failed_result_text.contains("SAVE FAILED  //  PROGRESS NOT RECORDED") and passed
	passed = not failed_result_text.contains("ARCADE COINS") and passed
	save_failure_app.queue_free()
	await _wait_frames(2)
	var completion_retry := completion.record_level_result(
		LevelResult.completed_result(definition, 1),
		definition
	)
	passed = bool(completion_retry.save_succeeded) and passed
	passed = int(completion_retry.coins_earned) == 475 and passed
	passed = completion_wallet.get_coin_balance() == 475 and passed
	passed = completion.is_level_completed("level_01") and passed
	var completion_ok := passed
	completion_wallet.free()
	completion.free()

	var legacy := hostile_save.duplicate(true)
	legacy.erase("economy")
	legacy.save_version = 1
	legacy.progression = {
		"unlocked_levels": ["level_01", "level_02"],
		"completed_levels": ["level_01"],
		"best_stars": {"level_01": 3},
		"fewest_shots": {"level_01": 1},
	}
	legacy.cosmetics = {
		"selected_ball": "ball_neon",
		"selected_trail": "trail_none",
		"selected_goal_effect": "goal_classic",
		"unlocked": ["ball_classic", "ball_neon", "trail_none", "goal_classic"],
	}
	_write_json(hostile_path, legacy)
	var migrated := _new_service("legacy_rc")
	_copy_file(hostile_path, migrated.get_save_path())
	var migrated_wallet := WalletServiceScript.new() as NetboundWalletService
	migrated_wallet.configure_save_service(migrated)
	passed = migrated.load_or_create() and passed
	passed = int(migrated.get_save_data().save_version) == 2 and passed
	passed = migrated_wallet.get_coin_balance() == 0 and passed
	var migrated_replay := migrated.record_level_result(
		LevelResult.completed_result(LevelRegistryScript.load_definition("level_01"), 1),
		LevelRegistryScript.load_definition("level_01")
	)
	passed = int(migrated_replay.coins_earned) == 100 and passed
	var migration_ok := passed
	migrated_wallet.free()
	migrated.free()
	_cleanup_path(hostile_path)
	if not passed:
		print(
			"ECONOMY_RC hostile detail normalized=", hostile_ok,
			" backup=", backup_ok,
			" purchase=", purchase_ok,
			" completion=", completion_ok,
			" migration=", migration_ok,
			" failed_completion=", failed_completion.to_dictionary()
		)
	print("ECONOMY_RC hostile_save ok=", passed)
	return passed


func _test_low_quality_catalog_and_lifecycle() -> bool:
	service.reset_to_defaults()
	service.recording_enabled = true
	service.unlock_all_cosmetics_for_development()
	service.set_setting_value("quality_tier", "low")
	var low_config := mobile_runtime.apply_quality_from_save(service)
	var app := AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	await _wait_frames(3)
	app.show_cosmetics()
	await _wait_frames(3)
	var passed := String(low_config.get("effective_tier", "")) == "low"
	var preview_ok := passed
	passed = int(low_config.get("trail_point_limit", 0)) == 8 and passed
	var balances_before_preview := Vector2i(wallet.get_coin_balance(), wallet.get_token_balance())
	for pass_index in 2:
		for definition in CosmeticRegistryScript.get_all():
			var cosmetic_id := String(definition.cosmetic_id)
			var category := String(definition.category)
			app.call("_preview_cosmetic", cosmetic_id)
			await _wait_frames(2)
			preview_ok = app.cosmetic_preview != null and preview_ok
			preview_ok = String(app.cosmetic_preview.current_category) == category and preview_ok
			preview_ok = String(app.cosmetic_preview.current_cosmetic_id) == cosmetic_id and preview_ok
			preview_ok = app.cosmetic_name_label.text == String(definition.display_name) and preview_ok
		preview_ok = Vector2i(wallet.get_coin_balance(), wallet.get_token_balance()) == balances_before_preview and preview_ok
	var preview_nodes_after_warmup := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var preview_resources_after_warmup := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for definition in CosmeticRegistryScript.get_all():
		app.call("_preview_cosmetic", String(definition.cosmetic_id))
		await _wait_frames(2)
	var preview_nodes_after_repeat := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var preview_resources_after_repeat := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	preview_ok = preview_nodes_after_repeat <= preview_nodes_after_warmup + 4 and preview_ok
	preview_ok = preview_resources_after_repeat <= preview_resources_after_warmup + 4 and preview_ok
	var idle_nodes_before := preview_nodes_after_repeat
	var idle_resources_before := preview_resources_after_repeat
	await _wait_frames(90)
	preview_ok = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) == idle_nodes_before and preview_ok
	preview_ok = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) == idle_resources_before and preview_ok
	passed = preview_ok and passed

	var level_scene := load("res://levels/level_01.tscn") as PackedScene
	var level := level_scene.instantiate()
	get_root().add_child(level)
	await _wait_frames(3)
	await physics_frame
	level.call("apply_quality_settings", low_config)
	var ball := level.get_node("Ball") as RigidBody3D
	var shape := (ball.get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D
	var mass_before := ball.mass
	var radius_before := shape.radius
	var speed_before := float(level.get("maximum_launch_speed"))
	var physics_ok := true
	for definition in CosmeticRegistryScript.get_by_category("ball"):
		CosmeticVisualsScript.apply_ball_skin(ball, String(definition.cosmetic_id))
		physics_ok = is_equal_approx(ball.mass, mass_before) and is_equal_approx(shape.radius, radius_before) and physics_ok
	for pass_index in 2:
		for definition in CosmeticRegistryScript.get_by_category("trail"):
			CosmeticVisualsScript.apply_ball_trail(ball, String(definition.cosmetic_id))
			var trail := ball.get_node_or_null("NetboundBallTrail")
			trail.call("configure_quality", low_config)
			physics_ok = int(trail.call("get_point_limit")) == 8 and physics_ok
			physics_ok = (trail.get("_positions") as Array).size() <= 8 and physics_ok
			physics_ok = is_equal_approx(ball.mass, mass_before) and physics_ok
	physics_ok = is_equal_approx(float(level.get("maximum_launch_speed")), speed_before) and physics_ok
	passed = physics_ok and passed

	var effects_ok := true
	for definition in CosmeticRegistryScript.get_by_category("goal_effect"):
		var nodes_before := _count_descendants(level)
		CosmeticVisualsScript.trigger_goal_effect(
			level,
			level.get("goal_root") as Node3D,
			level.get("goal_flash") as ColorRect,
			level.get("goal_particles") as CPUParticles3D,
			String(definition.cosmetic_id)
		)
		var particles := level.get("goal_particles") as CPUParticles3D
		particles.set_meta("phase9_base_amount", particles.amount)
		level.call("_apply_quality_to_goal_particles")
		effects_ok = particles.amount <= 44 and effects_ok
		effects_ok = get_nodes_in_group(CosmeticVisualsScript.GOAL_EFFECT_GROUP).size() <= 2 and effects_ok
		effects_ok = _count_descendants(level) - nodes_before <= 26 and effects_ok
		CosmeticVisualsScript.clear_goal_effects(level)
		await _wait_frames(2)
		effects_ok = get_nodes_in_group(CosmeticVisualsScript.GOAL_EFFECT_GROUP).is_empty() and effects_ok
	passed = effects_ok and passed
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	app.queue_free()
	await _wait_frames(4)

	service.reset_to_defaults()
	var lifecycle_app := AppScene.instantiate() as NetboundApp
	get_root().add_child(lifecycle_app)
	await _wait_frames(3)
	var stable_node_count := -1
	var stable_resource_count := -1
	var flow_node_counts: Array[int] = []
	var flow_resource_counts: Array[int] = []
	var flow_details: Array[Dictionary] = []
	var flow_ok := true
	for cycle in 5:
		var store_before_ok := lifecycle_app.show_store("main_menu")
		await _wait_frames(3)
		var load_ok := lifecycle_app.load_level("level_01")
		flow_ok = store_before_ok and load_ok and flow_ok
		await _wait_frames(3)
		var goal_ok := await _force_production_goal(lifecycle_app, 1, false)
		flow_ok = goal_ok and flow_ok
		var store_after_ok := lifecycle_app.show_store("main_menu")
		flow_ok = store_after_ok and flow_ok
		await _wait_frames(4)
		var cleared_ok := lifecycle_app.current_level == null
		var effects_cleared_ok := get_nodes_in_group(CosmeticVisualsScript.GOAL_EFFECT_GROUP).is_empty()
		flow_ok = cleared_ok and effects_cleared_ok and flow_ok
		if cycle == 0:
			stable_node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			stable_resource_count = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		else:
			flow_ok = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) <= stable_node_count + 4 and flow_ok
			flow_ok = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= stable_resource_count + 4 and flow_ok
		flow_node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		flow_resource_counts.append(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
		flow_details.append({
			"cycle": cycle,
			"store_before": store_before_ok,
			"load": load_ok,
			"goal": goal_ok,
			"store_after": store_after_ok,
			"cleared": cleared_ok,
			"effects_cleared": effects_cleared_ok,
			"screen": lifecycle_app.current_screen_name,
		})
	passed = flow_ok and passed
	lifecycle_app.queue_free()
	await _wait_frames(4)
	print(
		"ECONOMY_RC low_quality_lifecycle ok=", passed,
		" preview_nodes=", preview_nodes_after_warmup, "->", preview_nodes_after_repeat,
		" preview_resources=", preview_resources_after_warmup, "->", preview_resources_after_repeat,
		" flow_nodes=", stable_node_count,
		" flow_counts=", flow_node_counts,
		" flow_resources=", stable_resource_count,
		" flow_resource_counts=", flow_resource_counts,
		" flow_details=", flow_details,
		" sections=", [preview_ok, physics_ok, effects_ok, flow_ok]
	)
	return passed


func _force_production_goal(app: NetboundApp, shots_used: int, rewarded_continue: bool) -> bool:
	var level := app.current_level
	if not level or not await _wait_for_ready(level):
		return false
	level.set("shots_used", shots_used)
	level.set("shots_remaining", maxi(int(level.get("max_shots")) - shots_used, 0))
	level.set("rewarded_continue_used", rewarded_continue)
	level.set("active_shot_id", int(level.get("active_shot_id")) + 1)
	level.set("level_state", level.LevelState.SHOT_ACTIVE)
	level.call("_on_goal_scored")
	await create_timer(0.5, false, false, true).timeout
	return int(level.get("level_state")) == level.LevelState.GOAL and app.current_screen_name == "result"


func _shoot_and_force_miss(level: Node) -> bool:
	var shot_started := await _send_production_swipe(level)
	if not shot_started:
		return false
	var shot_id := int(level.get("active_shot_id"))
	level.call("_resolve_miss", shot_id, "economy_rc_miss")
	await physics_frame
	return int(level.get("level_state")) in [level.LevelState.AUTO_RESETTING, level.LevelState.FAILED]


func _send_production_swipe(level: Node) -> bool:
	var ball := level.get_node("Ball") as RigidBody3D
	var camera := level.get_node("Camera3D") as Camera3D
	var shots_before := int(level.get("shots_remaining"))
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


func _score_active_shot_through_goal(level: Node) -> bool:
	var active_shot_id := int(level.get("active_shot_id"))
	var goal := level.get_node("Goal") as GoalTarget
	goal.reset_shot_tracking()
	goal.begin_shot_tracking(active_shot_id, Vector3(0.0, 2.5, -8.0))
	return goal.process_ball(Vector3(0.0, 2.5, -12.0), 0.49, active_shot_id)


func _wait_for_ready(level: Node, max_frames: int = 120) -> bool:
	for _index in range(max_frames):
		if not is_instance_valid(level):
			return false
		if int(level.get("level_state")) == level.LevelState.READY and not bool(level.get("reset_in_progress")):
			return true
		await physics_frame
	return false


func _drag_over_control(control: Control) -> void:
	var start := control.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = start
	touch.pressed = true
	get_root().push_input(touch, true)
	await process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = start + Vector2(-140.0, 0.0)
	drag.relative = Vector2(-140.0, 0.0)
	get_root().push_input(drag, true)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = drag.position
	release.pressed = false
	get_root().push_input(release, true)
	await _wait_frames(2)


func _expected_filtered_count(category: String, rarity: String, ownership: String) -> int:
	var count := 0
	for definition in CosmeticRegistryScript.get_by_category(category):
		if rarity != "all" and String(definition.rarity) != rarity:
			continue
		var owned := service.is_cosmetic_unlocked(String(definition.cosmetic_id))
		if ownership == "owned" and not owned:
			continue
		if ownership == "unowned" and owned:
			continue
		count += 1
	return count


func _find_button_with_text(root: Node, expected_text: String) -> Button:
	if not root:
		return null
	if root is Button and String((root as Button).text).strip_edges() == expected_text:
		return root as Button
	for child in root.get_children():
		var found := _find_button_with_text(child, expected_text)
		if found:
			return found
	return null


func _collect_control_text(root: Node) -> String:
	if not root:
		return ""
	var values: Array[String] = []
	_collect_control_text_recursive(root, values)
	return "\n".join(values)


func _collect_control_text_recursive(root: Node, values: Array[String]) -> void:
	if root is Label:
		values.append((root as Label).text)
	elif root is Button:
		values.append((root as Button).text)
	for child in root.get_children():
		_collect_control_text_recursive(child, values)


func _count_descendants(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		count += 1 + _count_descendants(child)
	return count


func _configure_isolated_save() -> void:
	_cleanup_test_files()
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)


func _new_service(suffix: String) -> NetboundSaveService:
	var local := SaveServiceScript.new() as NetboundSaveService
	var path := "user://economy_rc_%s.json" % suffix
	local.configure_storage_paths(path, "%s.tmp" % path, "%s.bak" % path, "%s.corrupt" % path)
	local.recording_enabled = true
	return local


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data, "\t", true))


func _write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(contents)
		file.close()


func _copy_file(source: String, target: String) -> void:
	_write_text(target, FileAccess.get_file_as_string(source))


func _cleanup() -> void:
	paused = false
	Engine.time_scale = 1.0
	monetization.set_release_mode_enabled(false)
	mobile_runtime.set_release_mode_override_for_tests(-1)
	monetization.set_simulated_transaction_id("")
	service.recording_enabled = false
	_cleanup_test_files()
	await _wait_frames(2)


func _cleanup_test_files() -> void:
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		_cleanup_path(path)
	for suffix in ["hostile", "backup", "purchase_failure", "completion_failure", "legacy_rc"]:
		for extension in ["", ".tmp", ".bak", ".corrupt"]:
			_cleanup_path("user://economy_rc_%s.json%s" % [suffix, extension])
	_cleanup_path("user://economy_rc_hostile_source.json")


func _cleanup_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
