class_name NetboundGoalNetArt
extends Node3D

## Visual-only woven net with bounded spring-grid reaction.
## Never participates in scoring or collision.

const VISUAL_GROUP := "netbound_visual_polish"
const NET_GROUP := "netbound_goal_net_art"

var _goal: GoalTarget
var _quality_config: Dictionary = {}
var _rope_material: StandardMaterial3D
var _segment_mesh: CylinderMesh
var _panels: Array[Dictionary] = []
var _active: bool = false
var _elapsed: float = 0.0
var _max_duration: float = 1.35
var _hidden_sources: Array[MeshInstance3D] = []
var _reduced_motion: bool = false


func setup(goal: GoalTarget, quality_config: Dictionary = {}) -> void:
	_goal = goal
	_quality_config = quality_config.duplicate(true)
	name = "GoalNetArt"
	add_to_group(VISUAL_GROUP)
	add_to_group(NET_GROUP)
	_build_shared_resources()
	_hide_flat_net_boxes()
	_build_panels()
	set_process(false)


func apply_quality_settings(config: Dictionary) -> void:
	var previous_density := _grid_density()
	_quality_config = config.duplicate(true)
	if _grid_density() != previous_density:
		_build_panels()


func reset_reaction() -> void:
	_active = false
	_elapsed = 0.0
	set_process(false)
	for panel in _panels:
		var offsets: PackedVector3Array = panel["offsets"]
		var velocities: PackedVector3Array = panel["velocities"]
		for i in offsets.size():
			offsets[i] = Vector3.ZERO
			velocities[i] = Vector3.ZERO
		panel["offsets"] = offsets
		panel["velocities"] = velocities
		_update_panel_instances(panel)


func trigger_impact(global_impact: Vector3, global_velocity: Vector3) -> void:
	if not _goal:
		return
	reset_reaction()
	_reduced_motion = _is_reduced_motion()
	var local_impact := _goal.to_local(global_impact)
	var speed := clampf(global_velocity.length() / 18.0, 0.35, 1.6)
	var push_dir := (-global_velocity.normalized()) if global_velocity.length() > 0.15 else Vector3(0.0, 0.0, 1.0)
	push_dir = (_goal.global_transform.basis.inverse() * push_dir).normalized()
	if push_dir.length() < 0.1:
		push_dir = Vector3(0.0, 0.0, 1.0)
	var impulse_scale := 0.55 * speed
	if _reduced_motion:
		impulse_scale *= 0.55
		_max_duration = 0.45
	else:
		_max_duration = lerpf(0.9, 1.45, clampf(speed - 0.35, 0.0, 1.0))
	for panel in _panels:
		var rest: PackedVector3Array = panel["rest"]
		var velocities: PackedVector3Array = panel["velocities"]
		var radius := float(panel["influence_radius"])
		for i in rest.size():
			var dist := rest[i].distance_to(local_impact)
			if dist > radius:
				continue
			var falloff := 1.0 - (dist / radius)
			falloff *= falloff
			var along := push_dir * (impulse_scale * falloff * 1.35)
			match String(panel["name"]):
				"rear":
					along.z = -absf(along.z) - falloff * impulse_scale * 0.9
				"left":
					along.x -= falloff * impulse_scale * 0.55
				"right":
					along.x += falloff * impulse_scale * 0.55
				"top":
					along.y += falloff * impulse_scale * 0.35
					along.z -= falloff * impulse_scale * 0.25
			velocities[i] += along * 8.5
		panel["velocities"] = velocities
	_active = true
	_elapsed = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	var spring := 42.0 if not _reduced_motion else 70.0
	var damp := 7.5 if not _reduced_motion else 14.0
	var max_disp := 0.85 if not _reduced_motion else 0.35
	var still := true
	for panel in _panels:
		var offsets: PackedVector3Array = panel["offsets"]
		var velocities: PackedVector3Array = panel["velocities"]
		for i in offsets.size():
			var force := -offsets[i] * spring - velocities[i] * damp
			velocities[i] += force * delta
			offsets[i] += velocities[i] * delta
			if offsets[i].length() > max_disp:
				offsets[i] = offsets[i].limit_length(max_disp)
			if offsets[i].length() > 0.012 or velocities[i].length() > 0.05:
				still = false
		panel["offsets"] = offsets
		panel["velocities"] = velocities
		_update_panel_instances(panel)
	if still or _elapsed >= _max_duration:
		reset_reaction()


func get_budget_snapshot() -> Dictionary:
	return {
		"panels": _panels.size(),
		"hidden_sources": _hidden_sources.size(),
		"active": _active,
		"rope_points": _total_points(),
		"collision_nodes": 0,
	}


func _total_points() -> int:
	var total := 0
	for panel in _panels:
		total += (panel["rest"] as PackedVector3Array).size()
	return total


func _hide_flat_net_boxes() -> void:
	for path in ["NetLeftSide", "NetRightSide", "NetTop", "NetRear", "NetFloor"]:
		var mesh := _goal.get_node_or_null(path) as MeshInstance3D
		if mesh:
			mesh.visible = false
			_hidden_sources.append(mesh)


func _build_shared_resources() -> void:
	_rope_material = StandardMaterial3D.new()
	_rope_material.albedo_color = Color(0.95, 0.96, 0.93, 0.94)
	_rope_material.roughness = 0.76
	_rope_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rope_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rope_material.emission_enabled = true
	_rope_material.emission = Color(0.07, 0.08, 0.09, 1.0)
	_segment_mesh = CylinderMesh.new()
	_segment_mesh.top_radius = 0.04
	_segment_mesh.bottom_radius = 0.04
	_segment_mesh.height = 1.0
	_segment_mesh.radial_segments = 6
	_segment_mesh.rings = 1


func _build_panels() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_panels.clear()
	var half_w := _goal.opening_half_width
	var height := _goal.crossbar_height
	var depth := _goal.interior_depth
	var density := _grid_density()
	_panels.append(_make_panel("rear", half_w, height, depth, density))
	_panels.append(_make_panel("left", half_w, height, depth, density))
	_panels.append(_make_panel("right", half_w, height, depth, density))
	_panels.append(_make_panel("top", half_w, height, depth, density))


func _grid_density() -> Vector2i:
	var tier := String(_quality_config.get("effective_tier", _quality_config.get("tier", "high")))
	match tier:
		"low":
			return Vector2i(5, 4)
		"medium":
			return Vector2i(7, 5)
		_:
			return Vector2i(9, 6)


func _make_panel(panel_name: String, half_w: float, height: float, depth: float, density: Vector2i) -> Dictionary:
	var cols := density.x
	var rows := density.y
	if panel_name in ["left", "right", "top"]:
		cols = maxi(density.x - 1, 3)
		rows = density.y if panel_name != "top" else maxi(density.x - 1, 3)
	var rest := PackedVector3Array()
	var offsets := PackedVector3Array()
	var velocities := PackedVector3Array()
	for row in rows:
		for col in cols:
			var u := 0.0 if cols <= 1 else float(col) / float(cols - 1)
			var v := 0.0 if rows <= 1 else float(row) / float(rows - 1)
			var point := Vector3.ZERO
			match panel_name:
				"rear":
					point = Vector3(lerpf(-half_w, half_w, u), lerpf(0.12, height - 0.12, v), -depth + 0.06)
				"left":
					point = Vector3(-half_w - 0.05, lerpf(0.12, height - 0.12, v), lerpf(-depth + 0.12, -0.12, u))
				"right":
					point = Vector3(half_w + 0.05, lerpf(0.12, height - 0.12, v), lerpf(-depth + 0.12, -0.12, u))
				"top":
					point = Vector3(lerpf(-half_w, half_w, u), height - 0.08, lerpf(-depth + 0.12, -0.2, v))
			rest.append(point)
			offsets.append(Vector3.ZERO)
			velocities.append(Vector3.ZERO)
	var segment_count := rows * (cols - 1) + cols * (rows - 1)
	var multi := MultiMeshInstance3D.new()
	multi.name = "NetPanel_%s" % panel_name
	multi.add_to_group(VISUAL_GROUP)
	multi.add_to_group(NET_GROUP)
	var multi_mesh := MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.mesh = _segment_mesh
	multi_mesh.instance_count = segment_count
	multi.multimesh = multi_mesh
	multi.material_override = _rope_material
	add_child(multi)
	var influence := maxf(half_w * 1.1, 6.0)
	if panel_name in ["left", "right"]:
		influence = maxf(depth * 0.95, 4.5)
	var panel := {
		"name": panel_name,
		"multi": multi,
		"rest": rest,
		"offsets": offsets,
		"velocities": velocities,
		"cols": cols,
		"rows": rows,
		"influence_radius": influence,
	}
	_update_panel_instances(panel)
	return panel


func _update_panel_instances(panel: Dictionary) -> void:
	var cols: int = panel["cols"]
	var rows: int = panel["rows"]
	var rest: PackedVector3Array = panel["rest"]
	var offsets: PackedVector3Array = panel["offsets"]
	var multi: MultiMesh = (panel["multi"] as MultiMeshInstance3D).multimesh
	var index := 0
	for row in rows:
		for col in range(cols - 1):
			var a := rest[row * cols + col] + offsets[row * cols + col]
			var b := rest[row * cols + col + 1] + offsets[row * cols + col + 1]
			multi.set_instance_transform(index, _segment_transform(a, b))
			index += 1
	for col in cols:
		for row in range(rows - 1):
			var a := rest[row * cols + col] + offsets[row * cols + col]
			var b := rest[(row + 1) * cols + col] + offsets[(row + 1) * cols + col]
			multi.set_instance_transform(index, _segment_transform(a, b))
			index += 1


func _segment_transform(a: Vector3, b: Vector3) -> Transform3D:
	var delta := b - a
	var length := maxf(delta.length(), 0.001)
	var mid := (a + b) * 0.5
	var basis := Basis()
	var y_axis := delta / length
	var x_axis := y_axis.cross(Vector3.FORWARD)
	if x_axis.length() < 0.001:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	basis.x = x_axis
	basis.y = y_axis
	basis.z = z_axis
	return Transform3D(basis.scaled(Vector3(1.0, length, 1.0)), mid)


func _is_reduced_motion() -> bool:
	var save_service := get_node_or_null("/root/SaveService")
	return bool(save_service and save_service.call("get_setting_value", "reduced_motion_enabled", false))
