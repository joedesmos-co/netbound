class_name NetboundApp
extends Node

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const MenuBackdropScript := preload("res://scripts/ui/menu_backdrop.gd")
const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const CosmeticPreviewScript := preload("res://scripts/cosmetics/cosmetic_preview.gd")

const APP_VERSION_LABEL := "Vertical Slice P9"
const MAX_STARS := 30
const SAFE_MARGIN := 28
const SAFE_AREA_GROUP := "netbound_safe_area_margin"
const RESULT_REVEAL_DELAY := 0.35
const TOUCH_MINIMUM := Vector2(48.0, 48.0)
const ENTITLEMENT_REMOVE_ADS := "entitlement_remove_ads"
const ENTITLEMENT_STARTER_PACK := "entitlement_starter_pack"
const PRODUCT_REMOVE_ADS := "netbound_remove_ads"
const PRODUCT_STARTER_PACK := "netbound_starter_pack"
const CONTEXT_REWARDED_CONTINUE := "rewarded_continue"
const CONTEXT_NEXT_LEVEL := "next_level"
const CONTEXT_LEVEL_SELECT_AFTER_SUCCESS := "level_select_after_success"
const COSMETIC_CATEGORIES := [
	CosmeticRegistryScript.CATEGORY_BALL,
	CosmeticRegistryScript.CATEGORY_TRAIL,
	CosmeticRegistryScript.CATEGORY_GOAL_EFFECT,
]

var current_level_id: String = ""
var current_level: Node
var current_screen_name: String = ""
var previous_menu_screen: String = "main_menu"
var navigation_in_progress: bool = false
var level_card_buttons: Dictionary = {}
var result_overlay: Control
var pause_overlay: Control
var screen_root: CanvasLayer
var gameplay_overlay_root: CanvasLayer
var level_root: Node
var fade_rect: ColorRect
var status_label: Label
var play_button: Button
var play_subtitle_label: Label
var total_stars_label: Label
var level_grid: GridContainer
var result_title_label: Label
var result_detail_label: Label
var result_stars_label: Label
var result_best_label: Label
var result_unlock_label: Label
var result_next_button: Button
var settings_widgets: Dictionary = {}
var last_status_message: String = ""
var current_cosmetic_category: String = CosmeticRegistryScript.CATEGORY_BALL
var previewed_cosmetic_id: String = "ball_classic"
var cosmetic_category_buttons: Dictionary = {}
var cosmetic_card_buttons: Dictionary = {}
var cosmetic_items_box: VBoxContainer
var cosmetic_preview
var cosmetic_name_label: Label
var cosmetic_description_label: Label
var cosmetic_requirement_label: Label
var cosmetic_status_label: Label
var cosmetic_equip_button: Button
var cosmetic_store_button: Button
var store_status_label: Label
var store_remove_ads_button: Button
var store_starter_pack_button: Button
var store_restore_button: Button
var store_product_buttons: Dictionary = {}
var gameplay_pause_button: Button
var store_request_in_progress: bool = false
var store_pending_product_id: String = ""
var rewarded_continue_button: Button
var rewarded_continue_status_label: Label
var rewarded_continue_request_in_progress: bool = false
var rewarded_continue_level_instance_id: int = -1
var active_ui_tweens: Array[Tween] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_root = Node.new()
	level_root.name = "LevelRoot"
	add_child(level_root)

	screen_root = CanvasLayer.new()
	screen_root.name = "ScreenRoot"
	screen_root.layer = 20
	screen_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(screen_root)

	gameplay_overlay_root = CanvasLayer.new()
	gameplay_overlay_root.name = "GameplayOverlayRoot"
	gameplay_overlay_root.layer = 30
	gameplay_overlay_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(gameplay_overlay_root)

	fade_rect = ColorRect.new()
	fade_rect.name = "Fade"
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_root.add_child(fade_rect)

	_get_save_service().load_or_create()
	_connect_monetization_service()
	_connect_mobile_runtime_service()
	_apply_saved_settings()
	_show_main_menu_internal()


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_navigation()
	elif (
		(what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED)
		and not _get_mobile_runtime_service()
	):
		_on_mobile_app_backgrounded("app_notification")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			_handle_back_navigation()
			get_viewport().set_input_as_handled()


func show_main_menu() -> bool:
	if not _begin_navigation():
		return false
	_leave_current_level()
	_show_main_menu_internal()
	return true


func show_level_select() -> bool:
	if not _begin_navigation():
		return false
	_leave_current_level()
	_show_level_select_internal()
	return true


func show_settings(return_screen: String = "") -> bool:
	if not _begin_navigation():
		return false
	if not return_screen.is_empty():
		previous_menu_screen = return_screen
	elif current_screen_name in ["main_menu", "level_select", "cosmetics", "store"]:
		previous_menu_screen = current_screen_name
	_show_settings_internal()
	return true


func show_cosmetics() -> bool:
	if not _begin_navigation():
		return false
	previous_menu_screen = current_screen_name if current_screen_name != "cosmetics" else "main_menu"
	_show_cosmetics_internal()
	return true


func show_store(return_screen: String = "") -> bool:
	if not _begin_navigation():
		return false
	if not return_screen.is_empty():
		previous_menu_screen = return_screen
	elif current_screen_name in ["main_menu", "level_select", "cosmetics", "pause"]:
		previous_menu_screen = current_screen_name
	else:
		previous_menu_screen = "main_menu"
	_show_store_internal()
	return true


func request_continue() -> bool:
	var resolution := get_play_resolution()
	var action := String(resolution.get("action", ""))
	if action == "level":
		return load_level(String(resolution.get("level_id", "")))
	if action == "level_select":
		return show_level_select()
	_set_status("No playable level is available.")
	return false


func request_level_launch(level_id: String) -> bool:
	if not LevelRegistryScript.has_level_id(level_id):
		_set_status("That level is not registered.")
		_play_ui_feedback("ui_locked", "ui_tap", 0.45)
		return false
	if not _get_save_service().is_level_unlocked(level_id):
		_set_status("Complete earlier levels to unlock this one.")
		_play_ui_feedback("ui_locked", "ui_tap", 0.45)
		return false
	return load_level(level_id)


func load_level(level_id: String) -> bool:
	if not _begin_navigation():
		return false
	if not LevelRegistryScript.has_level_id(level_id):
		_set_status("Level not found: %s" % level_id)
		return false
	if not _get_save_service().is_level_unlocked(level_id):
		_set_status("Level is locked: %s" % level_id)
		return false

	var scene_path := LevelRegistryScript.get_scene_path(level_id)
	var packed := load(scene_path) as PackedScene
	if not packed:
		_set_status("Unable to load level scene.")
		_show_main_menu_internal()
		return false

	_leave_current_level()
	_clear_screen()
	_clear_gameplay_overlay()
	gameplay_overlay_root.visible = true
	current_level_id = level_id
	current_screen_name = "gameplay"
	current_level = packed.instantiate()
	current_level.name = "GameplayLevel"
	if current_level.has_method("set_external_navigation_ui_enabled"):
		current_level.call("set_external_navigation_ui_enabled", true)
	if current_level.has_signal("level_completed"):
		current_level.connect("level_completed", _on_level_completed)
	if current_level.has_signal("level_failed"):
		current_level.connect("level_failed", _on_level_failed)
	level_root.add_child(current_level)
	_apply_safe_area_to_level()
	_apply_developer_debug_to_level()
	_apply_presentation_settings_to_level()
	_apply_quality_settings_to_level()
	_build_gameplay_overlay()
	_play_gameplay_music(level_id)
	return true


func show_pause_menu() -> bool:
	if current_screen_name != "gameplay" or not current_level:
		return false
	if pause_overlay and pause_overlay.visible:
		return true
	_cancel_active_level_gesture()
	get_tree().paused = true
	current_screen_name = "pause"
	pause_overlay = _build_pause_overlay()
	gameplay_overlay_root.add_child(pause_overlay)
	return true


func resume_game() -> void:
	if pause_overlay:
		pause_overlay.queue_free()
		pause_overlay = null
	get_tree().paused = false
	if current_level:
		current_screen_name = "gameplay"


func restart_current_level() -> void:
	if not current_level:
		return
	resume_game()
	if result_overlay:
		result_overlay.queue_free()
		result_overlay = null
	if current_level.has_method("_restart_level"):
		await current_level.call("_restart_level")
	_apply_safe_area_to_level()
	_apply_quality_settings_to_level()


func get_play_resolution() -> Dictionary:
	var service := _get_save_service()
	var level_ids := LevelRegistryScript.get_level_ids()
	var highest_unlocked := ""
	var any_incomplete := false

	for level_id in level_ids:
		var unlocked: bool = service.is_level_unlocked(level_id)
		var completed: bool = service.is_level_completed(level_id)
		if not completed:
			any_incomplete = true
		if unlocked:
			highest_unlocked = level_id
			if not completed:
				var definition := LevelRegistryScript.load_definition(level_id)
				return {
					"action": "level",
					"level_id": level_id,
					"subtitle": "Continue: %s" % definition.display_name,
				}

	if not any_incomplete:
		return {
			"action": "level_select",
			"level_id": "",
			"subtitle": "All levels complete",
		}

	if not highest_unlocked.is_empty():
		var fallback_definition := LevelRegistryScript.load_definition(highest_unlocked)
		return {
			"action": "level",
			"level_id": highest_unlocked,
			"subtitle": "Replay: %s" % fallback_definition.display_name,
		}

	var first_id := LevelRegistryScript.get_first_level_id()
	var first_definition := LevelRegistryScript.load_definition(first_id)
	return {
		"action": "level",
		"level_id": first_id,
		"subtitle": "Play Level 1: %s" % first_definition.display_name,
	}


func get_registered_level_card_count() -> int:
	return level_card_buttons.size()


func set_setting_value(setting_name: String, value: Variant) -> bool:
	var saved: bool = _get_save_service().set_setting_value(setting_name, value)
	_apply_saved_settings()
	_refresh_settings_labels()
	return saved


func _show_main_menu_internal() -> void:
	get_tree().paused = false
	current_screen_name = "main_menu"
	_clear_screen()
	_clear_gameplay_overlay()
	_play_menu_music()

	var screen := _new_screen("MainMenu")
	var backdrop := MenuBackdropScript.new()
	screen.add_child(backdrop)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)

	var margin := _new_margin_container()
	screen.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "NETBOUND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.16, 1.0))
	layout.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Arcade trick-shot soccer"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	layout.add_child(subtitle)

	play_button = _new_menu_button("Play", true)
	play_button.pressed.connect(request_continue)
	layout.add_child(play_button)

	play_subtitle_label = Label.new()
	play_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_subtitle_label.add_theme_font_size_override("font_size", 17)
	layout.add_child(play_subtitle_label)

	var level_select_button := _new_menu_button("Level Select")
	level_select_button.pressed.connect(show_level_select)
	layout.add_child(level_select_button)

	var cosmetics_button := _new_menu_button("Cosmetics")
	cosmetics_button.pressed.connect(show_cosmetics)
	layout.add_child(cosmetics_button)

	var store_button := _new_menu_button("Store")
	store_button.pressed.connect(func() -> void: show_store("main_menu"))
	layout.add_child(store_button)

	var settings_button := _new_menu_button("Settings")
	settings_button.pressed.connect(func() -> void: show_settings("main_menu"))
	layout.add_child(settings_button)

	if not OS.has_feature("mobile"):
		var quit_button := _new_menu_button("Quit")
		quit_button.pressed.connect(func() -> void: get_tree().quit())
		layout.add_child(quit_button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	layout.add_child(status_label)

	var build := Label.new()
	build.text = APP_VERSION_LABEL
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	build.add_theme_font_size_override("font_size", 14)
	build.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.58))
	build.set_anchors_preset(Control.PRESET_FULL_RECT)
	_position_bottom_right_label(build)
	screen.add_child(build)

	screen_root.add_child(screen)
	_refresh_main_menu_play_state()
	_animate_screen_entrance(screen)


func _show_level_select_internal() -> void:
	get_tree().paused = false
	current_screen_name = "level_select"
	_clear_screen()
	_clear_gameplay_overlay()
	_play_menu_music()
	level_card_buttons.clear()

	var screen := _new_screen("LevelSelect")
	screen.add_child(_new_flat_backdrop())
	var margin := _new_margin_container()
	screen.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer.add_child(header)

	var back_button := _new_small_button("Back")
	back_button.pressed.connect(show_main_menu)
	header.add_child(back_button)

	var title := Label.new()
	title.text = "Level Select"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	header.add_child(title)

	total_stars_label = Label.new()
	total_stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_stars_label.add_theme_font_size_override("font_size", 22)
	header.add_child(total_stars_label)

	var continue_button := _new_small_button("Continue")
	continue_button.pressed.connect(request_continue)
	outer.add_child(continue_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	level_grid = GridContainer.new()
	level_grid.add_theme_constant_override("h_separation", 12)
	level_grid.add_theme_constant_override("v_separation", 12)
	level_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(level_grid)

	for i in LevelRegistryScript.get_level_ids().size():
		var level_id := LevelRegistryScript.get_level_ids()[i]
		var card := _build_level_card(level_id, i)
		level_grid.add_child(card)
		level_card_buttons[level_id] = card

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(status_label)

	screen_root.add_child(screen)
	_refresh_level_grid_columns()
	_refresh_level_select_state()
	_animate_screen_entrance(screen)


func _show_settings_internal() -> void:
	current_screen_name = "settings"
	_clear_screen()
	if previous_menu_screen != "pause":
		_play_menu_music()
	if pause_overlay:
		pause_overlay.queue_free()
		pause_overlay = null
	gameplay_overlay_root.visible = previous_menu_screen != "pause"
	settings_widgets.clear()

	var screen := _new_screen("Settings")
	screen.add_child(_new_flat_backdrop())
	var margin := _new_margin_container()
	screen.add_child(margin)

	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	outer.add_child(title)

	_add_volume_setting(outer, "Master Volume", "master_volume")
	_add_volume_setting(outer, "Music Volume", "music_volume")
	_add_volume_setting(outer, "SFX Volume", "sfx_volume")
	_add_toggle_setting(outer, "Haptics", "haptics_enabled")
	_add_toggle_setting(outer, "Reduced Motion", "reduced_motion_enabled")
	_add_volume_setting(outer, "Camera Effects", "camera_effects_intensity")
	_add_quality_setting(outer)
	if _development_controls_allowed():
		_add_toggle_setting(outer, "Developer Debug", "developer_debug")

	var back_button := _new_menu_button("Back", true)
	back_button.pressed.connect(_return_from_submenu)
	outer.add_child(back_button)

	screen_root.add_child(screen)
	_refresh_settings_labels()
	_animate_screen_entrance(screen)


func _show_cosmetics_internal() -> void:
	current_screen_name = "cosmetics"
	_clear_screen()
	if previous_menu_screen != "pause":
		_play_menu_music()
	cosmetic_category_buttons.clear()
	cosmetic_card_buttons.clear()

	var screen := _new_screen("Cosmetics")
	screen.add_child(_new_flat_backdrop())
	var margin := _new_margin_container()
	screen.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer.add_child(header)

	var back_button := _new_small_button("Back")
	back_button.pressed.connect(_return_from_submenu)
	header.add_child(back_button)

	var title := Label.new()
	title.text = "Cosmetics"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 36)
	header.add_child(title)

	var stars := Label.new()
	stars.text = "Stars: %d / %d" % [_get_save_service().get_total_stars(), MAX_STARS]
	stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stars.add_theme_font_size_override("font_size", 20)
	header.add_child(stars)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(390.0, 0.0)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(preview_panel)

	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 16)
	preview_margin.add_theme_constant_override("margin_top", 16)
	preview_margin.add_theme_constant_override("margin_right", 16)
	preview_margin.add_theme_constant_override("margin_bottom", 16)
	preview_panel.add_child(preview_margin)

	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 10)
	preview_margin.add_child(preview_box)

	cosmetic_preview = CosmeticPreviewScript.new()
	cosmetic_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cosmetic_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_box.add_child(cosmetic_preview)

	cosmetic_name_label = Label.new()
	cosmetic_name_label.add_theme_font_size_override("font_size", 28)
	cosmetic_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_box.add_child(cosmetic_name_label)

	cosmetic_description_label = Label.new()
	cosmetic_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cosmetic_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cosmetic_description_label.add_theme_font_size_override("font_size", 17)
	preview_box.add_child(cosmetic_description_label)

	cosmetic_requirement_label = Label.new()
	cosmetic_requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cosmetic_requirement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cosmetic_requirement_label.add_theme_font_size_override("font_size", 16)
	preview_box.add_child(cosmetic_requirement_label)

	cosmetic_equip_button = _new_menu_button("Equip", true)
	cosmetic_equip_button.pressed.connect(_equip_previewed_cosmetic)
	preview_box.add_child(cosmetic_equip_button)

	cosmetic_store_button = _new_menu_button("Open Store")
	cosmetic_store_button.pressed.connect(func() -> void: show_store("cosmetics"))
	preview_box.add_child(cosmetic_store_button)

	cosmetic_status_label = Label.new()
	cosmetic_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cosmetic_status_label.add_theme_font_size_override("font_size", 16)
	preview_box.add_child(cosmetic_status_label)

	var list_column := VBoxContainer.new()
	list_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_column.add_theme_constant_override("separation", 10)
	body.add_child(list_column)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	list_column.add_child(tabs)
	for category in COSMETIC_CATEGORIES:
		var category_name := CosmeticRegistryScript.get_category_plural_name(String(category))
		var tab := _new_small_button(category_name)
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var category_copy := String(category)
		tab.pressed.connect(func() -> void: _select_cosmetic_category(category_copy))
		tabs.add_child(tab)
		cosmetic_category_buttons[category_copy] = tab

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_column.add_child(scroll)

	cosmetic_items_box = VBoxContainer.new()
	cosmetic_items_box.add_theme_constant_override("separation", 10)
	cosmetic_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cosmetic_items_box)

	screen_root.add_child(screen)
	_refresh_cosmetics_screen()
	_animate_screen_entrance(screen)


func _select_cosmetic_category(category: String) -> void:
	if not CosmeticRegistryScript.is_valid_category(category):
		return
	current_cosmetic_category = category
	previewed_cosmetic_id = _get_save_service().get_selected_cosmetic(category)
	_refresh_cosmetics_screen()


func _preview_cosmetic(cosmetic_id: String) -> void:
	var definition := CosmeticRegistryScript.get_definition(cosmetic_id)
	if definition.is_empty():
		return
	current_cosmetic_category = String(definition.get("category", current_cosmetic_category))
	previewed_cosmetic_id = cosmetic_id
	_refresh_cosmetics_screen()


func _equip_previewed_cosmetic() -> void:
	var service := _get_save_service()
	if not service.is_cosmetic_unlocked(previewed_cosmetic_id):
		cosmetic_status_label.text = "Locked"
		_play_ui_feedback("ui_locked", "ui_tap", 0.45)
		return
	if service.set_selected_cosmetic(current_cosmetic_category, previewed_cosmetic_id):
		cosmetic_status_label.text = "Equipped"
		_play_ui_feedback("ui_confirm", "ui_tap", 0.65)
	else:
		cosmetic_status_label.text = "Unable to equip"
		_play_ui_feedback("ui_locked", "ui_tap", 0.45)
	_refresh_cosmetics_screen()


func _refresh_cosmetics_screen() -> void:
	if not cosmetic_items_box:
		return
	if not CosmeticRegistryScript.is_valid_category(current_cosmetic_category):
		current_cosmetic_category = CosmeticRegistryScript.CATEGORY_BALL

	var service := _get_save_service()
	for category in cosmetic_category_buttons.keys():
		var tab := cosmetic_category_buttons[category] as Button
		if tab:
			tab.button_pressed = String(category) == current_cosmetic_category

	if previewed_cosmetic_id.is_empty():
		previewed_cosmetic_id = service.get_selected_cosmetic(current_cosmetic_category)
	var preview_definition := CosmeticRegistryScript.get_definition(previewed_cosmetic_id)
	if (
		preview_definition.is_empty()
		or String(preview_definition.get("category", "")) != current_cosmetic_category
	):
		previewed_cosmetic_id = service.get_selected_cosmetic(current_cosmetic_category)
		preview_definition = CosmeticRegistryScript.get_definition(previewed_cosmetic_id)

	for child in cosmetic_items_box.get_children():
		child.queue_free()
	cosmetic_card_buttons.clear()

	for definition in CosmeticRegistryScript.get_by_category(current_cosmetic_category):
		var card := _build_cosmetic_card(definition)
		cosmetic_items_box.add_child(card)
		cosmetic_card_buttons[String(definition.get("cosmetic_id", ""))] = card

	_refresh_cosmetic_preview_panel(preview_definition)


func _build_cosmetic_card(definition: Dictionary) -> Button:
	var cosmetic_id := String(definition.get("cosmetic_id", ""))
	var display_name := String(definition.get("display_name", cosmetic_id))
	var service := _get_save_service()
	var unlocked: bool = service.is_cosmetic_unlocked(cosmetic_id)
	var selected: bool = service.get_selected_cosmetic(current_cosmetic_category) == cosmetic_id
	var previewed: bool = previewed_cosmetic_id == cosmetic_id
	var state_text := "Selected" if selected else ("Unlocked" if unlocked else "Locked")
	var card := Button.new()
	card.custom_minimum_size = Vector2(280.0, 112.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_ALL
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.text = "%s%s\n%s\n%s" % [
		"> " if previewed else "",
		display_name,
		state_text,
		CosmeticRegistryScript.get_unlock_requirement_text(cosmetic_id),
	]
	var cosmetic_id_copy := cosmetic_id
	card.pressed.connect(func() -> void: _preview_cosmetic(cosmetic_id_copy))
	return card


func _refresh_cosmetic_preview_panel(definition: Dictionary) -> void:
	if definition.is_empty():
		return
	var cosmetic_id := String(definition.get("cosmetic_id", ""))
	var service := _get_save_service()
	var unlocked: bool = service.is_cosmetic_unlocked(cosmetic_id)
	var selected: bool = service.get_selected_cosmetic(current_cosmetic_category) == cosmetic_id
	if cosmetic_preview:
		cosmetic_preview.set_preview(current_cosmetic_category, cosmetic_id)
	if cosmetic_name_label:
		cosmetic_name_label.text = String(definition.get("display_name", cosmetic_id))
	if cosmetic_description_label:
		cosmetic_description_label.text = String(definition.get("description", ""))
	if cosmetic_requirement_label:
		cosmetic_requirement_label.text = CosmeticRegistryScript.get_unlock_requirement_text(cosmetic_id)
	if cosmetic_equip_button:
		cosmetic_equip_button.disabled = not unlocked or selected
		cosmetic_equip_button.text = "Selected" if selected else ("Equip" if unlocked else "Locked")
	if cosmetic_store_button:
		var requirement := definition.get("unlock_requirement", {}) as Dictionary
		var requires_starter_pack := (
			String(requirement.get("type", "")) == CosmeticRegistryScript.REQUIREMENT_ENTITLEMENT
		)
		cosmetic_store_button.visible = requires_starter_pack and not unlocked
		cosmetic_store_button.disabled = not cosmetic_store_button.visible
	if cosmetic_status_label:
		if selected:
			cosmetic_status_label.text = "Currently equipped"
		elif unlocked:
			cosmetic_status_label.text = "Unlocked"
		else:
			cosmetic_status_label.text = "Preview only"


func _show_store_internal() -> void:
	current_screen_name = "store"
	_clear_screen()
	if previous_menu_screen != "pause":
		_play_menu_music()
	if pause_overlay:
		pause_overlay.queue_free()
		pause_overlay = null
	gameplay_overlay_root.visible = previous_menu_screen == "pause"
	store_product_buttons.clear()

	var screen := _new_screen("Store")
	screen.add_child(_new_flat_backdrop())
	var margin := _new_margin_container()
	screen.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 14)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer.add_child(header)

	var back_button := _new_small_button("Back")
	back_button.pressed.connect(_return_from_submenu)
	header.add_child(back_button)

	var title := Label.new()
	title.text = "Store"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 40)
	header.add_child(title)

	var note := Label.new()
	note.text = _store_note_text()
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 17)
	outer.add_child(note)

	var products := VBoxContainer.new()
	products.add_theme_constant_override("separation", 12)
	products.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(products)

	store_remove_ads_button = _build_store_product_button(
		PRODUCT_REMOVE_ADS,
		"Remove Ads",
		"Turns off interstitial ads permanently. Rewarded continues remain optional."
	)
	store_remove_ads_button.pressed.connect(_purchase_remove_ads)
	products.add_child(store_remove_ads_button)

	store_starter_pack_button = _build_store_product_button(
		PRODUCT_STARTER_PACK,
		"Starter Pack",
		"Includes Remove Ads plus the Supporter ball, trail, and goal effect."
	)
	store_starter_pack_button.pressed.connect(_purchase_starter_pack)
	products.add_child(store_starter_pack_button)

	store_restore_button = _new_menu_button("Restore Purchases")
	store_restore_button.pressed.connect(_restore_purchases)
	outer.add_child(store_restore_button)

	store_status_label = Label.new()
	store_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	store_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	store_status_label.add_theme_font_size_override("font_size", 17)
	outer.add_child(store_status_label)

	screen_root.add_child(screen)
	_refresh_store_screen()
	_animate_screen_entrance(screen)


func _build_store_product_button(product_id: String, display_name: String, description: String) -> Button:
	var button := Button.new()
	button.name = product_id
	button.custom_minimum_size = Vector2(560.0, 112.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.set_meta("product_id", product_id)
	button.set_meta("display_name", display_name)
	button.set_meta("description", description)
	store_product_buttons[product_id] = button
	_connect_button_feedback(button, "ui_confirm")
	return button


func _refresh_store_screen() -> void:
	var monetization := _get_monetization_service()
	var save_service := _get_save_service()
	var purchase_available := bool(
		monetization
		and monetization.has_method("is_purchase_available")
		and monetization.call("is_purchase_available")
	)
	_refresh_store_product_button(
		store_remove_ads_button,
		save_service.has_entitlement(ENTITLEMENT_REMOVE_ADS),
		purchase_available
	)
	_refresh_store_product_button(
		store_starter_pack_button,
		save_service.has_entitlement(ENTITLEMENT_STARTER_PACK),
		purchase_available
	)
	if store_restore_button:
		store_restore_button.disabled = store_request_in_progress or not purchase_available
	if store_status_label:
		if store_request_in_progress:
			store_status_label.text = "Contacting simulated store..."
		elif not purchase_available:
			store_status_label.text = "Purchases unavailable. Offline play and owned items still work."
		elif store_status_label.text.is_empty():
			store_status_label.text = "Purchases are cosmetic/convenience only."


func _refresh_store_product_button(button: Button, owned: bool, purchase_available: bool) -> void:
	if not button:
		return
	var product_id := String(button.get_meta("product_id", ""))
	var display_name := String(button.get_meta("display_name", product_id))
	var description := String(button.get_meta("description", ""))
	var monetization := _get_monetization_service()
	var product_info := (
		monetization.call("get_product_info", product_id)
		if monetization and monetization.has_method("get_product_info")
		else {"price_text": "Unavailable", "available": false}
	) as Dictionary
	var product_available := purchase_available and bool(product_info.get("available", false))
	var action_text := "Owned" if owned else (
		"Unavailable" if not product_available else "Purchase - %s" % String(product_info.get("price_text", ""))
	)
	if store_request_in_progress and product_id == store_pending_product_id:
		action_text = "Processing..."
	button.disabled = store_request_in_progress or owned or not product_available
	button.text = "%s\n%s\n%s" % [display_name, description, action_text]


func _purchase_remove_ads() -> void:
	_start_store_purchase(PRODUCT_REMOVE_ADS)


func _purchase_starter_pack() -> void:
	_start_store_purchase(PRODUCT_STARTER_PACK)


func _start_store_purchase(product_id: String) -> void:
	if store_request_in_progress:
		return
	var monetization := _get_monetization_service()
	if not monetization:
		_set_store_status("Store unavailable.")
		return
	var result := {}
	if product_id == PRODUCT_REMOVE_ADS:
		result = monetization.call("purchase_remove_ads")
	elif product_id == PRODUCT_STARTER_PACK:
		result = monetization.call("purchase_starter_pack")
	else:
		result = {"accepted": false, "reason": "unknown product"}
	if bool(result.get("accepted", false)):
		store_request_in_progress = true
		store_pending_product_id = product_id
		_set_store_status("Purchase simulation in progress...")
	else:
		_set_store_status(String(result.get("reason", "Purchase unavailable.")))
	_refresh_store_screen()


func _restore_purchases() -> void:
	if store_request_in_progress:
		return
	var monetization := _get_monetization_service()
	if not monetization or not monetization.has_method("restore_purchases"):
		_set_store_status("Restore unavailable.")
		return
	var result: Dictionary = monetization.call("restore_purchases")
	if bool(result.get("accepted", false)):
		store_request_in_progress = true
		store_pending_product_id = "restore"
		_set_store_status("Restore simulation in progress...")
	else:
		_set_store_status(String(result.get("reason", "Restore unavailable.")))
	_refresh_store_screen()


func _set_store_status(message: String) -> void:
	last_status_message = message
	if store_status_label:
		store_status_label.text = message


func _build_gameplay_overlay() -> void:
	_clear_gameplay_overlay()
	var layer_control := Control.new()
	layer_control.name = "GameplayChrome"
	layer_control.process_mode = Node.PROCESS_MODE_ALWAYS
	layer_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_overlay_root.add_child(layer_control)

	gameplay_pause_button = _new_small_button("Pause")
	gameplay_pause_button.name = "PauseButton"
	gameplay_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gameplay_pause_button.pressed.connect(show_pause_menu)
	layer_control.add_child(gameplay_pause_button)
	_position_gameplay_pause_button()


func _build_pause_overlay() -> Control:
	var overlay := _new_modal_overlay("PauseOverlay")
	var panel := _new_center_panel(Vector2(460.0, 420.0))
	overlay.add_child(panel)

	var box := _panel_vbox(panel)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	var resume_button := _new_menu_button("Resume", true)
	resume_button.pressed.connect(resume_game)
	box.add_child(resume_button)

	var restart_button := _new_menu_button("Restart Level")
	restart_button.pressed.connect(restart_current_level)
	box.add_child(restart_button)

	var select_button := _new_menu_button("Level Select")
	select_button.pressed.connect(show_level_select)
	box.add_child(select_button)

	var settings_button := _new_menu_button("Settings")
	settings_button.pressed.connect(func() -> void: show_settings("pause"))
	box.add_child(settings_button)

	var menu_button := _new_menu_button("Main Menu")
	menu_button.pressed.connect(show_main_menu)
	box.add_child(menu_button)
	return overlay


func _show_success_result(level_result: LevelResult, progression_update: RefCounted) -> void:
	_clear_result_overlay()
	current_screen_name = "result"
	_play_sfx("result_success")
	var definition := LevelRegistryScript.load_definition(level_result.level_id)
	var overlay := _new_modal_overlay("ResultOverlay")
	var panel := _new_center_panel(Vector2(620.0, 620.0))
	overlay.add_child(panel)
	var box := _panel_vbox(panel)

	result_title_label = Label.new()
	result_title_label.text = "Goal Complete"
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title_label.add_theme_font_size_override("font_size", 38)
	box.add_child(result_title_label)

	var level_name := definition.display_name if definition else level_result.level_id
	result_detail_label = Label.new()
	result_detail_label.text = "%s\nShots: %d / %d   Par: %d" % [
		level_name,
		level_result.shots_used,
		level_result.shot_limit,
		level_result.par_shots,
	]
	result_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail_label.add_theme_font_size_override("font_size", 21)
	box.add_child(result_detail_label)

	var run_stars := _get_update_int(progression_update, "stars_earned", 0)
	result_stars_label = Label.new()
	result_stars_label.text = "Stars this run: %d / 3   Total: %d / %d" % [
		run_stars,
		_get_save_service().get_total_stars(),
		MAX_STARS,
	]
	if level_result.rewarded_continue_used:
		result_stars_label.text += "\nAd continue used: max 1 star"
	result_stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_stars_label.add_theme_font_size_override("font_size", 22)
	box.add_child(result_stars_label)

	var previous_best := _get_update_int(progression_update, "previous_best_stars", 0)
	var new_best := _get_update_int(progression_update, "new_best_stars", previous_best)
	var previous_fewest := _get_update_int(progression_update, "previous_fewest_shots", -1)
	var new_fewest := _get_update_int(progression_update, "new_fewest_shots", previous_fewest)
	var improved := new_best > previous_best or (previous_fewest < 0 or new_fewest < previous_fewest)
	result_best_label = Label.new()
	result_best_label.text = "Best: %d -> %d stars   Fewest shots: %s%s" % [
		previous_best,
		new_best,
		("--" if previous_fewest < 0 else str(previous_fewest)),
		(" -> %d" % new_fewest if new_fewest >= 0 else ""),
	]
	if improved:
		result_best_label.text += "\nNew best result"
	result_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_best_label.add_theme_font_size_override("font_size", 18)
	box.add_child(result_best_label)

	result_unlock_label = Label.new()
	result_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_unlock_label.add_theme_font_size_override("font_size", 18)
	var unlocked_id := _get_update_string(progression_update, "unlocked_level_id", "")
	if not unlocked_id.is_empty():
		var unlocked_definition := LevelRegistryScript.load_definition(unlocked_id)
		result_unlock_label.text = "Unlocked: %s" % unlocked_definition.display_name
	elif level_result.level_id == LevelRegistryScript.get_level_ids()[-1]:
		result_unlock_label.text = "All production levels complete"
	else:
		result_unlock_label.text = ""
	box.add_child(result_unlock_label)

	var cosmetic_unlock_ids := _get_update_string_array(progression_update, "unlocked_cosmetic_ids")
	if not cosmetic_unlock_ids.is_empty():
		_play_sfx("cosmetic_unlock")
		var cosmetic_unlock_label := Label.new()
		cosmetic_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cosmetic_unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cosmetic_unlock_label.add_theme_font_size_override("font_size", 17)
		cosmetic_unlock_label.text = _format_cosmetic_unlock_text(cosmetic_unlock_ids)
		box.add_child(cosmetic_unlock_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)

	result_next_button = _new_small_button("Next Level")
	var next_id := definition.next_level_id if definition else ""
	result_next_button.disabled = next_id.is_empty() or not _get_save_service().is_level_unlocked(next_id)
	result_next_button.pressed.connect(func() -> void: _navigate_to_next_after_success(next_id))
	actions.add_child(result_next_button)

	var retry_button := _new_small_button("Retry")
	retry_button.pressed.connect(func() -> void: load_level(level_result.level_id))
	actions.add_child(retry_button)

	var select_button := _new_small_button("Level Select")
	select_button.pressed.connect(_show_level_select_after_success)
	actions.add_child(select_button)

	var menu_button := _new_small_button("Main Menu")
	menu_button.pressed.connect(show_main_menu)
	actions.add_child(menu_button)

	result_overlay = overlay
	gameplay_overlay_root.add_child(result_overlay)
	_animate_modal_entrance(result_overlay)
	_animate_result_reveal(box)


func _show_failure_result(level_result: LevelResult) -> void:
	_clear_result_overlay()
	current_screen_name = "result"
	_play_sfx("result_failure")
	var definition := LevelRegistryScript.load_definition(level_result.level_id)
	var overlay := _new_modal_overlay("FailureOverlay")
	var panel := _new_center_panel(Vector2(540.0, 540.0))
	overlay.add_child(panel)
	var box := _panel_vbox(panel)

	result_title_label = Label.new()
	result_title_label.text = "Out of Shots"
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title_label.add_theme_font_size_override("font_size", 38)
	box.add_child(result_title_label)

	result_detail_label = Label.new()
	result_detail_label.text = "%s\nShots used: %d / %d" % [
		definition.display_name if definition else level_result.level_id,
		level_result.shots_used,
		level_result.shot_limit,
	]
	result_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail_label.add_theme_font_size_override("font_size", 22)
	box.add_child(result_detail_label)

	rewarded_continue_button = _new_menu_button("Watch Ad for 1 Extra Shot", true)
	rewarded_continue_button.name = "RewardedContinueButton"
	rewarded_continue_button.pressed.connect(_request_rewarded_continue)
	box.add_child(rewarded_continue_button)

	rewarded_continue_status_label = Label.new()
	rewarded_continue_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewarded_continue_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rewarded_continue_status_label.add_theme_font_size_override("font_size", 16)
	box.add_child(rewarded_continue_status_label)

	var retry_button := _new_menu_button("Retry", true)
	retry_button.pressed.connect(func() -> void: load_level(level_result.level_id))
	box.add_child(retry_button)

	var select_button := _new_menu_button("Level Select")
	select_button.pressed.connect(show_level_select)
	box.add_child(select_button)

	var menu_button := _new_menu_button("Main Menu")
	menu_button.pressed.connect(show_main_menu)
	box.add_child(menu_button)

	result_overlay = overlay
	gameplay_overlay_root.add_child(result_overlay)
	_refresh_rewarded_continue_button()
	_animate_modal_entrance(result_overlay)
	_animate_result_reveal(box)


func _on_level_completed(level_result: LevelResult, progression_update: RefCounted) -> void:
	var monetization := _get_monetization_service()
	if monetization and monetization.has_method("record_level_completion_for_ads"):
		monetization.call("record_level_completion_for_ads")
	var expected_level := current_level
	await get_tree().create_timer(RESULT_REVEAL_DELAY, false, false, true).timeout
	if expected_level != current_level or not current_level:
		return
	_show_success_result(level_result, progression_update)


func _on_level_failed(level_result: LevelResult) -> void:
	_show_failure_result(level_result)


func _request_rewarded_continue() -> void:
	if rewarded_continue_request_in_progress:
		return
	var availability := _rewarded_continue_availability()
	if not bool(availability.get("available", false)):
		_set_rewarded_continue_status(String(availability.get("reason", "Extra shot unavailable.")))
		_refresh_rewarded_continue_button()
		return
	var monetization := _get_monetization_service()
	rewarded_continue_request_in_progress = true
	rewarded_continue_level_instance_id = current_level.get_instance_id() if current_level else -1
	var request_result: Dictionary = monetization.call(
		"request_rewarded_ad",
		CONTEXT_REWARDED_CONTINUE,
		{
			"level_id": current_level_id,
			"level_instance_id": rewarded_continue_level_instance_id,
		}
	)
	if not bool(request_result.get("accepted", false)):
		rewarded_continue_request_in_progress = false
		_set_rewarded_continue_status(_friendly_monetization_reason(String(request_result.get("reason", ""))))
	else:
		_set_rewarded_continue_status("Watching simulated ad...")
	_refresh_rewarded_continue_button()


func _rewarded_continue_availability() -> Dictionary:
	if not current_level or not current_level.has_method("can_use_rewarded_continue"):
		return {"available": false, "reason": "No failed level to continue."}
	if rewarded_continue_request_in_progress:
		return {"available": false, "reason": "Ad already running."}
	if not bool(current_level.call("can_use_rewarded_continue")):
		return {"available": false, "reason": "Extra shot already used for this attempt."}
	var monetization := _get_monetization_service()
	if not monetization or not monetization.has_method("is_rewarded_ad_available"):
		return {"available": false, "reason": "Ads unavailable."}
	if not bool(monetization.call("is_rewarded_ad_available")):
		return {"available": false, "reason": "Ads unavailable offline."}
	return {"available": true, "reason": ""}


func _refresh_rewarded_continue_button() -> void:
	if not rewarded_continue_button:
		return
	var availability := _rewarded_continue_availability()
	var available := bool(availability.get("available", false))
	rewarded_continue_button.disabled = not available
	if rewarded_continue_request_in_progress:
		rewarded_continue_button.text = "Ad Running..."
	elif available:
		rewarded_continue_button.text = "Watch Ad for 1 Extra Shot"
	else:
		rewarded_continue_button.text = "Extra Shot Unavailable"
	if rewarded_continue_status_label and not rewarded_continue_request_in_progress:
		rewarded_continue_status_label.text = (
			"Complete after an ad continue for up to 1 star."
			if available
			else String(availability.get("reason", "Extra shot unavailable."))
		)


func _set_rewarded_continue_status(message: String) -> void:
	last_status_message = message
	if rewarded_continue_status_label:
		rewarded_continue_status_label.text = message


func _navigate_to_next_after_success(next_id: String) -> void:
	_maybe_request_interstitial(CONTEXT_NEXT_LEVEL)
	load_level(next_id)


func _show_level_select_after_success() -> void:
	_maybe_request_interstitial(CONTEXT_LEVEL_SELECT_AFTER_SUCCESS)
	show_level_select()


func _maybe_request_interstitial(context: String) -> void:
	var monetization := _get_monetization_service()
	if monetization and monetization.has_method("request_interstitial"):
		monetization.call("request_interstitial", context)


func _on_monetization_reward_granted(
	context: String,
	_request_id: int,
	metadata: Dictionary
) -> void:
	if context != CONTEXT_REWARDED_CONTINUE:
		return
	rewarded_continue_request_in_progress = false
	var expected_instance_id := int(metadata.get("level_instance_id", -1))
	if (
		not current_level
		or current_level.get_instance_id() != expected_instance_id
		or not current_level.has_method("grant_rewarded_continue")
	):
		return
	var granted: bool = await current_level.call("grant_rewarded_continue")
	if granted:
		_clear_result_overlay()
		rewarded_continue_button = null
		rewarded_continue_status_label = null
		current_screen_name = "gameplay"
	else:
		_set_rewarded_continue_status("Extra shot unavailable now.")
		_refresh_rewarded_continue_button()


func _on_monetization_reward_failed(context: String, _request_id: int, reason: String) -> void:
	if context != CONTEXT_REWARDED_CONTINUE:
		return
	rewarded_continue_request_in_progress = false
	_set_rewarded_continue_status(_friendly_monetization_reason(reason))
	_refresh_rewarded_continue_button()


func _on_monetization_purchase_started(product_id: String, _request_id: int) -> void:
	store_request_in_progress = true
	store_pending_product_id = product_id
	_set_store_status("Contacting simulated store...")
	_refresh_store_screen()


func _on_monetization_purchase_completed(product_id: String, _request_id: int) -> void:
	store_request_in_progress = false
	store_pending_product_id = ""
	_set_store_status("%s owned." % _product_display_name(product_id))
	_refresh_store_screen()
	if current_screen_name == "cosmetics":
		_refresh_cosmetics_screen()


func _on_monetization_purchase_failed(product_id: String, _request_id: int, reason: String) -> void:
	store_request_in_progress = false
	store_pending_product_id = ""
	_set_store_status("%s: %s" % [_product_display_name(product_id), _friendly_monetization_reason(reason)])
	_refresh_store_screen()


func _on_monetization_purchases_restored(product_ids: Array[String], _request_id: int) -> void:
	store_request_in_progress = false
	store_pending_product_id = ""
	if product_ids.is_empty():
		_set_store_status("No simulated purchases to restore.")
	else:
		var names: Array[String] = []
		for product_id in product_ids:
			names.append(_product_display_name(product_id))
		_set_store_status("Restored: %s" % ", ".join(names))
	_refresh_store_screen()
	if current_screen_name == "cosmetics":
		_refresh_cosmetics_screen()


func _on_monetization_entitlement_changed(_entitlement_id: String) -> void:
	if current_screen_name == "store":
		_refresh_store_screen()
	elif current_screen_name == "cosmetics":
		_refresh_cosmetics_screen()


func _return_from_submenu() -> void:
	if previous_menu_screen == "level_select":
		show_level_select()
	elif previous_menu_screen == "pause":
		_show_pause_return()
	elif previous_menu_screen == "cosmetics":
		show_cosmetics()
	else:
		show_main_menu()


func _show_pause_return() -> void:
	_clear_screen()
	gameplay_overlay_root.visible = true
	current_screen_name = "gameplay"
	show_pause_menu()


func _handle_back_navigation() -> void:
	if current_screen_name == "gameplay":
		show_pause_menu()
	elif current_screen_name == "pause":
		resume_game()
	elif current_screen_name == "settings" or current_screen_name == "cosmetics" or current_screen_name == "store":
		_return_from_submenu()
	elif current_screen_name == "level_select":
		show_main_menu()
	elif current_screen_name == "result":
		show_level_select()


func _leave_current_level() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	rewarded_continue_request_in_progress = false
	rewarded_continue_level_instance_id = -1
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service and audio_service.has_method("cleanup_scene_audio"):
		audio_service.call("cleanup_scene_audio")
	_clear_gameplay_overlay()
	if current_level:
		if current_level.has_method("prepare_for_unload"):
			current_level.call("prepare_for_unload")
		current_level.queue_free()
	current_level = null
	current_level_id = ""


func _cancel_active_level_gesture() -> void:
	if current_level and current_level.has_method("cancel_active_gesture_for_lifecycle"):
		current_level.call("cancel_active_gesture_for_lifecycle")


func _clear_screen() -> void:
	_kill_ui_tweens()
	for child in screen_root.get_children():
		if child != fade_rect:
			child.queue_free()
	status_label = null
	cosmetic_items_box = null
	cosmetic_preview = null
	cosmetic_name_label = null
	cosmetic_description_label = null
	cosmetic_requirement_label = null
	cosmetic_status_label = null
	cosmetic_equip_button = null
	cosmetic_store_button = null
	store_status_label = null
	store_remove_ads_button = null
	store_starter_pack_button = null
	store_restore_button = null
	store_product_buttons.clear()
	cosmetic_category_buttons.clear()
	cosmetic_card_buttons.clear()


func _clear_gameplay_overlay() -> void:
	_kill_ui_tweens()
	gameplay_overlay_root.visible = true
	for child in gameplay_overlay_root.get_children():
		child.queue_free()
	pause_overlay = null
	result_overlay = null
	gameplay_pause_button = null
	rewarded_continue_button = null
	rewarded_continue_status_label = null


func _clear_result_overlay() -> void:
	if result_overlay:
		result_overlay.queue_free()
		result_overlay = null
	rewarded_continue_button = null
	rewarded_continue_status_label = null


func _begin_navigation() -> bool:
	if navigation_in_progress:
		return false
	navigation_in_progress = true
	call_deferred("_release_navigation_lock")
	return true


func _release_navigation_lock() -> void:
	navigation_in_progress = false


func _get_save_service() -> Node:
	if not is_inside_tree():
		return null
	return get_node("/root/SaveService")


func _get_monetization_service() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/MonetizationService")


func _get_mobile_runtime_service() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/MobileRuntimeService")


func _connect_monetization_service() -> void:
	var monetization := _get_monetization_service()
	if not monetization:
		return
	var connections := {
		"reward_granted": Callable(self, "_on_monetization_reward_granted"),
		"rewarded_ad_failed": Callable(self, "_on_monetization_reward_failed"),
		"purchase_started": Callable(self, "_on_monetization_purchase_started"),
		"purchase_completed": Callable(self, "_on_monetization_purchase_completed"),
		"purchase_failed": Callable(self, "_on_monetization_purchase_failed"),
		"purchases_restored": Callable(self, "_on_monetization_purchases_restored"),
		"entitlement_changed": Callable(self, "_on_monetization_entitlement_changed"),
	}
	for signal_name in connections.keys():
		var callback := connections[signal_name] as Callable
		if monetization.has_signal(String(signal_name)) and not monetization.is_connected(String(signal_name), callback):
			monetization.connect(String(signal_name), callback)


func _connect_mobile_runtime_service() -> void:
	var mobile_runtime := _get_mobile_runtime_service()
	if not mobile_runtime:
		return
	var connections := {
		"safe_area_changed": Callable(self, "_on_safe_area_changed"),
		"app_backgrounded": Callable(self, "_on_mobile_app_backgrounded"),
		"app_foregrounded": Callable(self, "_on_mobile_app_foregrounded"),
		"app_quit_requested": Callable(self, "_on_mobile_app_quit_requested"),
	}
	for signal_name in connections.keys():
		var callback := connections[signal_name] as Callable
		if mobile_runtime.has_signal(String(signal_name)) and not mobile_runtime.is_connected(String(signal_name), callback):
			mobile_runtime.connect(String(signal_name), callback)
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func _on_safe_area_changed(_margins: Dictionary) -> void:
	_refresh_safe_area_layout()


func _on_viewport_size_changed() -> void:
	_refresh_safe_area_layout()
	_refresh_level_grid_columns()


func _on_mobile_app_backgrounded(_reason: String) -> void:
	_cancel_active_level_gesture()
	if current_level and current_level.has_method("handle_app_backgrounded"):
		current_level.call("handle_app_backgrounded", _reason)
	if current_screen_name == "gameplay":
		show_pause_menu()
	var save_service := _get_save_service()
	if save_service and save_service.has_method("flush_if_dirty"):
		save_service.call("flush_if_dirty")


func _on_mobile_app_foregrounded(_reason: String) -> void:
	if current_level and current_level.has_method("handle_app_foregrounded"):
		current_level.call("handle_app_foregrounded", _reason)
	_refresh_safe_area_layout()


func _on_mobile_app_quit_requested(_reason: String) -> void:
	var save_service := _get_save_service()
	if save_service and save_service.has_method("flush_if_dirty"):
		save_service.call("flush_if_dirty")


func _refresh_main_menu_play_state() -> void:
	var resolution := get_play_resolution()
	if play_subtitle_label:
		play_subtitle_label.text = String(resolution.get("subtitle", ""))
	if play_button:
		play_button.text = "Continue" if String(resolution.get("action", "")) == "level" else "Level Select"


func _refresh_level_select_state() -> void:
	var service := _get_save_service()
	if total_stars_label:
		total_stars_label.text = "Stars: %d / %d" % [service.get_total_stars(), MAX_STARS]
	for i in LevelRegistryScript.get_level_ids().size():
		var level_id := LevelRegistryScript.get_level_ids()[i]
		var button := level_card_buttons.get(level_id) as Button
		if not button:
			continue
		var definition := LevelRegistryScript.load_definition(level_id)
		var unlocked: bool = service.is_level_unlocked(level_id)
		var completed: bool = service.is_level_completed(level_id)
		var stars: int = service.get_best_stars(level_id)
		var fewest: int = service.get_fewest_shots(level_id)
		var best_text := "--" if fewest < 0 else str(fewest)
		var state_text := "Complete" if completed else ("Unlocked" if unlocked else "Locked")
		var requirement := ""
		if not unlocked and i > 0:
			requirement = "\nUnlock: complete Level %02d" % i
		button.disabled = not unlocked
		button.text = "%02d  %s\n%s  |  %s\nStars: %d/3  Par: %d  Best: %s%s" % [
			i + 1,
			definition.display_name,
			_mechanic_label(definition.mechanic_id),
			state_text,
			stars,
			definition.par_shots,
			best_text,
			requirement,
		]


func _refresh_level_grid_columns() -> void:
	if not level_grid:
		return
	var margins := _safe_area_margins()
	var width := (
		get_viewport().get_visible_rect().size.x
		- float(margins.get("left", SAFE_MARGIN))
		- float(margins.get("right", SAFE_MARGIN))
	)
	if width >= 1100.0:
		level_grid.columns = 5
	elif width >= 780.0:
		level_grid.columns = 3
	else:
		level_grid.columns = 2


func _add_volume_setting(parent: VBoxContainer, title: String, setting_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(170.0, 48.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = float(_get_save_service().get_setting_value(setting_name, 1.0))
	slider.custom_minimum_size = Vector2(280.0, 48.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(58.0, 48.0)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)

	settings_widgets[setting_name] = {"slider": slider, "label": value_label}
	slider.value_changed.connect(func(value: float) -> void: set_setting_value(setting_name, value))


func _add_toggle_setting(parent: VBoxContainer, title: String, setting_name: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.custom_minimum_size = Vector2(420.0, 52.0)
	toggle.button_pressed = bool(_get_save_service().get_setting_value(setting_name, false))
	parent.add_child(toggle)
	settings_widgets[setting_name] = {"toggle": toggle}
	toggle.toggled.connect(func(value: bool) -> void: set_setting_value(setting_name, value))


func _add_quality_setting(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = "Quality"
	label.custom_minimum_size = Vector2(170.0, 48.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(280.0, 52.0)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var values := ["auto", "low", "medium", "high"]
	var display_names := ["Auto", "Low", "Medium", "High"]
	var selected_value := String(_get_save_service().get_setting_value("quality_tier", "auto"))
	var selected_index := 0
	for i in values.size():
		option.add_item(display_names[i], i)
		if values[i] == selected_value:
			selected_index = i
	option.select(selected_index)
	row.add_child(option)
	settings_widgets["quality_tier"] = {"option": option, "values": values}
	option.item_selected.connect(func(index: int) -> void:
		set_setting_value("quality_tier", values[index])
	)


func _refresh_settings_labels() -> void:
	for setting_name in settings_widgets.keys():
		var widgets: Dictionary = settings_widgets[setting_name]
		if widgets.has("slider") and widgets.has("label"):
			var slider := widgets.slider as HSlider
			var label := widgets.label as Label
			label.text = "%d%%" % roundi(slider.value * 100.0)
		elif widgets.has("option") and widgets.has("values"):
			var option := widgets.option as OptionButton
			var values := widgets.values as Array
			var selected_value := String(_get_save_service().get_setting_value(String(setting_name), "auto"))
			var selected_index := values.find(selected_value)
			if option and selected_index >= 0:
				option.select(selected_index)


func _apply_saved_settings() -> void:
	var service := _get_save_service()
	_apply_bus_volume("Master", float(service.get_setting_value("master_volume", 1.0)))
	_apply_bus_volume("Music", float(service.get_setting_value("music_volume", 1.0)))
	_apply_bus_volume("SFX", float(service.get_setting_value("sfx_volume", 1.0)))
	_apply_bus_volume("UI", float(service.get_setting_value("sfx_volume", 1.0)))
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service and audio_service.has_method("apply_settings_from_save"):
		audio_service.call("apply_settings_from_save", service)
	var haptics_service := get_node_or_null("/root/HapticsService")
	if haptics_service and haptics_service.has_method("apply_settings_from_save"):
		haptics_service.call("apply_settings_from_save", service)
	var monetization_service := _get_monetization_service()
	if monetization_service and monetization_service.has_method("apply_config_from_save"):
		monetization_service.call("apply_config_from_save", service)
	var mobile_runtime := _get_mobile_runtime_service()
	if mobile_runtime:
		if mobile_runtime.has_method("apply_quality_from_save"):
			mobile_runtime.call("apply_quality_from_save", service)
		if mobile_runtime.has_method("apply_release_configuration"):
			mobile_runtime.call("apply_release_configuration", monetization_service)
	_apply_developer_debug_to_level()
	_apply_presentation_settings_to_level()
	_apply_quality_settings_to_level()


func _apply_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var linear := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, -80.0 if linear <= 0.001 else linear_to_db(linear))


func _apply_developer_debug_to_level() -> void:
	if not current_level:
		return
	var enabled := (
		bool(_get_save_service().get_setting_value("developer_debug", false))
		and _development_controls_allowed()
	)
	current_level.set("developer_debug_enabled", enabled)
	if current_level.has_method("_update_debug_ui"):
		current_level.call("_update_debug_ui")


func _apply_presentation_settings_to_level() -> void:
	if not current_level:
		return
	if current_level.has_method("_apply_presentation_settings"):
		current_level.call("_apply_presentation_settings")


func _apply_quality_settings_to_level() -> void:
	if not current_level:
		return
	var mobile_runtime := _get_mobile_runtime_service()
	if mobile_runtime and mobile_runtime.has_method("apply_quality_to_node"):
		mobile_runtime.call("apply_quality_to_node", current_level)


func _set_status(message: String) -> void:
	last_status_message = message
	if status_label:
		status_label.text = message


func _play_menu_music() -> void:
	if _is_headless_run():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service and audio_service.has_method("play_music"):
		audio_service.call("play_music", "music_menu_loop")


func _play_gameplay_music(level_id: String) -> void:
	if _is_headless_run():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if not audio_service or not audio_service.has_method("play_music"):
		return
	var music_id := "music_final_loop" if level_id == "level_10" else "music_gameplay_loop"
	audio_service.call("play_music", music_id)


func _play_sfx(sound_id: String, volume_scale: float = 1.0) -> void:
	if _is_headless_run():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service and audio_service.has_method("play_sfx"):
		audio_service.call("play_sfx", sound_id, volume_scale)


func _play_ui_feedback(
	sound_id: String = "ui_tap",
	haptic_event: String = "ui_tap",
	haptic_strength: float = 0.55
) -> void:
	if _is_headless_run():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service and audio_service.has_method("play_ui"):
		audio_service.call("play_ui", sound_id)
	var haptics_service := get_node_or_null("/root/HapticsService")
	if haptics_service and haptics_service.has_method("emit_event"):
		haptics_service.call("emit_event", haptic_event, haptic_strength)


func _is_headless_run() -> bool:
	return DisplayServer.get_name() == "headless"


func _build_level_card(level_id: String, index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(220.0, 132.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var id_copy := level_id
	button.pressed.connect(func() -> void: request_level_launch(id_copy))
	return button


func _mechanic_label(mechanic_id: String) -> String:
	var labels := {
		"open_range": "Open Shot",
		"timed_gate": "Timing",
		"precision_gap": "Precision",
		"curve_blocker": "Curve",
		"elevation_barrier": "Lift",
		"low_road": "Low Shot",
		"rotating_gate": "Rotation",
		"bank_shot": "Bank",
		"double_timing": "Double Timing",
		"combo_challenge": "Finale",
	}
	return String(labels.get(mechanic_id, mechanic_id.capitalize()))


func _format_cosmetic_unlock_text(cosmetic_ids: Array[String]) -> String:
	var lines: Array[String] = []
	lines.append("New Cosmetic Unlocked" if cosmetic_ids.size() == 1 else "New Cosmetics Unlocked")
	for cosmetic_id in cosmetic_ids:
		var definition := CosmeticRegistryScript.get_definition(cosmetic_id)
		if definition.is_empty():
			continue
		lines.append(
			"%s - %s" % [
				String(definition.get("display_name", cosmetic_id)),
				CosmeticRegistryScript.get_category_display_name(
					String(definition.get("category", ""))
				),
			]
		)
	return "\n".join(lines)


func _product_display_name(product_id: String) -> String:
	match product_id:
		PRODUCT_REMOVE_ADS:
			return "Remove Ads"
		PRODUCT_STARTER_PACK:
			return "Starter Pack"
		"restore":
			return "Restore"
		_:
			return product_id


func _friendly_monetization_reason(reason: String) -> String:
	match reason:
		"cancelled":
			return "Cancelled."
		"failed":
			return "Request failed. Please try again."
		"unavailable", "rewarded ad unavailable", "purchases unavailable":
			return "Unavailable offline or in this build."
		"already owned":
			return "Already owned."
		"rewarded ad already running", "purchase already running":
			return "Already in progress."
		_:
			return reason if not reason.is_empty() else "Unavailable."


func _store_note_text() -> String:
	if _development_controls_allowed():
		return "Development build: purchases are simulated. Core levels stay free and offline."
	return "Purchases are unavailable in this offline build. Core levels stay free and playable."


func _development_controls_allowed() -> bool:
	var mobile_runtime := _get_mobile_runtime_service()
	if mobile_runtime and mobile_runtime.has_method("allow_development_controls"):
		return bool(mobile_runtime.call("allow_development_controls"))
	return OS.is_debug_build()


func _new_screen(node_name: String) -> Control:
	var screen := Control.new()
	screen.name = node_name
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	return screen


func _new_margin_container() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_to_group(SAFE_AREA_GROUP)
	_apply_safe_area_to_margin(margin)
	return margin


func _safe_area_margins() -> Dictionary:
	var mobile_runtime := _get_mobile_runtime_service()
	if mobile_runtime and mobile_runtime.has_method("get_safe_area_margins"):
		return mobile_runtime.call("get_safe_area_margins", float(SAFE_MARGIN)) as Dictionary
	return {
		"left": float(SAFE_MARGIN),
		"top": float(SAFE_MARGIN),
		"right": float(SAFE_MARGIN),
		"bottom": float(SAFE_MARGIN),
	}


func _apply_safe_area_to_margin(margin: MarginContainer) -> void:
	if not margin:
		return
	var margins := _safe_area_margins()
	margin.add_theme_constant_override("margin_left", roundi(float(margins.get("left", SAFE_MARGIN))))
	margin.add_theme_constant_override("margin_top", roundi(float(margins.get("top", SAFE_MARGIN))))
	margin.add_theme_constant_override("margin_right", roundi(float(margins.get("right", SAFE_MARGIN))))
	margin.add_theme_constant_override("margin_bottom", roundi(float(margins.get("bottom", SAFE_MARGIN))))


func _refresh_safe_area_layout() -> void:
	if screen_root:
		for node in screen_root.find_children("*", "MarginContainer", true, false):
			var margin := node as MarginContainer
			if margin and margin.is_in_group(SAFE_AREA_GROUP):
				_apply_safe_area_to_margin(margin)
	if gameplay_overlay_root:
		for node in gameplay_overlay_root.find_children("*", "MarginContainer", true, false):
			var margin := node as MarginContainer
			if margin and margin.is_in_group(SAFE_AREA_GROUP):
				_apply_safe_area_to_margin(margin)
	_position_gameplay_pause_button()
	_apply_safe_area_to_level()


func _apply_safe_area_to_level() -> void:
	if current_level and current_level.has_method("apply_safe_area_margins"):
		current_level.call("apply_safe_area_margins", _safe_area_margins())


func _position_gameplay_pause_button() -> void:
	if not gameplay_pause_button:
		return
	var margins := _safe_area_margins()
	gameplay_pause_button.offset_left = -156.0 - float(margins.get("right", SAFE_MARGIN))
	gameplay_pause_button.offset_top = 18.0 + float(margins.get("top", SAFE_MARGIN))
	gameplay_pause_button.offset_right = -18.0 - float(margins.get("right", SAFE_MARGIN))
	gameplay_pause_button.offset_bottom = 66.0 + float(margins.get("top", SAFE_MARGIN))


func _position_bottom_right_label(label: Control) -> void:
	if not label:
		return
	var margins := _safe_area_margins()
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = -(16.0 + float(margins.get("right", SAFE_MARGIN)))
	label.offset_bottom = -(10.0 + float(margins.get("bottom", SAFE_MARGIN)))


func _new_flat_backdrop() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.035, 0.07, 0.105, 1.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _new_menu_button(text_value: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(360.0, 54.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 22 if primary else 20)
	_connect_button_feedback(button, "ui_confirm" if primary else "ui_tap")
	return button


func _new_small_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = TOUCH_MINIMUM
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	_connect_button_feedback(button, "ui_tap")
	return button


func _connect_button_feedback(button: Button, sound_id: String) -> void:
	button.pressed.connect(func() -> void:
		_play_ui_feedback(sound_id)
		_animate_button_press(button)
	)


func _new_modal_overlay(node_name: String) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	return overlay


func _animate_screen_entrance(screen: Control) -> void:
	if _motion_reduced_for_ui() or not screen:
		return
	screen.modulate.a = 0.0
	var tween := create_tween()
	_track_ui_tween(tween)
	tween.tween_property(screen, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _active_ui_tween_finished(tween))
	_animate_buttons_in(screen)


func _animate_modal_entrance(overlay: Control) -> void:
	if _motion_reduced_for_ui() or not overlay:
		return
	overlay.modulate.a = 0.0
	var tween := create_tween()
	_track_ui_tween(tween)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _active_ui_tween_finished(tween))
	var panel := _first_panel_child(overlay)
	if panel:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.96, 0.96)
		var panel_tween := create_tween()
		_track_ui_tween(panel_tween)
		panel_tween.tween_property(panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		panel_tween.tween_callback(func() -> void: _active_ui_tween_finished(panel_tween))


func _animate_result_reveal(box: VBoxContainer) -> void:
	if _motion_reduced_for_ui() or not box:
		return
	var delay := 0.0
	for child in box.get_children():
		var control := child as Control
		if not control:
			continue
		control.modulate.a = 0.0
		var tween := create_tween()
		_track_ui_tween(tween)
		tween.tween_interval(delay)
		tween.tween_property(control, "modulate:a", 1.0, 0.12)
		tween.tween_callback(func() -> void: _active_ui_tween_finished(tween))
		delay += 0.045


func _animate_buttons_in(root: Node) -> void:
	if _motion_reduced_for_ui():
		return
	var buttons: Array[Button] = []
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button:
			buttons.append(button)
	for i in mini(buttons.size(), 12):
		var button := buttons[i]
		button.modulate.a = 0.0
		var tween := create_tween()
		_track_ui_tween(tween)
		tween.tween_interval(float(i) * 0.025)
		tween.tween_property(button, "modulate:a", 1.0, 0.12)
		tween.tween_callback(func() -> void: _active_ui_tween_finished(tween))


func _animate_button_press(button: Button) -> void:
	if _motion_reduced_for_ui() or not button:
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.98, 0.98)
	var tween := create_tween()
	_track_ui_tween(tween)
	tween.tween_property(button, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _active_ui_tween_finished(tween))


func _motion_reduced_for_ui() -> bool:
	return _is_headless_run() or bool(_get_save_service().get_setting_value("reduced_motion_enabled", false))


func _track_ui_tween(tween: Tween) -> void:
	if tween:
		active_ui_tweens.append(tween)


func _active_ui_tween_finished(tween: Tween) -> void:
	active_ui_tweens.erase(tween)


func _kill_ui_tweens() -> void:
	for tween in active_ui_tweens:
		if tween:
			tween.kill()
	active_ui_tweens.clear()


func _first_panel_child(root: Node) -> Control:
	for child in root.get_children():
		if child is PanelContainer:
			return child as Control
		var nested := _first_panel_child(child)
		if nested:
			return nested
	return null


func _new_center_panel(size: Vector2) -> PanelContainer:
	var margins := _safe_area_margins()
	var viewport_size := get_viewport().get_visible_rect().size
	var available_size := Vector2(
		maxf(320.0, viewport_size.x - float(margins.get("left", SAFE_MARGIN)) - float(margins.get("right", SAFE_MARGIN)) - 24.0),
		maxf(300.0, viewport_size.y - float(margins.get("top", SAFE_MARGIN)) - float(margins.get("bottom", SAFE_MARGIN)) - 24.0)
	)
	var panel_size := Vector2(minf(size.x, available_size.x), minf(size.y, available_size.y))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -panel_size.x * 0.5
	panel.offset_top = -panel_size.y * 0.5
	panel.offset_right = panel_size.x * 0.5
	panel.offset_bottom = panel_size.y * 0.5
	return panel


func _panel_vbox(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box


func _get_update_int(update: RefCounted, property_name: String, fallback: int) -> int:
	if not update:
		return fallback
	return int(update.get(property_name))


func _get_update_string(update: RefCounted, property_name: String, fallback: String) -> String:
	if not update:
		return fallback
	return String(update.get(property_name))


func _get_update_string_array(update: RefCounted, property_name: String) -> Array[String]:
	var result: Array[String] = []
	if not update:
		return result
	var value: Variant = update.get(property_name)
	if typeof(value) != TYPE_ARRAY:
		return result
	var values := value as Array
	for item in values:
		result.append(String(item))
	return result
