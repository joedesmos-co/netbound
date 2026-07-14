class_name SwipeOverlay
extends Control

var swipe_points: PackedVector2Array = []
var ball_screen_position: Vector2 = Vector2.ZERO
var shot_direction_screen: Vector2 = Vector2.ZERO
var curve_sign: float = 0.0
var curve_strength: float = 0.0
var is_active: bool = false


func set_swipe_visuals(
	points: PackedVector2Array,
	ball_screen: Vector2,
	shot_dir_screen: Vector2,
	signed_curve: float,
	strength: float,
	active: bool
) -> void:
	swipe_points = points
	ball_screen_position = ball_screen
	shot_direction_screen = shot_dir_screen
	curve_sign = signed_curve
	curve_strength = strength
	is_active = active
	queue_redraw()


func clear_visuals() -> void:
	swipe_points = PackedVector2Array()
	is_active = false
	queue_redraw()


func _draw() -> void:
	if not is_active:
		return

	if swipe_points.size() >= 2:
		for index in range(1, swipe_points.size()):
			draw_line(swipe_points[index - 1], swipe_points[index], Color(0.2, 0.95, 1.0, 0.95), 5.0)

	if shot_direction_screen.length() > 4.0:
		var arrow_end := ball_screen_position + shot_direction_screen
		draw_line(ball_screen_position, arrow_end, Color(1.0, 0.88, 0.15, 0.95), 6.0)
		_draw_arrow_head(arrow_end, shot_direction_screen.normalized(), Color(1.0, 0.88, 0.15, 0.95))

	if curve_strength > 0.02 and shot_direction_screen.length() > 4.0:
		var curve_color := Color(1.0, 0.35, 0.35, 0.9) if curve_sign < 0.0 else Color(0.35, 1.0, 0.45, 0.9)
		var shot_dir := shot_direction_screen.normalized()
		var curve_perp := Vector2(-shot_dir.y, shot_dir.x) * curve_sign
		var mid := ball_screen_position + (shot_direction_screen * 0.55)
		var control := mid + (curve_perp * curve_strength * 80.0)
		var previous := ball_screen_position
		for step in range(1, 9):
			var t := float(step) / 8.0
			var point := _quadratic_bezier(ball_screen_position, control, ball_screen_position + shot_direction_screen, t)
			draw_line(previous, point, curve_color, 4.0)
			previous = point


func _draw_arrow_head(tip: Vector2, direction: Vector2, color: Color) -> void:
	var back := direction * 16.0
	var left := Vector2(-direction.y, direction.x) * 8.0
	draw_colored_polygon(PackedVector2Array([tip, tip - back + left, tip - back - left]), color)


func _quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var inverse := 1.0 - t
	return (
		(inverse * inverse * start)
		+ (2.0 * inverse * t * control)
		+ (t * t * end)
	)
