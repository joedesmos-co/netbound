class_name NetboundArcadeCourseArt
extends Node

const VISUAL_GROUP := "netbound_visual_polish"
const COURSE_GROUP := "netbound_course_art"
const DETAIL_GROUP := "netbound_course_art_detail"

const ARCHETYPE_BLOCKER := "padded_blocker"
const ARCHETYPE_GATE := "sliding_panel"
const ARCHETYPE_SPINNER := "training_spinner"
const ARCHETYPE_REBOUND := "rebound_board"
const ARCHETYPE_TOWER := "stacked_tower"
const ARCHETYPE_PARTITION := "training_partition"

var _level: Node
var _quality_config: Dictionary = {}
var _materials: Dictionary = {}
var _mesh_cache: Dictionary = {}
var _wrappers: Array[Node3D] = []
var _base_meshes: Array[MeshInstance3D] = []
var _detail_meshes: Array[MeshInstance3D] = []
var _hidden_sources: Array[MeshInstance3D] = []
var _archetype_counts: Dictionary = {}


func setup(level: Node, quality_config: Dictionary) -> void:
	_level = level
	_quality_config = quality_config.duplicate(true)
	name = "CourseArt"
	add_to_group(VISUAL_GROUP)
	_build_materials()
	_wrap_course_obstacles()
	apply_quality_settings(_quality_config)


func apply_quality_settings(config: Dictionary) -> void:
	_quality_config = config.duplicate(true)
	var details_enabled := bool(_quality_config.get("decorative_geometry_enabled", true))
	for detail in _detail_meshes:
		if is_instance_valid(detail):
			detail.visible = details_enabled or bool(detail.get_meta("keep_low", false))
	for base in _base_meshes:
		if is_instance_valid(base):
			base.visible = true


func get_budget_snapshot() -> Dictionary:
	return {
		"wrapped_obstacles": _wrappers.size(),
		"visual_nodes": _wrappers.size() + _base_meshes.size() + _detail_meshes.size(),
		"base_meshes": _base_meshes.size(),
		"detail_meshes": _detail_meshes.size(),
		"hidden_sources": _hidden_sources.size(),
		"collision_nodes": 0,
		"material_resources": _materials.size(),
		"mesh_resources": _mesh_cache.size(),
		"archetypes": _archetype_counts.duplicate(true),
	}


func get_wrappers() -> Array[Node3D]:
	return _wrappers.duplicate()


func _wrap_course_obstacles() -> void:
	for node in _level.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not _is_course_obstacle(body):
			continue
		var source := body.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if not source or not source.visible or not (source.mesh is BoxMesh):
			continue
		var size := (source.mesh as BoxMesh).size
		if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
			continue
		var archetype := _archetype_for(body)
		var wrapper := Node3D.new()
		wrapper.name = "NetboundCourseArt"
		wrapper.transform = source.transform
		wrapper.add_to_group(VISUAL_GROUP)
		wrapper.add_to_group(COURSE_GROUP)
		wrapper.set_meta("archetype", archetype)
		wrapper.set_meta("source_path", String(source.get_path()))
		wrapper.set_meta("visual_size", size)
		body.add_child(wrapper)
		source.visible = false
		_hidden_sources.append(source)
		_wrappers.append(wrapper)
		_archetype_counts[archetype] = int(_archetype_counts.get(archetype, 0)) + 1
		_build_archetype(wrapper, size, archetype)


func _is_course_obstacle(body: StaticBody3D) -> bool:
	if not body or body.name == "Ground" or body.name == "Obstacle":
		return false
	if not body.visible or body.collision_layer == 0:
		return false
	var ancestor: Node = body
	while ancestor and ancestor != _level:
		if ancestor.name == "Goal" or ancestor is GoalTarget:
			return false
		ancestor = ancestor.get_parent()
	return body.has_node("CollisionShape3D") and not body.has_node("NetboundCourseArt")


func _archetype_for(body: StaticBody3D) -> String:
	var path := String(body.get_path()).to_lower()
	if body is BounceSurface or path.contains("bank") or path.contains("bounce"):
		return ARCHETYPE_REBOUND
	if _script_path(body).ends_with("rotating_obstacle.gd") or path.contains("rotating"):
		return ARCHETYPE_SPINNER
	if _has_motion_ancestor(body) or path.contains("gate") or path.contains("traffic") or path.contains("slider") or path.contains("elevator") or path.contains("beat"):
		return ARCHETYPE_GATE
	if path.contains("tower") or path.contains("lift") or path.contains("overhead") or path.contains("topcap"):
		return ARCHETYPE_TOWER
	if path.contains("wall") or path.contains("shield"):
		return ARCHETYPE_PARTITION
	return ARCHETYPE_BLOCKER


func _has_motion_ancestor(node: Node) -> bool:
	var ancestor: Node = node
	while ancestor and ancestor != _level:
		var script_path := _script_path(ancestor)
		if script_path.ends_with("moving_obstacle.gd") or script_path.ends_with("timed_gate.gd"):
			return true
		ancestor = ancestor.get_parent()
	return false


func _script_path(node: Node) -> String:
	var script := node.get_script() as Script
	return script.resource_path.to_lower() if script else ""


func _build_archetype(root: Node3D, size: Vector3, archetype: String) -> void:
	match archetype:
		ARCHETYPE_GATE:
			_build_sliding_panel(root, size)
		ARCHETYPE_SPINNER:
			_build_training_spinner(root, size)
		ARCHETYPE_REBOUND:
			_build_rebound_board(root, size)
		ARCHETYPE_TOWER:
			_build_stacked_tower(root, size)
		ARCHETYPE_PARTITION:
			_build_training_partition(root, size)
		_:
			_build_padded_blocker(root, size)


func _build_padded_blocker(root: Node3D, size: Vector3) -> void:
	_add_box(root, "PadFrame", size, Vector3.ZERO, _materials.navy, false)
	var face_z := size.z * 0.5 + 0.014
	_add_box(
		root,
		"SafetyPad",
		Vector3(size.x * 0.9, size.y * 0.78, 0.035),
		Vector3(0.0, 0.0, face_z),
		_materials.foam,
		true,
		true
	)
	if size.y >= 0.8 and size.x >= 0.8:
		var radius := clampf(minf(size.x, size.y) * 0.2, 0.16, 0.72)
		_add_disc(root, "TargetRing", radius, 0.035, Vector3(0.0, 0.0, face_z + 0.02), _materials.canvas, "z", 16, true)
		_add_disc(root, "TargetCenter", radius * 0.58, 0.04, Vector3(0.0, 0.0, face_z + 0.044), _materials.navy, "z", 16)


func _build_sliding_panel(root: Node3D, size: Vector3) -> void:
	_add_box(root, "ScoreboardFrame", size, Vector3.ZERO, _materials.navy, false)
	var face_z := size.z * 0.5 + 0.014
	_add_box(
		root,
		"ScoreboardFace",
		Vector3(size.x * 0.9, size.y * 0.78, 0.035),
		Vector3(0.0, 0.0, face_z),
		_materials.moving,
		true,
		true
	)
	var track_height := clampf(size.y * 0.1, 0.08, 0.2)
	_add_box(
		root,
		"MotionTrack",
		Vector3(size.x * 0.54, track_height, 0.04),
		Vector3(0.0, 0.0, face_z + 0.03),
		_materials.canvas
	)
	_add_box(
		root,
		"TrackMarker",
		Vector3(clampf(size.x * 0.1, 0.14, 0.46), track_height * 1.45, 0.045),
		Vector3(0.0, 0.0, face_z + 0.052),
		_materials.yellow
	)


func _build_training_spinner(root: Node3D, size: Vector3) -> void:
	_add_box(root, "BarrierFrame", size, Vector3.ZERO, _materials.navy, false)
	var face_z := size.z * 0.5 + 0.014
	for segment_index in 5:
		var segment_x := (float(segment_index) - 2.0) * size.x * 0.18
		_add_box(
			root,
			"BarrierStripe",
			Vector3(size.x * 0.15, size.y * 0.72, 0.035),
			Vector3(segment_x, 0.0, face_z),
			_materials.spinner if segment_index % 2 == 0 else _materials.canvas,
			true,
			true
		)
	var radius := clampf(size.y * 0.78, 0.18, 0.46)
	_add_disc(root, "OctagonalHub", radius, 0.04, Vector3(0.0, 0.0, face_z + 0.02), _materials.foam, "z", 8, true)
	_add_disc(root, "HubBolt", radius * 0.42, 0.045, Vector3(0.0, 0.0, face_z + 0.044), _materials.navy, "z", 8)


func _build_stacked_tower(root: Node3D, size: Vector3) -> void:
	_add_box(root, "CrashPadFrame", size, Vector3.ZERO, _materials.navy, false)
	var face_z := size.z * 0.5 + 0.014
	if size.y < 1.4:
		_add_box(
			root,
			"HurdlePad",
			Vector3(size.x * 0.9, size.y * 0.7, 0.035),
			Vector3(0.0, 0.0, face_z),
			_materials.foam,
			true,
			true
		)
		return
	var segment_height := size.y * 0.22
	for segment_y in [-0.27, 0.0, 0.27]:
		_add_box(
			root,
			"CrashMat",
			Vector3(size.x * 0.86, segment_height, 0.035),
			Vector3(0.0, segment_y * size.y, face_z),
			_materials.foam,
			true,
			true
		)


func _build_training_partition(root: Node3D, size: Vector3) -> void:
	_add_box(root, "PartitionBody", size, Vector3.ZERO, _materials.navy, false)
	var face_z := size.z * 0.5 + 0.014
	_add_box(
		root,
		"BarricadeFace",
		Vector3(size.x * 0.9, size.y * 0.78, 0.035),
		Vector3(0.0, 0.0, face_z),
		_materials.canvas,
		true,
		true
	)
	for stripe_index in 3:
		var x := (float(stripe_index) - 1.0) * size.x * 0.26
		_add_box(
			root,
			"SafetyStripe",
			Vector3(size.x * 0.09, size.y * 0.62, 0.04),
			Vector3(x, 0.0, face_z + 0.03),
			_materials.foam,
			true,
			false,
			Vector3(0.0, 0.0, -0.32)
		)


func _build_rebound_board(root: Node3D, size: Vector3) -> void:
	_add_box(root, "ReboundFrame", size, Vector3.ZERO, _materials.navy, false)
	var thin_axis := "x" if size.x <= size.z else "z"
	for side in [-1.0, 1.0]:
		if thin_axis == "x":
			_add_box(root, "ReboundFace", Vector3(0.035, size.y * 0.84, size.z * 0.88), Vector3(side * (size.x * 0.5 + 0.014), 0.0, 0.0), _materials.rebound, true, true)
			_add_box(root, "ReboundMark", Vector3(0.04, size.y * 0.12, size.z * 0.62), Vector3(side * (size.x * 0.5 + 0.038), 0.0, 0.0), _materials.canvas)
		else:
			_add_box(root, "ReboundFace", Vector3(size.x * 0.88, size.y * 0.84, 0.035), Vector3(0.0, 0.0, side * (size.z * 0.5 + 0.014)), _materials.rebound, true, true)
			_add_box(root, "ReboundMark", Vector3(size.x * 0.62, size.y * 0.12, 0.04), Vector3(0.0, 0.0, side * (size.z * 0.5 + 0.038)), _materials.canvas)


func _add_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material: Material,
	is_detail: bool = true,
	keep_low: bool = false,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _box_mesh(size)
	instance.material_override = material
	instance.position = position_value
	instance.rotation = rotation_value
	instance.add_to_group(VISUAL_GROUP)
	instance.add_to_group(COURSE_GROUP)
	if is_detail:
		instance.add_to_group(DETAIL_GROUP)
		instance.set_meta("keep_low", keep_low)
		_detail_meshes.append(instance)
	else:
		_base_meshes.append(instance)
	parent.add_child(instance)
	return instance


func _add_disc(
	parent: Node3D,
	node_name: String,
	radius: float,
	depth: float,
	position_value: Vector3,
	material: Material,
	face_axis: String,
	segments: int = 12,
	keep_low: bool = false
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = _cylinder_mesh(radius, depth, segments)
	instance.material_override = material
	instance.position = position_value
	instance.rotation = Vector3(PI * 0.5, 0.0, 0.0) if face_axis == "z" else Vector3(0.0, 0.0, PI * 0.5)
	instance.add_to_group(VISUAL_GROUP)
	instance.add_to_group(COURSE_GROUP)
	instance.add_to_group(DETAIL_GROUP)
	instance.set_meta("keep_low", keep_low)
	_detail_meshes.append(instance)
	parent.add_child(instance)
	return instance


func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "box:%.3f:%.3f:%.3f" % [size.x, size.y, size.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_cache[key] = mesh
	return mesh


func _cylinder_mesh(radius: float, depth: float, segments: int) -> CylinderMesh:
	var key := "cylinder:%.3f:%.3f:%d" % [radius, depth, segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as CylinderMesh
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = segments
	mesh.rings = 1
	_mesh_cache[key] = mesh
	return mesh


func _build_materials() -> void:
	_materials = {
		"foam": _material(Color("ef6a59"), 0.86),
		"moving": _material(Color("35a9a3"), 0.78),
		"spinner": _material(Color("f0c84b"), 0.78),
		"rebound": _material(Color("238d82"), 0.7),
		"canvas": _material(Color("f6f0df"), 0.92),
		"navy": _material(Color("17324a"), 0.82),
		"yellow": _material(Color("f3cf4b"), 0.78),
	}


func _material(color: Color, roughness: float, emission: Color = Color.TRANSPARENT) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
	return material
