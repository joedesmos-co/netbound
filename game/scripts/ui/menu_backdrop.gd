class_name NetboundMenuBackdrop
extends Control

var animation_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()


func _draw() -> void:
	var rect := get_rect()
	var size := rect.size
	if size.x <= 1.0 or size.y <= 1.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.07, 0.105, 1.0), true)

	var horizon_y := size.y * 0.62
	var field_color := Color(0.05, 0.34, 0.18, 1.0)
	var lane_color := Color(0.12, 0.72, 0.42, 0.55)
	draw_rect(Rect2(Vector2(0.0, horizon_y), Vector2(size.x, size.y - horizon_y)), field_color, true)

	for i in 7:
		var t := float(i) / 6.0
		var x := lerpf(size.x * 0.08, size.x * 0.92, t)
		draw_line(Vector2(size.x * 0.5, horizon_y), Vector2(x, size.y), lane_color, 2.0)

	for i in 5:
		var y := lerpf(horizon_y + 18.0, size.y - 16.0, float(i) / 4.0)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(1.0, 1.0, 1.0, 0.08), 2.0)

	var goal_center := Vector2(size.x * 0.5, horizon_y - size.y * 0.08)
	var goal_width := minf(size.x * 0.34, 360.0)
	var goal_height := minf(size.y * 0.26, 160.0)
	var post_color := Color(0.95, 1.0, 1.0, 0.88)
	var left := goal_center.x - goal_width * 0.5
	var right := goal_center.x + goal_width * 0.5
	var top := goal_center.y - goal_height
	var bottom := goal_center.y
	draw_line(Vector2(left, bottom), Vector2(left, top), post_color, 7.0)
	draw_line(Vector2(right, bottom), Vector2(right, top), post_color, 7.0)
	draw_line(Vector2(left, top), Vector2(right, top), post_color, 7.0)
	for i in 6:
		var x := lerpf(left, right, float(i) / 5.0)
		draw_line(Vector2(x, top), Vector2(x, bottom), Color(1.0, 1.0, 1.0, 0.13), 1.0)

	var pulse := sin(animation_time * 1.6) * 0.5 + 0.5
	var ball_x := size.x * (0.24 + 0.08 * sin(animation_time * 0.9))
	var ball_y := horizon_y - 18.0 - pulse * 36.0
	var ball_pos := Vector2(ball_x, ball_y)
	var trail_start := ball_pos + Vector2(-120.0, 74.0)
	var mid := ball_pos + Vector2(-58.0, -34.0 - pulse * 20.0)
	draw_polyline(
		PackedVector2Array([trail_start, mid, ball_pos]),
		Color(1.0, 0.75, 0.12, 0.42),
		9.0,
		true
	)
	draw_circle(ball_pos, 17.0, Color(0.95, 0.98, 1.0, 1.0))
	draw_circle(ball_pos + Vector2(-4.0, -3.0), 5.0, Color(0.05, 0.07, 0.09, 0.9))
