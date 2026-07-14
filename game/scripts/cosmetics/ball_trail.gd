class_name NetboundBallTrail
extends Node3D

const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")

const MAX_POINTS := 16
const SAMPLE_DISTANCE := 0.22
const SPEED_THRESHOLD := 0.8

var trail_id: String = "trail_none"
var point_limit: int = MAX_POINTS
var _points: Array[MeshInstance3D] = []
var _positions: Array[Vector3] = []
var _materials: Array[StandardMaterial3D] = []
var _last_sample_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	name = "NetboundBallTrail"
	_build_points()
	configure(trail_id)


func configure(new_trail_id: String) -> void:
	var normalized_id := CosmeticRegistryScript.normalize_id_for_category(
		CosmeticRegistryScript.CATEGORY_TRAIL,
		new_trail_id
	)
	if normalized_id == trail_id and not _materials.is_empty():
		reset_trail()
		set_physics_process(trail_id != "trail_none")
		return
	trail_id = normalized_id
	_configure_point_meshes()
	_configure_materials()
	reset_trail()
	set_physics_process(trail_id != "trail_none")


func configure_quality(config: Dictionary) -> void:
	point_limit = clampi(int(config.get("trail_point_limit", MAX_POINTS)), 0, MAX_POINTS)
	while _positions.size() > point_limit:
		_positions.pop_back()
	for i in _points.size():
		if i >= point_limit:
			_points[i].visible = false


func get_point_limit() -> int:
	return point_limit


func reset_trail() -> void:
	_positions.clear()
	_last_sample_position = _ball_position()
	for point in _points:
		point.visible = false


func _physics_process(_delta: float) -> void:
	if trail_id == "trail_none":
		return
	var ball := get_parent() as RigidBody3D
	if not ball:
		reset_trail()
		return

	var speed := ball.linear_velocity.length()
	if speed < SPEED_THRESHOLD:
		reset_trail()
		return

	var position := ball.global_position
	if _positions.is_empty() or position.distance_to(_last_sample_position) >= SAMPLE_DISTANCE:
		_positions.push_front(position)
		_last_sample_position = position
		while _positions.size() > point_limit:
			_positions.pop_back()

	for i in _points.size():
		var point := _points[i]
		if i >= point_limit or i >= _positions.size():
			point.visible = false
			continue
		var age_ratio := float(i) / float(maxi(point_limit - 1, 1))
		var speed_scale := clampf(speed / 18.0, 0.55, 1.35)
		point.visible = true
		point.global_position = _positions[i]
		var point_size := lerpf(0.18, 0.035, age_ratio) * speed_scale
		match trail_id:
			"trail_bubble":
				point.scale = Vector3.ONE * point_size * (1.0 + sin(float(i) * 1.7) * 0.28)
			"trail_streamers":
				point.scale = Vector3(point_size * 1.8, point_size * 0.32, point_size * 0.42)
			"trail_comet":
				point.scale = Vector3(point_size * 1.45, point_size * 0.7, point_size * 0.7)
			"trail_pixel":
				point.scale = Vector3.ONE * point_size * (1.15 if i % 2 == 0 else 0.72)
			"trail_starfall":
				point.scale = Vector3.ONE * point_size * (1.4 if i % 3 == 0 else 0.62)
			_:
				point.scale = Vector3.ONE * point_size
		if i < _materials.size():
			var material := _materials[i]
			var color := _color_for_index(i)
			color.a = lerpf(0.78, 0.0, age_ratio)
			material.albedo_color = color
			material.emission = Color(color.r, color.g, color.b, 1.0) * 0.7


func _build_points() -> void:
	if not _points.is_empty():
		return
	for i in MAX_POINTS:
		var point := MeshInstance3D.new()
		point.name = "TrailPoint%02d" % i
		point.top_level = true
		point.visible = false
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		point.mesh = mesh
		add_child(point)
		_points.append(point)


func _configure_materials() -> void:
	_materials.clear()
	for i in _points.size():
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		var color := _color_for_index(i)
		color.a = 0.75
		material.albedo_color = color
		material.emission = Color(color.r, color.g, color.b, 1.0) * 0.7
		_points[i].material_override = material
		_materials.append(material)


func _configure_point_meshes() -> void:
	for point in _points:
		if trail_id in ["trail_chalk", "trail_streamers", "trail_pixel"]:
			var box := BoxMesh.new()
			box.size = Vector3(0.22, 0.08, 0.08)
			point.mesh = box
		elif trail_id == "trail_starfall":
			var prism := PrismMesh.new()
			prism.size = Vector3(0.2, 0.2, 0.08)
			point.mesh = prism
		else:
			var sphere := SphereMesh.new()
			sphere.radius = 0.12
			sphere.height = 0.24
			point.mesh = sphere


func _color_for_index(index: int) -> Color:
	var ratio := float(index) / float(maxi(MAX_POINTS - 1, 1))
	match trail_id:
		"trail_blue":
			return Color(0.08, lerpf(0.75, 0.3, ratio), 1.0, 1.0)
		"trail_flame":
			return Color(1.0, lerpf(0.46, 0.08, ratio), 0.04, 1.0)
		"trail_spark":
			return Color(1.0, lerpf(0.95, 0.55, ratio), lerpf(0.18, 0.04, ratio), 1.0)
		"trail_rainbow":
			return Color.from_hsv(fmod(ratio * 0.9 + 0.58, 1.0), 0.82, 1.0, 1.0)
		"trail_supporter":
			return Color(
				lerpf(0.1, 1.0, ratio),
				lerpf(1.0, 0.72, ratio),
				lerpf(0.78, 0.18, ratio),
				1.0
			)
		"trail_chalk":
			return Color(0.96, 0.94, 0.84, 1.0)
		"trail_bubble":
			return Color(lerpf(0.35, 0.72, ratio), lerpf(0.92, 0.55, ratio), 1.0, 1.0)
		"trail_streamers":
			return Color("ff665f") if index % 2 == 0 else Color("ffd63f")
		"trail_comet":
			return Color(lerpf(0.9, 0.18, ratio), lerpf(0.98, 0.42, ratio), 1.0, 1.0)
		"trail_pixel":
			return Color.from_hsv(lerpf(0.72, 0.83, ratio), 0.72, 1.0, 1.0)
		"trail_starfall":
			return Color("ffd84d") if index % 3 == 0 else Color("3159c7")
		_:
			return Color(0.0, 0.0, 0.0, 0.0)


func _ball_position() -> Vector3:
	var ball := get_parent() as RigidBody3D
	return ball.global_position if ball else global_position
