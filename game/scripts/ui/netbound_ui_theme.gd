class_name NetboundUITheme
extends RefCounted

const FONT_BODY: FontFile = preload("res://assets/fonts/LiberationSans-Regular.ttf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/LiberationSans-Bold.ttf")
const FONT_DISPLAY: FontFile = preload("res://assets/fonts/LiberationSansNarrow-Bold.ttf")

const INK := Color("0b2942")
const FIELD_INK := Color("0f4f54")
const SURFACE := Color("174d68")
const SURFACE_HIGH := Color("216882")
const CHALK := Color("fff9e8")
const PAPER := Color("fff3d6")
const MUTED := Color("a9c2c8")
const SIGNAL := Color("ffd84a")
const SUCCESS := Color("43c878")
const FAILURE := Color("ff625f")
const LOCKED := Color("718a91")
const CURVE := Color("43d2e3")
const CORAL := Color("ff765e")
const SKY := Color("55b9ef")
const GRASS := Color("31bf72")

const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_6 := 24
const SPACE_8 := 32
const SPACE_12 := 48
const SPACE_16 := 64

static var _shared_theme: Theme


static func get_theme() -> Theme:
	if not _shared_theme:
		_shared_theme = _build_theme()
	return _shared_theme


static func style(
	background: Color,
	border: Color = Color.TRANSPARENT,
	border_width: int = 0,
	corner_radius: int = 2,
	content_margin := Vector2(18.0, 12.0)
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(corner_radius)
	box.content_margin_left = content_margin.x
	box.content_margin_right = content_margin.x
	box.content_margin_top = content_margin.y
	box.content_margin_bottom = content_margin.y
	return box


static func transparent_style(content_margin := Vector2(12.0, 8.0)) -> StyleBoxFlat:
	return style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, content_margin)


static func edge_style(
	background: Color,
	border: Color,
	left_width: int,
	right_width: int = 0,
	content_margin := Vector2(18.0, 12.0)
) -> StyleBoxFlat:
	var box := style(background, border, 0, 0, content_margin)
	box.border_width_left = left_width
	box.border_width_right = right_width
	return box


static func _build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT_BODY
	theme.default_font_size = 18

	theme.set_font("font", "Label", FONT_BODY)
	theme.set_font_size("font_size", "Label", 18)
	theme.set_color("font_color", "Label", CHALK)
	theme.set_color("font_shadow_color", "Label", Color.TRANSPARENT)

	_register_label_variations(theme)
	_register_button_variations(theme)
	_register_panel_variations(theme)
	_register_range_controls(theme)
	_register_misc_controls(theme)
	return theme


static func _register_label_variations(theme: Theme) -> void:
	_register_label(theme, "DisplayLabel", FONT_DISPLAY, 96, CHALK)
	_register_label(theme, "ScreenTitle", FONT_DISPLAY, 46, CHALK)
	_register_label(theme, "ResultTitle", FONT_DISPLAY, 72, CHALK)
	_register_label(theme, "SectionLabel", FONT_BOLD, 15, SIGNAL)
	_register_label(theme, "BodyLabel", FONT_BODY, 18, CHALK)
	_register_label(theme, "MetaLabel", FONT_BODY, 15, MUTED)
	_register_label(theme, "NumericLabel", FONT_DISPLAY, 28, CHALK)
	_register_label(theme, "SuccessLabel", FONT_BOLD, 17, SUCCESS)
	_register_label(theme, "FailureLabel", FONT_BOLD, 17, FAILURE)
	_register_label(theme, "LightResultTitle", FONT_DISPLAY, 78, INK)
	_register_label(theme, "LightSectionLabel", FONT_BOLD, 15, Color("b44732"))
	_register_label(theme, "LightBodyLabel", FONT_BODY, 18, INK)
	_register_label(theme, "LightMetaLabel", FONT_BODY, 15, Color("55707a"))
	_register_label(theme, "LightNumericLabel", FONT_DISPLAY, 28, INK)
	_register_label(theme, "LightSuccessLabel", FONT_BOLD, 17, Color("188d4a"))
	_register_label(theme, "LightScreenTitle", FONT_DISPLAY, 48, INK)


static func _register_label(
	theme: Theme,
	variation: StringName,
	font: Font,
	font_size: int,
	color: Color
) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, font_size)
	theme.set_color("font_color", variation, color)


static func _register_button_variations(theme: Theme) -> void:
	theme.set_font("font", "Button", FONT_BOLD)
	theme.set_font_size("font_size", "Button", 18)
	theme.set_color("font_color", "Button", CHALK)
	theme.set_color("font_hover_color", "Button", CHALK)
	theme.set_color("font_pressed_color", "Button", CHALK)
	theme.set_color("font_focus_color", "Button", CHALK)
	theme.set_color("font_disabled_color", "Button", LOCKED)
	theme.set_stylebox("normal", "Button", style(SURFACE, Color(CHALK, 0.28), 1))
	theme.set_stylebox("hover", "Button", style(SURFACE_HIGH, CHALK, 1))
	theme.set_stylebox("pressed", "Button", style(FIELD_INK, SIGNAL, 2))
	theme.set_stylebox("focus", "Button", style(SURFACE, SIGNAL, 2))
	theme.set_stylebox("disabled", "Button", style(Color(SURFACE, 0.58), Color(LOCKED, 0.48), 1))

	_register_button(
		theme,
		"PrimaryButton",
		24,
		INK,
		style(SIGNAL, SIGNAL, 2, 2, Vector2(22.0, 15.0)),
		style(Color("ffe35b"), CHALK, 2, 2, Vector2(22.0, 15.0)),
		style(Color("c7aa1f"), INK, 2, 2, Vector2(22.0, 15.0))
	)
	_register_button(
		theme,
		"SecondaryButton",
		18,
		INK,
		style(PAPER, INK, 2, 3),
		style(CHALK, CORAL, 2, 3),
		style(CURVE, INK, 2, 3)
	)
	_register_button(
		theme,
		"QuietButton",
		16,
		MUTED,
		transparent_style(),
		style(Color(CHALK, 0.06), Color(CHALK, 0.25), 1, 0, Vector2(12.0, 8.0)),
		style(Color(SIGNAL, 0.12), SIGNAL, 1, 0, Vector2(12.0, 8.0))
	)
	_register_button(
		theme,
		"TabButton",
		16,
		MUTED,
		style(Color.TRANSPARENT, Color(MUTED, 0.32), 0, 0),
		style(Color(CHALK, 0.06), Color(CHALK, 0.45), 1, 0),
		style(SIGNAL, SIGNAL, 2, 0)
	)
	theme.set_color("font_pressed_color", "TabButton", INK)
	theme.set_color("font_focus_color", "TabButton", INK)
	theme.set_color("font_color", "TabButton", Color(INK, 0.72))
	theme.set_color("font_hover_color", "TabButton", INK)
	_register_button(
		theme,
		"DangerButton",
		18,
		CHALK,
		style(Color(FAILURE, 0.12), FAILURE, 1),
		style(Color(FAILURE, 0.22), FAILURE, 2),
		style(Color(FAILURE, 0.32), CHALK, 2)
	)
	_register_button(
		theme,
		"HudButton",
		15,
		CHALK,
		style(Color(INK, 0.78), Color(CHALK, 0.24), 1, 1, Vector2(14.0, 9.0)),
		style(Color(SURFACE_HIGH, 0.92), CHALK, 1, 1, Vector2(14.0, 9.0)),
		style(Color(SIGNAL, 0.92), SIGNAL, 2, 1, Vector2(14.0, 9.0))
	)
	_register_button(
		theme,
		"LightQuietButton",
		16,
		INK,
		transparent_style(),
		style(Color(CORAL, 0.12), CORAL, 1, 1, Vector2(12.0, 8.0)),
		style(SIGNAL, INK, 2, 1, Vector2(12.0, 8.0))
	)


static func _register_button(
	theme: Theme,
	variation: StringName,
	font_size: int,
	font_color: Color,
	normal: StyleBox,
	hover: StyleBox,
	pressed: StyleBox
) -> void:
	theme.set_type_variation(variation, "Button")
	theme.set_font("font", variation, FONT_BOLD)
	theme.set_font_size("font_size", variation, font_size)
	theme.set_color("font_color", variation, font_color)
	theme.set_color("font_hover_color", variation, font_color)
	theme.set_color("font_pressed_color", variation, font_color)
	theme.set_color("font_focus_color", variation, font_color)
	theme.set_color("font_disabled_color", variation, Color(LOCKED, 0.9))
	theme.set_stylebox("normal", variation, normal)
	theme.set_stylebox("hover", variation, hover)
	theme.set_stylebox("pressed", variation, pressed)
	theme.set_stylebox("focus", variation, style(Color.TRANSPARENT, SIGNAL, 2, 2))
	theme.set_stylebox("disabled", variation, style(Color(SURFACE, 0.42), Color(LOCKED, 0.42), 1))


static func _register_panel_variations(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", style(SURFACE, Color(CHALK, 0.18), 1, 2))
	theme.set_type_variation("RailPanel", "PanelContainer")
	theme.set_stylebox(
		"panel",
		"RailPanel",
		edge_style(Color(INK, 0.95), CORAL, 7, 0, Vector2(0.0, 0.0))
	)
	theme.set_type_variation("ResultPanel", "PanelContainer")
	theme.set_stylebox("panel", "ResultPanel", style(Color(INK, 0.96), SIGNAL, 0, 0))
	theme.set_type_variation("SuccessPanel", "PanelContainer")
	theme.set_stylebox(
		"panel",
		"SuccessPanel",
		edge_style(PAPER, SUCCESS, 8, 0, Vector2(0.0, 0.0))
	)
	theme.set_type_variation("FailurePanel", "PanelContainer")
	theme.set_stylebox(
		"panel",
		"FailurePanel",
		edge_style(PAPER, FAILURE, 8, 0, Vector2(0.0, 0.0))
	)
	theme.set_type_variation("HudBadge", "PanelContainer")
	theme.set_stylebox("panel", "HudBadge", style(Color(INK, 0.82), Color(CHALK, 0.22), 1, 1, Vector2(18.0, 8.0)))
	theme.set_type_variation("PreviewStage", "PanelContainer")
	theme.set_stylebox("panel", "PreviewStage", style(Color(SURFACE, 0.95), CHALK, 3, 3, Vector2(0.0, 0.0)))
	theme.set_type_variation("LockerDetailPanel", "PanelContainer")
	theme.set_stylebox("panel", "LockerDetailPanel", edge_style(PAPER, CORAL, 7, 0, Vector2(0.0, 0.0)))
	theme.set_type_variation("StoreOfferPanel", "PanelContainer")
	theme.set_stylebox("panel", "StoreOfferPanel", style(PAPER, INK, 3, 3, Vector2(0.0, 0.0)))
	theme.set_type_variation("StoreOfferAccentPanel", "PanelContainer")
	theme.set_stylebox("panel", "StoreOfferAccentPanel", edge_style(PAPER, CORAL, 8, 0, Vector2(0.0, 0.0)))
	theme.set_type_variation("InfoBand", "PanelContainer")
	theme.set_stylebox("panel", "InfoBand", style(Color(INK, 0.94), Color(CHALK, 0.2), 1, 1, Vector2(0.0, 0.0)))
	theme.set_type_variation("SettingsPanel", "PanelContainer")
	theme.set_stylebox("panel", "SettingsPanel", style(PAPER, INK, 3, 3, Vector2(0.0, 0.0)))
	theme.set_type_variation("SettingsAccentPanel", "PanelContainer")
	theme.set_stylebox("panel", "SettingsAccentPanel", edge_style(PAPER, CORAL, 8, 0, Vector2(0.0, 0.0)))


static func _register_range_controls(theme: Theme) -> void:
	var slider := style(Color(MUTED, 0.35), Color.TRANSPARENT, 0, 1, Vector2.ZERO)
	slider.content_margin_top = 4.0
	slider.content_margin_bottom = 4.0
	var grabber_area := style(SIGNAL, Color.TRANSPARENT, 0, 1, Vector2.ZERO)
	grabber_area.content_margin_top = 4.0
	grabber_area.content_margin_bottom = 4.0
	theme.set_stylebox("slider", "HSlider", slider)
	theme.set_stylebox("grabber_area", "HSlider", grabber_area)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabber_area)

	var progress_background := style(Color(INK, 0.82), Color(CHALK, 0.18), 1, 1, Vector2.ZERO)
	var progress_fill := style(SIGNAL, SIGNAL, 0, 1, Vector2.ZERO)
	theme.set_stylebox("background", "ProgressBar", progress_background)
	theme.set_stylebox("fill", "ProgressBar", progress_fill)


static func _register_misc_controls(theme: Theme) -> void:
	theme.set_font("font", "CheckButton", FONT_BOLD)
	theme.set_font_size("font_size", "CheckButton", 17)
	theme.set_color("font_color", "CheckButton", CHALK)
	theme.set_color("font_pressed_color", "CheckButton", CHALK)
	theme.set_type_variation("LightCheckButton", "CheckButton")
	theme.set_font("font", "LightCheckButton", FONT_BOLD)
	theme.set_font_size("font_size", "LightCheckButton", 17)
	theme.set_color("font_color", "LightCheckButton", INK)
	theme.set_color("font_hover_color", "LightCheckButton", INK)
	theme.set_color("font_pressed_color", "LightCheckButton", INK)
	theme.set_color("font_focus_color", "LightCheckButton", INK)
	theme.set_stylebox("normal", "LightCheckButton", transparent_style(Vector2(4.0, 6.0)))
	theme.set_stylebox("hover", "LightCheckButton", style(Color(CORAL, 0.1), CORAL, 1, 1, Vector2(4.0, 6.0)))
	theme.set_stylebox("pressed", "LightCheckButton", transparent_style(Vector2(4.0, 6.0)))
	theme.set_stylebox("focus", "LightCheckButton", style(Color.TRANSPARENT, SIGNAL, 2, 1, Vector2(4.0, 6.0)))
	theme.set_font("font", "OptionButton", FONT_BOLD)
	theme.set_font_size("font_size", "OptionButton", 17)
	theme.set_color("font_color", "OptionButton", CHALK)
	theme.set_stylebox("normal", "OptionButton", style(SURFACE, Color(MUTED, 0.5), 1))
	theme.set_stylebox("hover", "OptionButton", style(SURFACE_HIGH, CHALK, 1))
	theme.set_stylebox("pressed", "OptionButton", style(FIELD_INK, SIGNAL, 2))
	theme.set_stylebox("focus", "OptionButton", style(SURFACE, SIGNAL, 2))

	var separator := StyleBoxLine.new()
	separator.color = Color(CHALK, 0.16)
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)
	theme.set_stylebox("separator", "VSeparator", separator)

	theme.set_color("font_color", "TooltipLabel", CHALK)
	theme.set_stylebox("panel", "TooltipPanel", style(SURFACE, CHALK, 1, 1, Vector2(10.0, 6.0)))
