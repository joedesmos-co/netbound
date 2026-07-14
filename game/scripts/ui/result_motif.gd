class_name NetboundResultMotif
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var target := Vector2(size.x * 0.82, size.y * 0.67)
	draw_arc(target, 62.0, 0.0, TAU, 40, Color(NetboundUITheme.INK, 0.06), 9.0, true)
	draw_arc(target, 26.0, 0.0, TAU, 30, Color(NetboundUITheme.CORAL, 0.09), 5.0, true)
	draw_circle(target + Vector2(13.0, -15.0), 7.0, Color(NetboundUITheme.INK, 0.08))

	var path := _quadratic_path(
		Vector2(size.x * 0.16, size.y * 0.73),
		Vector2(size.x * 0.48, size.y * 0.62),
		target + Vector2(-30.0, 2.0),
		28
	)
	for index in path.size() - 1:
		if index % 3 != 2:
			draw_line(path[index], path[index + 1], Color(NetboundUITheme.CORAL, 0.08), 6.0, true)


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
