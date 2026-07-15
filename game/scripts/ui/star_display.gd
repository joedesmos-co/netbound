class_name NetboundStarDisplay
extends Control

var stars_earned: int = 0
var revealed_stars: int = 0
var _reveal_tween: Tween


func _ready() -> void:
	custom_minimum_size = Vector2(280.0, 82.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_stars(value: int, reveal_immediately: bool = true) -> void:
	stars_earned = clampi(value, 0, 3)
	if reveal_immediately:
		revealed_stars = stars_earned
	queue_redraw()


func play_reveal(reduced_motion: bool) -> void:
	if _reveal_tween:
		_reveal_tween.kill()
	if reduced_motion:
		revealed_stars = stars_earned
		queue_redraw()
		return
	revealed_stars = 0
	queue_redraw()
	_reveal_tween = create_tween()
	for index in stars_earned:
		_reveal_tween.tween_interval(0.08 if index == 0 else 0.06)
		_reveal_tween.tween_callback(func() -> void:
			revealed_stars = mini(stars_earned, revealed_stars + 1)
			queue_redraw()
		)


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var center_y := size.y * 0.5
	var spacing := minf(86.0, size.x / 3.3)
	var start_x := size.x * 0.5 - spacing
	draw_line(Vector2(start_x - 30.0, center_y), Vector2(start_x + spacing * 2.0 + 30.0, center_y), Color(NetboundUITheme.INK, 0.16), 3.0, true)
	for index in 3:
		var center := Vector2(start_x + float(index) * spacing, center_y)
		var points := _star_points(center, 29.0)
		if index < revealed_stars:
			draw_colored_polygon(points, NetboundUITheme.SIGNAL)
			draw_circle(center + Vector2(8.0, -8.0), 4.0, NetboundUITheme.SUCCESS)
		else:
			var outline := PackedVector2Array(points)
			outline.append(points[0])
			draw_polyline(outline, Color(NetboundUITheme.INK, 0.34), 3.0, true)


func _star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 10:
		var angle := -PI * 0.5 + float(index) * PI / 5.0
		var point_radius := radius if index % 2 == 0 else radius * 0.46
		points.append(center + Vector2(cos(angle), sin(angle)) * point_radius)
	return points
