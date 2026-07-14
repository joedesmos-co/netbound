class_name NetboundMenuBackdrop
extends Control

var animation_time: float = 0.0
var variant: String = "menu"
var reduced_motion: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not reduced_motion:
		animation_time += delta
		queue_redraw()


func _draw() -> void:
	var rect := get_rect()
	var size := rect.size
	if size.x <= 1.0 or size.y <= 1.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), NetboundUITheme.SKY, true)
	if variant == "route":
		_draw_route_field(size)
	elif variant == "secondary":
		_draw_secondary_field(size)
	else:
		_draw_menu_field(size)


func _draw_menu_field(size: Vector2) -> void:
	var horizon_y := size.y * 0.57
	_draw_cloud(Vector2(size.x * 0.11, size.y * 0.15), size.y * 0.055)
	_draw_cloud(Vector2(size.x * 0.48, size.y * 0.1), size.y * 0.04)
	draw_circle(Vector2(size.x * 0.72, size.y * 0.11), size.y * 0.055, NetboundUITheme.SIGNAL)
	draw_rect(
		Rect2(Vector2(0.0, horizon_y), Vector2(size.x, size.y - horizon_y)),
		NetboundUITheme.GRASS,
		true
	)
	for index in 6:
		var ratio := float(index) / 5.0
		var x := lerpf(size.x * 0.02, size.x * 0.98, ratio)
		draw_line(
			Vector2(size.x * 0.58, horizon_y),
			Vector2(x, size.y),
			Color(NetboundUITheme.CHALK, 0.28),
			3.0,
			true
		)
	for index in 4:
		var y := lerpf(horizon_y + 36.0, size.y - 20.0, float(index) / 3.0)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(NetboundUITheme.CHALK, 0.24), 3.0, true)

	var target_point := Vector2(size.x * 0.68, horizon_y - size.y * 0.08)

	var path := _quadratic_path(
		Vector2(size.x * 0.06, size.y * 0.9),
		Vector2(size.x * 0.47, size.y * 0.76),
		target_point,
		38
	)
	for index in path.size() - 1:
		if index % 3 != 2:
			draw_line(path[index], path[index + 1], Color(NetboundUITheme.CHALK, 0.92), 7.0, true)
	var ball_ratio := 0.7 if reduced_motion else fmod(animation_time * 0.16, 1.0)
	var ball_index := clampi(roundi(ball_ratio * float(path.size() - 1)), 0, path.size() - 1)
	var ball_position := path[ball_index]
	draw_circle(ball_position + Vector2(4.0, 6.0), 18.0, Color(NetboundUITheme.INK, 0.24))
	draw_circle(ball_position, 18.0, NetboundUITheme.CHALK)
	draw_circle(ball_position + Vector2(-4.0, -3.0), 5.0, NetboundUITheme.INK)
	var target := path[-1]
	draw_arc(target, 34.0, 0.0, TAU, 28, NetboundUITheme.CORAL, 7.0, true)
	draw_arc(target, 15.0, 0.0, TAU, 20, NetboundUITheme.CHALK, 4.0, true)


func _draw_route_field(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("65c7f3"), true)
	draw_rect(
		Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.16)),
		NetboundUITheme.INK,
		true
	)
	draw_rect(
		Rect2(Vector2(0.0, size.y * 0.16), Vector2(size.x, size.y * 0.84)),
		Color("42bd75"),
		true
	)
	var center := Vector2(size.x * 0.5, size.y * 0.54)
	draw_arc(center, minf(size.x, size.y) * 0.31, -2.7, 0.25, 64, Color(NetboundUITheme.CHALK, 0.32), 4.0, true)
	draw_arc(center, minf(size.x, size.y) * 0.22, 0.45, 3.4, 64, Color(NetboundUITheme.SIGNAL, 0.5), 7.0, true)
	for index in 5:
		var x := lerpf(size.x * 0.08, size.x * 0.92, float(index) / 4.0)
		draw_line(Vector2(x, size.y * 0.17), Vector2(x, size.y), Color(NetboundUITheme.CHALK, 0.18), 2.0, true)
	var target := Vector2(size.x * 0.87, size.y * 0.23)
	draw_arc(target, 54.0, 0.0, TAU, 32, Color(NetboundUITheme.CORAL, 0.72), 7.0, true)
	draw_arc(target, 24.0, 0.0, TAU, 24, Color(NetboundUITheme.CHALK, 0.8), 4.0, true)


func _draw_secondary_field(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), NetboundUITheme.SKY, true)
	var field_top := size.y * 0.44
	draw_rect(
		Rect2(Vector2(0.0, field_top), Vector2(size.x, size.y - field_top)),
		NetboundUITheme.GRASS,
		true
	)
	for index in 5:
		var x := lerpf(size.x * 0.04, size.x * 0.96, float(index) / 4.0)
		draw_line(
			Vector2(size.x * 0.5, field_top),
			Vector2(x, size.y),
			Color(NetboundUITheme.CHALK, 0.22),
			3.0,
			true
		)
	var target := Vector2(size.x * 0.86, size.y * 0.22)
	draw_arc(target, 72.0, 0.0, TAU, 36, Color(NetboundUITheme.CORAL, 0.52), 9.0, true)
	draw_arc(target, 30.0, 0.0, TAU, 28, Color(NetboundUITheme.CHALK, 0.84), 5.0, true)
	_draw_cloud(Vector2(size.x * 0.13, size.y * 0.16), size.y * 0.045)


func _draw_cloud(center: Vector2, radius: float) -> void:
	var cloud := Color(NetboundUITheme.CHALK, 0.78)
	draw_circle(center + Vector2(-radius * 0.75, radius * 0.18), radius * 0.62, cloud)
	draw_circle(center, radius * 0.86, cloud)
	draw_circle(center + Vector2(radius * 0.8, radius * 0.24), radius * 0.56, cloud)
	draw_rect(
		Rect2(center + Vector2(-radius * 1.25, radius * 0.18), Vector2(radius * 2.5, radius * 0.65)),
		cloud,
		true
	)


func _quadratic_path(start: Vector2, control: Vector2, end: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count:
		var t := float(index) / float(maxi(1, count - 1))
		var inverse := 1.0 - t
		points.append(
			inverse * inverse * start
			+ 2.0 * inverse * t * control
			+ t * t * end
		)
	return points
