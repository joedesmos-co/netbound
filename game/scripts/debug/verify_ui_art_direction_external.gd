extends SceneTree

const AppScene := preload("res://app/netbound_app.tscn")
const CosmeticPreviewScript := preload("res://scripts/cosmetics/cosmetic_preview.gd")
const LevelMarkerScript := preload("res://scripts/ui/level_marker.gd")

const TEST_SAVE := "user://ui_art_direction_test.json"
const TEST_TMP := "user://ui_art_direction_test.tmp"
const TEST_BAK := "user://ui_art_direction_test.bak"
const TEST_CORRUPT := "user://ui_art_direction_test.corrupt"

const RESPONSIVE_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1600, 720),
	Vector2i(1920, 864),
	Vector2i(2340, 1080),
	Vector2i(1024, 768),
	Vector2i(1366, 1024),
]

var app: NetboundApp
var service: NetboundSaveService


func _initialize() -> void:
	service = get_root().get_node("SaveService") as NetboundSaveService
	service.configure_storage_paths(TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT)
	service.recording_enabled = true
	service.reset_to_defaults()
	app = AppScene.instantiate() as NetboundApp
	get_root().add_child(app)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := true
	passed = _test_design_system() and passed
	passed = await _test_primary_screens() and passed
	passed = await _test_secondary_screens() and passed
	passed = await _test_white_goal_preview() and passed
	passed = await _test_responsive_markers() and passed
	await _cleanup()
	print("UI_ART_DIRECTION verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _test_design_system() -> bool:
	var palette := [
		NetboundUITheme.INK,
		NetboundUITheme.CHALK,
		NetboundUITheme.PAPER,
		NetboundUITheme.SKY,
		NetboundUITheme.GRASS,
		NetboundUITheme.SIGNAL,
		NetboundUITheme.CORAL,
	]
	var unique_colors: Dictionary = {}
	for color in palette:
		unique_colors[color.to_html()] = true
	var theme: Theme = NetboundUITheme.get_theme()
	var passed: bool = unique_colors.size() == palette.size() \
		and theme != null \
		and FileAccess.file_exists("res://assets/fonts/LiberationSans-Regular.ttf") \
		and FileAccess.file_exists("res://assets/fonts/LiberationSans-Bold.ttf") \
		and FileAccess.file_exists("res://assets/fonts/LiberationSansNarrow-Bold.ttf") \
		and theme.get_type_variation_base("PrimaryButton") == "Button" \
		and theme.get_type_variation_base("SuccessPanel") == "PanelContainer"
	print("UI_ART_DIRECTION system ok=", passed)
	return passed


func _test_primary_screens() -> bool:
	app.show_main_menu()
	await process_frame
	var passed := app.current_screen_name == "main_menu" \
		and app.play_button != null \
		and app.play_button.custom_minimum_size.y >= 64.0
	app.show_level_select()
	await process_frame
	passed = app.current_screen_name == "level_select" \
		and app.get_registered_level_card_count() == 10 \
		and passed
	for card_value in app.level_card_buttons.values():
		var card := card_value as Button
		passed = card != null \
			and card.get_script() == LevelMarkerScript \
			and card.custom_minimum_size.x >= 200.0 \
			and card.custom_minimum_size.y >= 100.0 \
			and passed
	print("UI_ART_DIRECTION primary ok=", passed)
	return passed


func _test_secondary_screens() -> bool:
	app.show_cosmetics()
	await process_frame
	var passed := app.current_screen_name == "cosmetics" \
		and app.cosmetic_category_buttons.size() == 3 \
		and app.cosmetic_preview != null \
		and app.cosmetic_items_box is HBoxContainer
	app.show_store("main_menu")
	await process_frame
	passed = app.current_screen_name == "store" \
		and app.store_product_buttons.size() == 2 \
		and app.store_restore_button != null \
		and passed
	app.show_settings("main_menu")
	await process_frame
	passed = app.current_screen_name == "settings" \
		and app.settings_widgets.has("master_volume") \
		and app.settings_widgets.has("reduced_motion_enabled") \
		and passed
	print("UI_ART_DIRECTION secondary ok=", passed)
	return passed


func _test_white_goal_preview() -> bool:
	var preview := CosmeticPreviewScript.new() as NetboundCosmeticPreview
	get_root().add_child(preview)
	await process_frame
	preview.set_preview("goal_effect", "goal_shockwave")
	await process_frame
	var passed := preview._goal_material != null \
		and preview._goal_material.albedo_color.is_equal_approx(Color.WHITE) \
		and preview._goal_preview_pieces.size() == 12 \
		and preview._goal_preview_ring != null
	preview.queue_free()
	await process_frame
	print("UI_ART_DIRECTION white_goal_preview ok=", passed)
	return passed


func _test_responsive_markers() -> bool:
	var passed := true
	for size in RESPONSIVE_SIZES:
		get_root().size = size
		get_root().content_scale_size = size
		app.show_level_select()
		await process_frame
		await process_frame
		for card_value in app.level_card_buttons.values():
			var card := card_value as Button
			var rect := card.get_global_rect()
			passed = rect.position.x >= -1.0 \
				and rect.position.y >= -1.0 \
				and rect.end.x <= float(size.x) + 1.0 \
				and rect.end.y <= float(size.y) + 1.0 \
				and rect.size.x >= 48.0 \
				and rect.size.y >= 48.0 \
				and passed
	get_root().size = Vector2i(1280, 720)
	get_root().content_scale_size = Vector2i(1280, 720)
	print("UI_ART_DIRECTION responsive ok=", passed)
	return passed


func _cleanup() -> void:
	paused = false
	if app:
		app._clear_result_overlay()
		app._leave_current_level()
		app.queue_free()
		await process_frame
	service.recording_enabled = false
	for path in [TEST_SAVE, TEST_TMP, TEST_BAK, TEST_CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
