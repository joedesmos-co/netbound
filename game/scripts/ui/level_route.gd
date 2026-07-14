class_name NetboundLevelRoute
extends Container

const H_GAP := 14.0
const V_GAP := 18.0
const MARKER_HEIGHT := 138.0
const V_PADDING := 40.0

var columns: int = 5:
	set(value):
		columns = maxi(1, value)
		queue_sort()
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)
	child_entered_tree.connect(_on_child_tree_changed)
	child_exiting_tree.connect(_on_child_tree_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout_markers()


func _draw() -> void:
	var markers := _markers()
	if markers.size() < 2:
		return
	for index in markers.size() - 1:
		var ports := _connector_ports(markers[index], markers[index + 1])
		var from: Vector2 = ports[0]
		var to: Vector2 = ports[1]
		draw_line(from + Vector2(0.0, 4.0), to + Vector2(0.0, 4.0), Color(NetboundUITheme.INK, 0.34), 13.0, true)
		draw_line(from, to, NetboundUITheme.CHALK, 8.0, true)
		var segment_color := NetboundUITheme.LOCKED
		if bool(markers[index].get("route_completed")):
			segment_color = NetboundUITheme.SUCCESS
		elif bool(markers[index].get("route_unlocked")):
			segment_color = NetboundUITheme.SIGNAL
		draw_line(from, to, segment_color, 4.0, true)

	var start: Vector2 = markers[0].position + Vector2(18.0, markers[0].size.y - 18.0)
	var finish: Vector2 = markers[-1].position + Vector2(markers[-1].size.x - 18.0, markers[-1].size.y - 18.0)
	draw_arc(start, 17.0, 0.0, TAU, 24, NetboundUITheme.CHALK, 4.0, true)
	draw_arc(finish, 18.0, 0.0, TAU, 24, NetboundUITheme.CORAL, 5.0, true)


func _layout_markers() -> void:
	var markers := _markers()
	if markers.is_empty():
		custom_minimum_size.y = 0.0
		return
	var active_columns := mini(columns, markers.size())
	var rows := ceili(float(markers.size()) / float(active_columns))
	var content_height := float(rows) * MARKER_HEIGHT + float(maxi(0, rows - 1)) * V_GAP
	var target_height := content_height + V_PADDING * 2.0
	if not is_equal_approx(custom_minimum_size.y, target_height):
		custom_minimum_size.y = target_height
	var available_width := maxf(size.x, 1.0)
	var top_padding := maxf(V_PADDING, (size.y - content_height) * 0.5)
	var marker_width := maxf(
		190.0,
		(available_width - float(active_columns - 1) * H_GAP) / float(active_columns)
	)

	for index in markers.size():
		var row := index / active_columns
		var logical_column := index % active_columns
		var visual_column := active_columns - 1 - logical_column if row % 2 == 1 else logical_column
		var route_bounce := sin(float(index) * 1.7) * 7.0
		var rect := Rect2(
			Vector2(
				float(visual_column) * (marker_width + H_GAP),
				top_padding + float(row) * (MARKER_HEIGHT + V_GAP) + route_bounce
			),
			Vector2(marker_width, MARKER_HEIGHT)
		)
		fit_child_in_rect(markers[index], rect)
	queue_redraw()


func _markers() -> Array[Button]:
	var result: Array[Button] = []
	for child in get_children():
		var marker := child as Button
		if marker and marker.has_method("configure_level"):
			result.append(marker)
	return result


func _connector_ports(from_marker: Button, to_marker: Button) -> Array[Vector2]:
	var same_row := is_equal_approx(from_marker.position.y, to_marker.position.y)
	if same_row:
		if to_marker.position.x > from_marker.position.x:
			return [
				from_marker.position + Vector2(from_marker.size.x, from_marker.size.y * 0.5),
				to_marker.position + Vector2(0.0, to_marker.size.y * 0.5),
			]
		return [
			from_marker.position + Vector2(0.0, from_marker.size.y * 0.5),
			to_marker.position + Vector2(to_marker.size.x, to_marker.size.y * 0.5),
		]
	return [
		from_marker.position + Vector2(from_marker.size.x * 0.5, from_marker.size.y),
		to_marker.position + Vector2(to_marker.size.x * 0.5, 0.0),
	]


func _on_resized() -> void:
	queue_sort()
	queue_redraw()


func _on_child_tree_changed(_node: Node) -> void:
	queue_sort()
	queue_redraw()
