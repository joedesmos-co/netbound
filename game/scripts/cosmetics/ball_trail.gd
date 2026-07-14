class_name NetboundBallTrail
extends Node3D

const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")

const MAX_POINTS := 16
const SAMPLE_DISTANCE := 0.22
const SPEED_THRESHOLD := 0.8

var trail_id: String = "trail_none"
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
	_configure_materials()
	reset_trail()
	set_physics_process(trail_id != "trail_none")


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
		while _positions.size() > MAX_POINTS:
			_positions.pop_back()

	for i in _points.size():
		var point := _points[i]
		if i >= _positions.size():
			point.visible = false
			continue
		var age_ratio := float(i) / float(maxi(MAX_POINTS - 1, 1))
		var speed_scale := clampf(speed / 18.0, 0.55, 1.35)
		point.visible = true
		point.global_position = _positions[i]
		point.scale = Vector3.ONE * lerpf(0.18, 0.035, age_ratio) * speed_scale
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
		_:
			return Color(0.0, 0.0, 0.0, 0.0)


func _ball_position() -> Vector3:
	var ball := get_parent() as RigidBody3D
	return ball.global_position if ball else global_position
