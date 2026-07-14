class_name NetboundCosmeticChoiceButton
extends Button

var cosmetic_id: String = ""
var display_name: String = ""
var category: String = "ball"
var unlocked: bool = false
var selected: bool = false
var previewed: bool = false
var rarity: String = "common"
var price_text: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(200.0, 120.0)
	focus_mode = Control.FOCUS_ALL
	flat = true
	text = ""
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	resized.connect(queue_redraw)


func configure_choice(
	id_value: String,
	name_value: String,
	category_value: String,
	is_unlocked: bool,
	is_selected: bool,
	is_previewed: bool,
	rarity_value: String = "common",
	price_value: String = ""
) -> void:
	cosmetic_id = id_value
	display_name = name_value
	category = category_value
	unlocked = is_unlocked
	selected = is_selected
	previewed = is_previewed
	rarity = rarity_value
	price_text = price_value
	tooltip_text = "%s, %s" % [
		display_name,
		"equipped" if selected else ("unlocked" if unlocked else "locked"),
	]
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var fill := NetboundUITheme.PAPER if unlocked else Color("bfd3d4")
	if previewed:
		fill = NetboundUITheme.SIGNAL
	elif is_hovered() or has_focus():
		fill = NetboundUITheme.CHALK
	var edge := (
		NetboundUITheme.CORAL
		if previewed
		else (NetboundUITheme.SUCCESS if selected else NetboundUITheme.INK)
	)
	var cut := 13.0
	var shape := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x - cut, 0.0),
		Vector2(size.x, cut),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y),
	])
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(0.0, 5.0))
	draw_colored_polygon(shadow, Color(NetboundUITheme.INK, 0.25))
	draw_colored_polygon(shape, fill)
	draw_polyline(PackedVector2Array([shape[0], shape[1], shape[2], shape[3], shape[4], shape[0]]), edge, 3.0, true)
	if selected:
		draw_rect(Rect2(0.0, 0.0, 7.0, size.y), NetboundUITheme.SUCCESS)

	_draw_category_icon(Vector2(31.0, 37.0), edge)
	var text_color := NetboundUITheme.INK if unlocked else Color(NetboundUITheme.INK, 0.5)
	var available_width := maxf(40.0, size.x - 70.0)
	var label_text := display_name.to_upper()
	var label_size := _fit_font_size(label_text, available_width, 16, 12)
	draw_string(
		NetboundUITheme.FONT_BOLD,
		Vector2(58.0, 35.0),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		available_width,
		label_size,
		text_color
	)
	var state := "EQUIPPED" if selected else ("OWNED" if unlocked else rarity.to_upper())
	draw_string(
		NetboundUITheme.FONT_BODY,
		Vector2(58.0, 61.0),
		state,
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(40.0, size.x - 70.0),
		13,
		Color(NetboundUITheme.INK, 0.62)
	)
	if not price_text.is_empty() and not unlocked:
		draw_string(
			NetboundUITheme.FONT_BOLD,
			Vector2(58.0, 88.0),
			price_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			maxf(40.0, size.x - 70.0),
			12,
			NetboundUITheme.CORAL
		)
	if previewed:
		draw_arc(Vector2(size.x - 22.0, size.y - 22.0), 9.0, 0.0, TAU, 20, NetboundUITheme.CORAL, 3.0, true)
		draw_circle(Vector2(size.x - 22.0, size.y - 22.0), 3.0, NetboundUITheme.CORAL)


func _draw_category_icon(center: Vector2, color: Color) -> void:
	match category:
		"trail":
			draw_arc(center + Vector2(-4.0, 1.0), 15.0, -1.0, 1.2, 18, color, 4.0, true)
			draw_circle(center + Vector2(10.0, -10.0), 6.0, color)
		"goal_effect":
			draw_line(center + Vector2(-13.0, 13.0), center + Vector2(-13.0, -10.0), color, 4.0, true)
			draw_line(center + Vector2(13.0, 13.0), center + Vector2(13.0, -10.0), color, 4.0, true)
			draw_line(center + Vector2(-13.0, -10.0), center + Vector2(13.0, -10.0), color, 4.0, true)
			draw_circle(center + Vector2(0.0, 2.0), 5.0, NetboundUITheme.CORAL)
		_:
			draw_circle(center, 15.0, color)
			draw_arc(center, 7.0, 0.0, TAU, 16, fill_color(), 2.0, true)


func fill_color() -> Color:
	return NetboundUITheme.INK if previewed else NetboundUITheme.CORAL


func _fit_font_size(value: String, available_width: float, maximum: int, minimum: int) -> int:
	for font_size in range(maximum, minimum - 1, -1):
		if NetboundUITheme.FONT_BOLD.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= available_width:
			return font_size
	return minimum
