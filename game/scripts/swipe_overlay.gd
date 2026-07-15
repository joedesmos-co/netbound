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
	if not is_active or swipe_points.size() < 2:
		return

	var power_ratio := clampf((shot_direction_screen.length() - 80.0) / 140.0, 0.0, 1.0)
	var stroke_width := lerpf(4.5, 8.5, power_ratio)
	var stroke_color := Color(0.32, 0.94, 1.0, 0.96).lerp(
		Color(1.0, 0.84, 0.18, 0.98),
		power_ratio
	)
	var previous := ball_screen_position
	for index in range(1, swipe_points.size()):
		var point := swipe_points[index]
		draw_line(previous, point, Color(0.04, 0.16, 0.24, 0.72), stroke_width + 3.0, true)
		draw_line(previous, point, stroke_color, stroke_width, true)
		previous = point
