class_name NetboundWordmark
extends Control


func _ready() -> void:
	custom_minimum_size = Vector2(500.0, 138.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var font := NetboundUITheme.FONT_DISPLAY
	var font_size := clampi(roundi(size.y * 0.72), 64, 112)
	var prefix := "NETB"
	var suffix := "UND"
	var prefix_width := font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var suffix_width := font.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var target_diameter := font_size * 0.62
	var total_width := prefix_width + target_diameter + suffix_width
	if total_width > size.x:
		font_size = maxi(56, floori(float(font_size) * size.x / total_width))
		prefix_width = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		suffix_width = font.get_string_size(suffix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		target_diameter = font_size * 0.62
		total_width = prefix_width + target_diameter + suffix_width

	var start_x := maxf(0.0, (size.x - total_width) * 0.5)
	var baseline := size.y * 0.72
	draw_string(
		font,
		Vector2(start_x + 6.0, baseline + 7.0),
		prefix,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(NetboundUITheme.INK, 0.48)
	)
	draw_string(
		font,
		Vector2(start_x, baseline),
		prefix,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		NetboundUITheme.CHALK
	)

	var target_center := Vector2(
		start_x + prefix_width + target_diameter * 0.5,
		baseline - font_size * 0.34
	)
	var outer_radius := target_diameter * 0.46
	draw_circle(target_center + Vector2(6.0, 7.0), outer_radius, Color(NetboundUITheme.INK, 0.48))
	draw_circle(target_center, outer_radius, NetboundUITheme.SIGNAL)
	draw_circle(target_center, outer_radius * 0.62, NetboundUITheme.INK)
	draw_arc(target_center, outer_radius * 0.78, -1.1, 2.2, 20, NetboundUITheme.CHALK, 3.0, true)
	var ball_position := target_center + Vector2(outer_radius * 0.56, -outer_radius * 0.58)
	draw_circle(ball_position, maxf(5.0, outer_radius * 0.15), NetboundUITheme.CHALK)
	draw_circle(ball_position + Vector2(-1.5, -1.0), maxf(1.5, outer_radius * 0.045), NetboundUITheme.INK)

	draw_string(
		font,
		Vector2(start_x + prefix_width + target_diameter + 6.0, baseline + 7.0),
		suffix,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(NetboundUITheme.INK, 0.48)
	)
	draw_string(
		font,
		Vector2(start_x + prefix_width + target_diameter, baseline),
		suffix,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		NetboundUITheme.CHALK
	)

	var path_points := PackedVector2Array()
	var path_start := Vector2(target_center.x - target_diameter * 2.05, baseline + 23.0)
	var path_control := Vector2(target_center.x - target_diameter * 1.22, baseline + 37.0)
	var path_end := target_center + Vector2(-outer_radius * 0.88, outer_radius * 0.32)
	for index in 18:
		var t := float(index) / 17.0
		var inverse := 1.0 - t
		path_points.append(
			inverse * inverse * path_start
			+ 2.0 * inverse * t * path_control
			+ t * t * path_end
		)
	draw_polyline(path_points, NetboundUITheme.CORAL, 7.0, true)
