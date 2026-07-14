class_name NetboundLevelMarker
extends Button

var level_number: int = 1
var display_name: String = "Open Range"
var mechanic_name: String = "Open Shot"
var route_unlocked: bool = true
var route_completed: bool = false
var route_current: bool = false
var star_count: int = 0
var par_shots: int = 1
var best_shots: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(210.0, 138.0)
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


func configure_level(
	number: int,
	name_value: String,
	mechanic_value: String,
	unlocked: bool,
	completed: bool,
	current: bool,
	stars: int,
	par_value: int,
	best_value: int
) -> void:
	level_number = number
	display_name = name_value
	mechanic_name = mechanic_value
	route_unlocked = unlocked
	route_completed = completed
	route_current = current
	star_count = clampi(stars, 0, 3)
	par_shots = maxi(par_value, 0)
	best_shots = best_value
	disabled = not unlocked
	tooltip_text = _accessibility_text()
	queue_redraw()
	if get_parent():
		get_parent().queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var state_color := _state_color()
	var background := NetboundUITheme.PAPER
	if disabled:
		background = Color("bfd3d4")
	elif route_current:
		background = NetboundUITheme.SIGNAL
	elif route_completed:
		background = Color("e9ffef")
	elif is_pressed():
		background = Color("ffd07a")
	elif is_hovered() or has_focus():
		background = NetboundUITheme.CHALK

	var cut := 15.0
	var shape := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x - cut, 0.0),
		Vector2(size.x, cut),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y),
	])
	var shadow_shape := PackedVector2Array()
	for point in shape:
		shadow_shape.append(point + Vector2(0.0, 5.0))
	draw_colored_polygon(shadow_shape, Color(NetboundUITheme.INK, 0.28))
	draw_colored_polygon(shape, background)
	draw_polyline(PackedVector2Array([shape[0], shape[1], shape[2], shape[3], shape[4], shape[0]]), state_color, 3.0, true)
	draw_rect(Rect2(0.0, 0.0, 8.0, size.y), state_color)

	var number_color := NetboundUITheme.INK if route_unlocked else Color(NetboundUITheme.INK, 0.48)
	draw_string(
		NetboundUITheme.FONT_DISPLAY,
		Vector2(18.0, 49.0),
		"%02d" % level_number,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		36,
		number_color
	)
	var available_name_width := maxf(40.0, size.x - 94.0)
	var name_font_size := _fit_font_size(display_name.to_upper(), available_name_width, 16, 12)
	draw_string(
		NetboundUITheme.FONT_BOLD,
		Vector2(78.0, 31.0),
		display_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT,
		available_name_width,
		name_font_size,
		number_color
	)
	draw_string(
		NetboundUITheme.FONT_BODY,
		Vector2(78.0, 54.0),
		mechanic_name.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(40.0, size.x - 94.0),
		13,
		Color(NetboundUITheme.INK, 0.68) if route_unlocked else Color(NetboundUITheme.INK, 0.4)
	)

	_draw_target(Vector2(39.0, 84.0), state_color)
	for index in 3:
		var center := Vector2(78.0 + float(index) * 23.0, 86.0)
		_draw_star(center, 9.0, index < star_count)

	var best_text := "--" if best_shots < 0 else str(best_shots)
	draw_string(
		NetboundUITheme.FONT_BODY,
		Vector2(78.0, 124.0),
		"PAR %d   BEST %s" % [par_shots, best_text],
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(40.0, size.x - 92.0),
		14,
		Color(NetboundUITheme.INK, 0.66) if route_unlocked else Color(NetboundUITheme.INK, 0.4)
	)

	if not route_unlocked:
		_draw_lock(Vector2(size.x - 24.0, size.y - 23.0))
	elif route_current:
		draw_arc(Vector2(size.x - 22.0, size.y - 22.0), 9.0, 0.0, TAU, 20, NetboundUITheme.SIGNAL, 3.0, true)
		draw_circle(Vector2(size.x - 22.0, size.y - 22.0), 3.0, NetboundUITheme.SIGNAL)


func _state_color() -> Color:
	if route_completed:
		return NetboundUITheme.SUCCESS
	if route_current:
		return NetboundUITheme.SIGNAL
	if route_unlocked:
		return NetboundUITheme.CHALK
	return NetboundUITheme.LOCKED


func _draw_target(center: Vector2, color: Color) -> void:
	draw_arc(center, 13.0, 0.0, TAU, 24, Color(color, 0.95), 3.0, true)
	draw_arc(center, 6.0, 0.0, TAU, 18, Color(color, 0.62), 2.0, true)
	draw_circle(center + Vector2(4.0, -4.0), 3.0, color)


func _draw_star(center: Vector2, radius: float, filled: bool) -> void:
	var points := _star_points(center, radius)
	if filled:
		draw_colored_polygon(
			points,
			NetboundUITheme.INK if route_current else NetboundUITheme.SIGNAL
		)
	else:
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		draw_polyline(outline, Color(NetboundUITheme.INK, 0.38), 1.5, true)


func _draw_lock(center: Vector2) -> void:
	draw_arc(center + Vector2(0.0, -3.0), 6.0, PI, TAU, 12, NetboundUITheme.LOCKED, 2.0, true)
	draw_rect(Rect2(center.x - 7.0, center.y - 3.0, 14.0, 11.0), NetboundUITheme.LOCKED)


func _star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 10:
		var angle := -PI * 0.5 + float(index) * PI / 5.0
		var point_radius := radius if index % 2 == 0 else radius * 0.46
		points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
	return points


func _fit_font_size(text_value: String, max_width: float, preferred: int, minimum: int) -> int:
	for font_size in range(preferred, minimum - 1, -1):
		if NetboundUITheme.FONT_BOLD.get_string_size(
			text_value,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x <= max_width:
			return font_size
	return minimum


func _accessibility_text() -> String:
	var state := "complete" if route_completed else ("unlocked" if route_unlocked else "locked")
	var best := "no best" if best_shots < 0 else "best %d shots" % best_shots
	return "Level %d, %s, %s, %d stars, par %d, %s" % [
		level_number,
		display_name,
		state,
		star_count,
		par_shots,
		best,
	]
