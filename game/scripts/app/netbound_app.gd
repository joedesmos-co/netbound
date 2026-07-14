class_name NetboundApp
extends Node

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const MenuBackdropScript := preload("res://scripts/ui/menu_backdrop.gd")
const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const CosmeticPreviewScript := preload("res://scripts/cosmetics/cosmetic_preview.gd")

const APP_VERSION_LABEL := "Vertical Slice P6"
const MAX_STARS := 30
const SAFE_MARGIN := 28
const RESULT_REVEAL_DELAY := 0.35
const TOUCH_MINIMUM := Vector2(48.0, 48.0)
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
	_apply_saved_settings()
	_show_main_menu_internal()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and current_screen_name == "gameplay":
		show_pause_menu()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_navigation()


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
	elif current_screen_name in ["main_menu", "level_select", "cosmetics"]:
		previous_menu_screen = current_screen_name
	_show_settings_internal()
	return true


func show_cosmetics() -> bool:
	if not _begin_navigation():
		return false
	previous_menu_screen = current_screen_name if current_screen_name != "cosmetics" else "main_menu"
	_show_cosmetics_internal()
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
		return false
	if not _get_save_service().is_level_unlocked(level_id):
		_set_status("Complete earlier levels to unlock this one.")
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
	_apply_developer_debug_to_level()
	_build_gameplay_overlay()
	return true


func show_pause_menu() -> bool:
	if current_screen_name != "gameplay" or not current_level:
		return false
	if pause_overlay and pause_overlay.visible:
		return true
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
	build.offset_left = 0.0
	build.offset_top = 0.0
	build.offset_right = -16.0
	build.offset_bottom = -10.0
	screen.add_child(build)

	screen_root.add_child(screen)
	_refresh_main_menu_play_state()


func _show_level_select_internal() -> void:
	get_tree().paused = false
	current_screen_name = "level_select"
	_clear_screen()
	_clear_gameplay_overlay()
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


func _show_settings_internal() -> void:
	current_screen_name = "settings"
	_clear_screen()
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
	if OS.is_debug_build():
		_add_toggle_setting(outer, "Developer Debug", "developer_debug")

	var back_button := _new_menu_button("Back", true)
	back_button.pressed.connect(_return_from_submenu)
	outer.add_child(back_button)

	screen_root.add_child(screen)
	_refresh_settings_labels()


func _show_cosmetics_internal() -> void:
	current_screen_name = "cosmetics"
	_clear_screen()
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
		return
	if service.set_selected_cosmetic(current_cosmetic_category, previewed_cosmetic_id):
		cosmetic_status_label.text = "Equipped"
	else:
		cosmetic_status_label.text = "Unable to equip"
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
	if cosmetic_status_label:
		if selected:
			cosmetic_status_label.text = "Currently equipped"
		elif unlocked:
			cosmetic_status_label.text = "Unlocked"
		else:
			cosmetic_status_label.text = "Preview only"


func _build_gameplay_overlay() -> void:
	_clear_gameplay_overlay()
	var layer_control := Control.new()
	layer_control.name = "GameplayChrome"
	layer_control.process_mode = Node.PROCESS_MODE_ALWAYS
	layer_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_overlay_root.add_child(layer_control)

	var pause_button := _new_small_button("Pause")
	pause_button.name = "PauseButton"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -156.0
	pause_button.offset_top = 18.0
	pause_button.offset_right = -18.0
	pause_button.offset_bottom = 66.0
	pause_button.pressed.connect(show_pause_menu)
	layer_control.add_child(pause_button)


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
	result_next_button.pressed.connect(func() -> void: load_level(next_id))
	actions.add_child(result_next_button)

	var retry_button := _new_small_button("Retry")
	retry_button.pressed.connect(func() -> void: load_level(level_result.level_id))
	actions.add_child(retry_button)

	var select_button := _new_small_button("Level Select")
	select_button.pressed.connect(show_level_select)
	actions.add_child(select_button)

	var menu_button := _new_small_button("Main Menu")
	menu_button.pressed.connect(show_main_menu)
	actions.add_child(menu_button)

	result_overlay = overlay
	gameplay_overlay_root.add_child(result_overlay)


func _show_failure_result(level_result: LevelResult) -> void:
	_clear_result_overlay()
	current_screen_name = "result"
	var definition := LevelRegistryScript.load_definition(level_result.level_id)
	var overlay := _new_modal_overlay("FailureOverlay")
	var panel := _new_center_panel(Vector2(500.0, 420.0))
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


func _on_level_completed(level_result: LevelResult, progression_update: RefCounted) -> void:
	var expected_level := current_level
	await get_tree().create_timer(RESULT_REVEAL_DELAY, false, false, true).timeout
	if expected_level != current_level or not current_level:
		return
	_show_success_result(level_result, progression_update)


func _on_level_failed(level_result: LevelResult) -> void:
	_show_failure_result(level_result)


func _return_from_submenu() -> void:
	if previous_menu_screen == "level_select":
		show_level_select()
	elif previous_menu_screen == "pause":
		_show_pause_return()
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
	elif current_screen_name == "settings" or current_screen_name == "cosmetics":
		_return_from_submenu()
	elif current_screen_name == "level_select":
		show_main_menu()
	elif current_screen_name == "result":
		show_level_select()


func _leave_current_level() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_clear_gameplay_overlay()
	if current_level:
		if current_level.has_method("prepare_for_unload"):
			current_level.call("prepare_for_unload")
		current_level.queue_free()
	current_level = null
	current_level_id = ""


func _clear_screen() -> void:
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
	cosmetic_category_buttons.clear()
	cosmetic_card_buttons.clear()


func _clear_gameplay_overlay() -> void:
	gameplay_overlay_root.visible = true
	for child in gameplay_overlay_root.get_children():
		child.queue_free()
	pause_overlay = null
	result_overlay = null


func _clear_result_overlay() -> void:
	if result_overlay:
		result_overlay.queue_free()
		result_overlay = null


func _begin_navigation() -> bool:
	if navigation_in_progress:
		return false
	navigation_in_progress = true
	call_deferred("_release_navigation_lock")
	return true


func _release_navigation_lock() -> void:
	navigation_in_progress = false


func _get_save_service() -> Node:
	return get_node("/root/SaveService")


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
	var width := get_viewport().get_visible_rect().size.x
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


func _refresh_settings_labels() -> void:
	for setting_name in settings_widgets.keys():
		var widgets: Dictionary = settings_widgets[setting_name]
		if widgets.has("slider") and widgets.has("label"):
			var slider := widgets.slider as HSlider
			var label := widgets.label as Label
			label.text = "%d%%" % roundi(slider.value * 100.0)


func _apply_saved_settings() -> void:
	var service := _get_save_service()
	_apply_bus_volume("Master", float(service.get_setting_value("master_volume", 1.0)))
	_apply_bus_volume("Music", float(service.get_setting_value("music_volume", 1.0)))
	_apply_bus_volume("SFX", float(service.get_setting_value("sfx_volume", 1.0)))
	_apply_developer_debug_to_level()


func _apply_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var linear := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, -80.0 if linear <= 0.001 else linear_to_db(linear))


func _apply_developer_debug_to_level() -> void:
	if not current_level:
		return
	var enabled := bool(_get_save_service().get_setting_value("developer_debug", false))
	current_level.set("developer_debug_enabled", enabled)
	if current_level.has_method("_update_debug_ui"):
		current_level.call("_update_debug_ui")


func _set_status(message: String) -> void:
	last_status_message = message
	if status_label:
		status_label.text = message


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
	margin.add_theme_constant_override("margin_left", SAFE_MARGIN)
	margin.add_theme_constant_override("margin_top", SAFE_MARGIN)
	margin.add_theme_constant_override("margin_right", SAFE_MARGIN)
	margin.add_theme_constant_override("margin_bottom", SAFE_MARGIN)
	return margin


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
	return button


func _new_small_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = TOUCH_MINIMUM
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	return button


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


func _new_center_panel(size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
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
