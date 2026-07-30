class_name NetboundLevelVisualPolish
extends Node3D

const VISUAL_GROUP := "netbound_visual_polish"
const CourseArtScript := preload("res://scripts/presentation/arcade_course_art.gd")
const WorldCatalogScript := preload("res://scripts/levels/world_catalog.gd")

var _level: Node
var _definition: LevelDefinition
var _ball: RigidBody3D
var _goal_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _shadow: MeshInstance3D
var _course_art
var _active_tweens: Array[Tween] = []
var _palette: Dictionary = {}
var _world_id: String = WorldCatalogScript.WORLD_TRAINING
var _quality_config: Dictionary = {
	"decorative_geometry_enabled": true,
	"contact_shadow_enabled": true,
	"dynamic_shadows_enabled": true,
}

const GOAL_FRAME_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const GOAL_FRAME_EMISSION := Color(0.08, 0.09, 0.1, 1.0)
const SUCCESS_EMISSION := Color(0.16, 0.9, 0.4, 1.0)


func setup(level: Node) -> void:
	_level = level
	_definition = level.get("level_definition") as LevelDefinition
	_ball = level.get_node_or_null("Ball") as RigidBody3D
	name = "LevelVisualPolish"
	add_to_group(VISUAL_GROUP)
	_world_id = WorldCatalogScript.get_world_id_for_level_id(
		_definition.level_id if _definition else "level_01"
	)
	_palette = _palette_for_world(_world_id, _level_index())
	_apply_environment()
	_apply_material_language()
	_hide_prototype_markers()
	_build_course_art()
	_build_decorative_geometry()
	_build_contact_shadow()
	_apply_quality_settings_to_nodes()
	set_process(_ball != null)


func _process(_delta: float) -> void:
	_update_contact_shadow()


func on_goal_scored() -> void:
	if not _goal_material:
		return
	var tween := create_tween()
	_active_tweens.append(tween)
	var base_emission := GOAL_FRAME_EMISSION
	if _reduced_motion_enabled():
		_goal_material.emission = SUCCESS_EMISSION
		tween.tween_interval(0.2)
		tween.tween_callback(func() -> void: _goal_material.emission = base_emission)
	else:
		tween.tween_property(_goal_material, "emission", SUCCESS_EMISSION, 0.06)
		tween.tween_interval(0.12)
		tween.tween_property(_goal_material, "emission", base_emission, 0.24)
	tween.tween_callback(func() -> void: _active_tweens.erase(tween))


func clear_feedback() -> void:
	for tween in _active_tweens:
		if tween:
			tween.kill()
	_active_tweens.clear()
	if _goal_material:
		_goal_material.emission = GOAL_FRAME_EMISSION


func get_budget_snapshot() -> Dictionary:
	var visual_nodes := 0
	var collision_nodes := 0
	for child in find_children("*", "", true, false):
		if child.is_in_group(VISUAL_GROUP):
			visual_nodes += 1
			if child is CollisionObject3D:
				collision_nodes += 1
	var snapshot := {
		"visual_nodes": visual_nodes,
		"collision_nodes": collision_nodes,
		"active_tweens": _active_tweens.size(),
		"quality": _quality_config.duplicate(true),
	}
	if _course_art:
		snapshot["course_art"] = _course_art.get_budget_snapshot()
	return snapshot


func apply_quality_settings(config: Dictionary) -> void:
	_quality_config = config.duplicate(true)
	_apply_quality_settings_to_nodes()
	if _course_art:
		_course_art.apply_quality_settings(_quality_config)


func _build_course_art() -> void:
	if _course_art:
		return
	_course_art = CourseArtScript.new()
	add_child(_course_art)
	_course_art.setup(_level, _quality_config)


func _apply_environment() -> void:
	var environment_node := _level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node:
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = _palette.get("sky", Color(0.42, 0.58, 0.82, 1.0))
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = _palette.get("ambient", Color(0.85, 0.9, 1.0, 1.0))
		environment.ambient_light_energy = float(_palette.get("ambient_energy", 0.78))
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.tonemap_exposure = float(_palette.get("exposure", 1.0))
		environment_node.environment = environment

	var sun := _level.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.light_color = _palette.get("sun", Color(1.0, 0.96, 0.86, 1.0))
		sun.light_energy = float(_palette.get("sun_energy", 1.55))
		sun.shadow_enabled = bool(_quality_config.get("dynamic_shadows_enabled", true))
		sun.shadow_blur = float(_palette.get("shadow_blur", 1.15))
		sun.directional_shadow_max_distance = 48.0
		if _world_id == WorldCatalogScript.WORLD_STADIUM:
			sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
		elif _world_id == WorldCatalogScript.WORLD_STREET:
			sun.rotation_degrees = Vector3(-42.0, 34.0, 0.0)
		else:
			sun.rotation_degrees = Vector3(-50.0, 18.0, 0.0)


func _apply_material_language() -> void:
	var field_material := _material(_palette.get("field", Color(0.08, 0.48, 0.28, 1.0)), 0.9)
	var static_material := _material(_palette.get("static", Color(0.86, 0.28, 0.24, 1.0)), 0.66)
	var static_accent_material := _material(
		_palette.get("static_accent", Color(0.52, 0.28, 0.82, 1.0)),
		0.58,
		true
	)
	var gate_material := _material(_palette.get("gate", Color(0.16, 0.82, 1.0, 1.0)), 0.48, true)
	var route_material := _material(_palette.get("route", Color(1.0, 0.86, 0.22, 0.72)), 0.62, true, true)
	var bounce_material := _material(_palette.get("bounce", Color(0.0, 0.95, 0.72, 1.0)), 0.32, true)
	var net_material := _material(_palette.get("net", Color(0.8, 0.95, 1.0, 0.26)), 0.86, false, true)
	_goal_material = _material(GOAL_FRAME_COLOR, 0.28, true)
	_goal_material.emission = GOAL_FRAME_EMISSION
	_trim_material = _material(_palette.get("trim", Color(1.0, 0.85, 0.28, 1.0)), 0.45, true)

	for node in _level.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh or _should_skip_mesh(mesh):
			continue
		var path := String(mesh.get_path()).to_lower()
		var parent_name := mesh.get_parent().name.to_lower() if mesh.get_parent() else ""
		var node_name := mesh.name.to_lower()
		if parent_name == "ground":
			mesh.material_override = field_material
		elif path.contains("/goal/"):
			mesh.material_override = net_material if node_name.contains("net") or parent_name.contains("net") else _goal_material
		elif _is_route_mesh(path, node_name, parent_name):
			mesh.material_override = route_material
		elif path.contains("bank") or path.contains("bounce"):
			mesh.material_override = bounce_material
		elif _uses_moving_material(mesh) or path.contains("gate") or path.contains("rotating"):
			mesh.material_override = gate_material
		elif path.contains("tower") or path.contains("lift"):
			mesh.material_override = static_accent_material
		elif mesh.get_parent() is StaticBody3D:
			mesh.material_override = static_material


func _hide_prototype_markers() -> void:
	# The inherited Level 01 obstacle is an off-course compatibility sentinel,
	# not production course art. Keep its collider intact while hiding its mesh.
	var prototype_obstacle := _level.get_node_or_null("Obstacle") as StaticBody3D
	if not prototype_obstacle:
		return
	for child in prototype_obstacle.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false


func _build_decorative_geometry() -> void:
	if has_node("VisualDeck"):
		return
	var deck := Node3D.new()
	deck.name = "VisualDeck"
	deck.add_to_group(VISUAL_GROUP)
	add_child(deck)

	var field_line_material := _material(_palette.get("field_line", Color(1.0, 1.0, 1.0, 0.16)), 0.75, false, true)
	var route_material := _material(_palette.get("route", Color(1.0, 0.86, 0.22, 0.6)), 0.58, true, true)
	var backdrop_material := _material(_palette.get("backdrop", Color(0.08, 0.14, 0.22, 1.0)), 0.82, true)
	var secondary_material := _material(
		_palette.get("backdrop_secondary", Color(0.12, 0.2, 0.3, 1.0)),
		0.78,
		true
	)
	var banner_material := _material(_palette.get("banner", Color(0.95, 0.35, 0.28, 1.0)), 0.55, true)
	var seat_material := _material(_palette.get("seating", Color(0.16, 0.22, 0.34, 1.0)), 0.88, true)

	for i in 9:
		var z := lerpf(-16.0, 9.5, float(i) / 8.0)
		_add_box(deck, "FieldStripe%02d" % i, Vector3(0.0, 0.025, z), Vector3(45.5, 0.018, 0.1), field_line_material)

	for x in [-18.0, 18.0]:
		_add_box(deck, "SideTrim%.0f" % x, Vector3(x, 0.08, -3.0), Vector3(0.18, 0.16, 31.5), _trim_material)
	for x in [-5.5, 5.5]:
		_add_box(deck, "RouteRail%.0f" % x, Vector3(x, 0.04, -5.5), Vector3(0.12, 0.08, 10.0), route_material)

	_add_box(deck, "BackArenaWall", Vector3(0.0, 2.2, -17.2), Vector3(45.0, 4.4, 0.18), backdrop_material)
	_add_box(deck, "LeftArenaRail", Vector3(-22.7, 1.05, -3.0), Vector3(0.18, 2.1, 30.0), backdrop_material)
	_add_box(deck, "RightArenaRail", Vector3(22.7, 1.05, -3.0), Vector3(0.18, 2.1, 30.0), backdrop_material)

	match _world_id:
		WorldCatalogScript.WORLD_TRAINING:
			_add_box(deck, "PracticeFence", Vector3(0.0, 1.35, -17.55), Vector3(36.0, 2.4, 0.12), secondary_material)
			for i in 4:
				var x := lerpf(-14.0, 14.0, float(i) / 3.0)
				_add_box(deck, "PracticeBanner%02d" % i, Vector3(x, 2.7, -17.4), Vector3(3.2, 1.1, 0.08), banner_material)
			for i in 5:
				var x := lerpf(-12.0, 12.0, float(i) / 4.0)
				_add_box(deck, "ConeMark%02d" % i, Vector3(x, 0.18, 4.8), Vector3(0.35, 0.36, 0.35), _trim_material)
		WorldCatalogScript.WORLD_STREET:
			_add_box(deck, "CourtWall", Vector3(0.0, 2.8, -17.55), Vector3(40.0, 5.2, 0.16), secondary_material)
			for i in 3:
				var x := lerpf(-12.0, 12.0, float(i) / 2.0)
				_add_box(deck, "WallStripe%02d" % i, Vector3(x, 2.4, -17.42), Vector3(4.8, 0.55, 0.06), banner_material)
			_add_box(deck, "LeftCourtRail", Vector3(-21.8, 0.55, -2.0), Vector3(0.35, 1.1, 24.0), seat_material)
			_add_box(deck, "RightCourtRail", Vector3(21.8, 0.55, -2.0), Vector3(0.35, 1.1, 24.0), seat_material)
		_:
			_add_box(deck, "StandBand", Vector3(0.0, 3.6, -17.8), Vector3(48.0, 6.8, 0.4), seat_material)
			_add_box(deck, "UpperDeck", Vector3(0.0, 6.4, -18.5), Vector3(46.0, 2.2, 1.4), secondary_material)
			for i in 5:
				var x := lerpf(-16.0, 16.0, float(i) / 4.0)
				_add_box(deck, "FlagMast%02d" % i, Vector3(x, 5.2, -17.1), Vector3(0.12, 4.4, 0.12), _trim_material)
				_add_box(deck, "FlagCloth%02d" % i, Vector3(x + 0.55, 6.8, -17.05), Vector3(1.1, 0.7, 0.05), banner_material)
			for i in 3:
				var x := lerpf(-14.0, 14.0, float(i) / 2.0)
				_add_box(deck, "Floodlight%02d" % i, Vector3(x, 8.4, -16.4), Vector3(1.8, 0.35, 0.55), _trim_material)
			_add_box(deck, "ScoreboardFace", Vector3(0.0, 7.8, -17.0), Vector3(8.5, 2.2, 0.25), secondary_material)
			_add_box(deck, "ScoreboardScreen", Vector3(0.0, 7.8, -16.85), Vector3(7.2, 1.5, 0.08), route_material)


func _build_contact_shadow() -> void:
	if not _ball or _shadow:
		return
	_shadow = MeshInstance3D.new()
	_shadow.name = "BallContactShadow"
	_shadow.top_level = true
	_shadow.add_to_group(VISUAL_GROUP)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.58
	mesh.bottom_radius = 0.58
	mesh.height = 0.01
	mesh.radial_segments = 32
	_shadow.mesh = mesh
	var material := _material(Color(0.0, 0.0, 0.0, 0.28), 1.0, false, true)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = material
	add_child(_shadow)
	_update_contact_shadow()


func _update_contact_shadow() -> void:
	if not _shadow or not _ball:
		return
	var height := maxf(_ball.global_position.y - 0.5, 0.0)
	var scale_value := clampf(1.0 + height * 0.08, 0.72, 1.75)
	_shadow.global_position = Vector3(_ball.global_position.x, 0.028, _ball.global_position.z)
	_shadow.scale = Vector3(scale_value, 1.0, scale_value)
	_shadow.visible = bool(_quality_config.get("contact_shadow_enabled", true)) and _ball.global_position.y > -0.4


func _apply_quality_settings_to_nodes() -> void:
	var deck := get_node_or_null("VisualDeck") as Node3D
	if deck:
		deck.visible = bool(_quality_config.get("decorative_geometry_enabled", true))
	if _shadow:
		_shadow.visible = bool(_quality_config.get("contact_shadow_enabled", true))
	var sun: DirectionalLight3D = null
	if _level:
		sun = _level.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = bool(_quality_config.get("dynamic_shadows_enabled", true))


func _add_box(
	parent: Node3D,
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.add_to_group(VISUAL_GROUP)
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position_value
	parent.add_child(mesh_instance)
	return mesh_instance


func _should_skip_mesh(mesh: MeshInstance3D) -> bool:
	var path := String(mesh.get_path()).to_lower()
	return (
		mesh.is_in_group(VISUAL_GROUP)
		or path.contains("/ball/")
		or path.contains("/aimguide/")
		or path.contains("/goaldetection/")
		or mesh.name.to_lower().contains("debug")
	)


func _is_route_mesh(path: String, node_name: String, parent_name: String) -> bool:
	return (
		path.contains("lane")
		or path.contains("marker")
		or path.contains("hint")
		or path.contains("route")
		or node_name.contains("stripe")
		or parent_name.contains("stripe")
	)


func _uses_moving_material(mesh: MeshInstance3D) -> bool:
	var ancestor: Node = mesh.get_parent()
	while ancestor and ancestor != _level:
		if ancestor is MovingObstacle or ancestor is TimedGate or ancestor is RotatingObstacle:
			return true
		ancestor = ancestor.get_parent()
	return false


func _level_index() -> int:
	if not _definition:
		return 1
	var parts := _definition.level_id.split("_")
	if parts.size() >= 2:
		return clampi(int(parts[-1]), 1, 30)
	return 1


func _reduced_motion_enabled() -> bool:
	var save_service := get_node_or_null("/root/SaveService")
	return bool(save_service and save_service.call("get_setting_value", "reduced_motion_enabled", false))


func _palette_for_world(world_id: String, level_index: int) -> Dictionary:
	match world_id:
		WorldCatalogScript.WORLD_STREET:
			return _street_palette(level_index)
		WorldCatalogScript.WORLD_STADIUM:
			return _stadium_palette(level_index)
		_:
			return _training_palette(level_index)


func _training_palette(level_index: int) -> Dictionary:
	var warm := level_index >= 7
	return {
		"sky": Color(0.46, 0.68, 0.9, 1.0) if not warm else Color(0.34, 0.56, 0.86, 1.0),
		"ambient": Color(0.92, 0.96, 1.0, 1.0),
		"ambient_energy": 0.82,
		"sun": Color(1.0, 0.98, 0.9, 1.0),
		"sun_energy": 1.58,
		"shadow_blur": 1.2,
		"exposure": 1.02,
		"field": Color(0.1, 0.54, 0.32, 1.0),
		"field_line": Color(0.92, 1.0, 0.9, 0.22),
		"static": Color(0.93, 0.3, 0.24, 1.0),
		"static_accent": Color(0.2, 0.55, 0.86, 1.0),
		"gate": Color(0.08, 0.76, 0.98, 1.0),
		"route": Color(1.0, 0.88, 0.2, 0.7),
		"bounce": Color(0.08, 0.9, 0.74, 1.0),
		"trim": Color(0.18, 0.78, 1.0, 1.0),
		"net": Color(0.9, 0.97, 1.0, 0.34),
		"backdrop": Color(0.12, 0.28, 0.22, 1.0),
		"backdrop_secondary": Color(0.18, 0.34, 0.28, 1.0),
		"banner": Color(0.96, 0.38, 0.28, 1.0),
		"seating": Color(0.16, 0.26, 0.22, 1.0),
		"pulse": Color(1.0, 0.92, 0.2, 1.0),
	}


func _street_palette(level_index: int) -> Dictionary:
	var dusk := level_index >= 17
	return {
		"sky": Color(0.42, 0.74, 0.92, 1.0) if not dusk else Color(0.24, 0.4, 0.72, 1.0),
		"ambient": Color(0.95, 0.9, 0.84, 1.0) if not dusk else Color(0.74, 0.84, 1.0, 1.0),
		"ambient_energy": 0.8,
		"sun": Color(1.0, 0.9, 0.7, 1.0) if not dusk else Color(0.92, 0.95, 1.0, 1.0),
		"sun_energy": 1.5 if not dusk else 1.36,
		"shadow_blur": 1.1,
		"exposure": 1.0,
		"field": Color(0.07, 0.46, 0.34, 1.0),
		"field_line": Color(1.0, 0.92, 0.7, 0.2),
		"static": Color(0.95, 0.32, 0.24, 1.0),
		"static_accent": Color(0.52, 0.3, 0.84, 1.0),
		"gate": Color(0.08, 0.78, 0.96, 1.0),
		"route": Color(1.0, 0.82, 0.16, 0.72),
		"bounce": Color(0.08, 0.88, 0.7, 1.0),
		"trim": Color(1.0, 0.72, 0.16, 1.0),
		"net": Color(0.94, 0.98, 1.0, 0.36),
		"backdrop": Color(0.18, 0.16, 0.22, 1.0),
		"backdrop_secondary": Color(0.28, 0.24, 0.3, 1.0),
		"banner": Color(1.0, 0.48, 0.22, 1.0),
		"seating": Color(0.22, 0.2, 0.26, 1.0),
		"pulse": Color(1.0, 0.78, 0.18, 1.0),
	}


func _stadium_palette(level_index: int) -> Dictionary:
	var finale := level_index >= 28
	return {
		"sky": Color(0.16, 0.28, 0.52, 1.0) if not finale else Color(0.12, 0.2, 0.42, 1.0),
		"ambient": Color(0.78, 0.86, 1.0, 1.0),
		"ambient_energy": 0.86,
		"sun": Color(1.0, 0.92, 0.72, 1.0),
		"sun_energy": 1.62,
		"shadow_blur": 1.25,
		"exposure": 0.98,
		"field": Color(0.05, 0.4, 0.28, 1.0),
		"field_line": Color(0.86, 1.0, 0.9, 0.24),
		"static": Color(0.94, 0.28, 0.3, 1.0),
		"static_accent": Color(0.28, 0.42, 0.86, 1.0),
		"gate": Color(0.14, 0.82, 1.0, 1.0),
		"route": Color(1.0, 0.84, 0.2, 0.74),
		"bounce": Color(0.12, 0.94, 0.74, 1.0),
		"trim": Color(0.96, 0.78, 0.28, 1.0),
		"net": Color(0.92, 0.97, 1.0, 0.38),
		"backdrop": Color(0.08, 0.12, 0.22, 1.0),
		"backdrop_secondary": Color(0.14, 0.18, 0.3, 1.0),
		"banner": Color(0.9, 0.24, 0.3, 1.0),
		"seating": Color(0.14, 0.18, 0.3, 1.0),
		"pulse": Color(1.0, 0.84, 0.22, 1.0),
	}


func _material(
	color: Color,
	roughness: float,
	emissive: bool = false,
	alpha: bool = false
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if alpha or color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0) * 0.38
	return material
