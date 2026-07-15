class_name NetboundLevelVisualPolish
extends Node3D

const VISUAL_GROUP := "netbound_visual_polish"

var _level: Node
var _definition: LevelDefinition
var _ball: RigidBody3D
var _goal_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _shadow: MeshInstance3D
var _active_tweens: Array[Tween] = []
var _palette: Dictionary = {}
var _quality_config: Dictionary = {
	"decorative_geometry_enabled": true,
	"contact_shadow_enabled": true,
	"dynamic_shadows_enabled": true,
}

const GOAL_FRAME_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const GOAL_FRAME_EMISSION := Color(0.08, 0.09, 0.1, 1.0)


func setup(level: Node) -> void:
	_level = level
	_definition = level.get("level_definition") as LevelDefinition
	_ball = level.get_node_or_null("Ball") as RigidBody3D
	name = "LevelVisualPolish"
	add_to_group(VISUAL_GROUP)
	_palette = _palette_for_level(_level_index())
	_apply_environment()
	_apply_material_language()
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
	var pulse_emission: Color = _palette.get("pulse", Color(1.0, 0.92, 0.25, 1.0))
	tween.tween_property(_goal_material, "emission", pulse_emission, 0.08)
	tween.tween_interval(0.16)
	tween.tween_property(_goal_material, "emission", base_emission, 0.32)
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
	return {
		"visual_nodes": visual_nodes,
		"collision_nodes": collision_nodes,
		"active_tweens": _active_tweens.size(),
		"quality": _quality_config.duplicate(true),
	}


func apply_quality_settings(config: Dictionary) -> void:
	_quality_config = config.duplicate(true)
	_apply_quality_settings_to_nodes()


func _apply_environment() -> void:
	var environment_node := _level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if environment_node:
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = _palette.get("sky", Color(0.42, 0.58, 0.82, 1.0))
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = _palette.get("ambient", Color(0.85, 0.9, 1.0, 1.0))
		environment.ambient_light_energy = 0.72
		environment_node.environment = environment

	var sun := _level.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.light_color = _palette.get("sun", Color(1.0, 0.96, 0.86, 1.0))
		sun.light_energy = float(_palette.get("sun_energy", 1.55))
		sun.shadow_enabled = bool(_quality_config.get("dynamic_shadows_enabled", true))


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
		return clampi(int(parts[-1]), 1, 20)
	return 1


func _palette_for_level(level_index: int) -> Dictionary:
	if level_index <= 3:
		return {
			"sky": Color(0.42, 0.64, 0.86, 1.0),
			"ambient": Color(0.9, 0.96, 1.0, 1.0),
			"sun": Color(1.0, 0.98, 0.88, 1.0),
			"sun_energy": 1.55,
			"field": Color(0.08, 0.52, 0.31, 1.0),
			"field_line": Color(0.78, 1.0, 0.78, 0.18),
			"goal": Color(0.94, 1.0, 1.0, 1.0),
			"goal_emission": Color(0.16, 0.38, 0.58, 1.0),
			"static": Color(0.93, 0.28, 0.23, 1.0),
			"gate": Color(0.07, 0.72, 1.0, 1.0),
			"route": Color(1.0, 0.9, 0.24, 0.68),
			"bounce": Color(0.08, 0.9, 0.72, 1.0),
			"trim": Color(0.15, 0.78, 1.0, 1.0),
			"net": Color(0.82, 0.94, 1.0, 0.25),
			"backdrop": Color(0.08, 0.18, 0.26, 1.0),
			"pulse": Color(1.0, 0.96, 0.24, 1.0),
		}
	if level_index <= 6:
		return {
			"sky": Color(0.66, 0.46, 0.36, 1.0),
			"ambient": Color(0.98, 0.82, 0.64, 1.0),
			"sun": Color(1.0, 0.78, 0.5, 1.0),
			"sun_energy": 1.42,
			"field": Color(0.06, 0.43, 0.36, 1.0),
			"field_line": Color(1.0, 0.82, 0.42, 0.17),
			"goal": Color(1.0, 0.95, 0.84, 1.0),
			"goal_emission": Color(0.48, 0.22, 0.08, 1.0),
			"static": Color(0.78, 0.18, 0.34, 1.0),
			"gate": Color(1.0, 0.5, 0.18, 1.0),
			"route": Color(0.35, 1.0, 0.65, 0.7),
			"bounce": Color(0.1, 0.9, 0.85, 1.0),
			"trim": Color(1.0, 0.62, 0.2, 1.0),
			"net": Color(1.0, 0.9, 0.72, 0.24),
			"backdrop": Color(0.23, 0.13, 0.14, 1.0),
			"pulse": Color(0.35, 1.0, 0.62, 1.0),
		}
	if level_index <= 9:
		return {
			"sky": Color(0.06, 0.1, 0.15, 1.0),
			"ambient": Color(0.45, 0.78, 0.86, 1.0),
			"sun": Color(0.62, 0.95, 1.0, 1.0),
			"sun_energy": 1.25,
			"field": Color(0.025, 0.23, 0.2, 1.0),
			"field_line": Color(0.28, 1.0, 0.86, 0.2),
			"goal": Color(0.85, 1.0, 0.96, 1.0),
			"goal_emission": Color(0.0, 0.55, 0.68, 1.0),
			"static": Color(0.95, 0.18, 0.42, 1.0),
			"gate": Color(0.0, 0.88, 1.0, 1.0),
			"route": Color(1.0, 0.82, 0.16, 0.72),
			"bounce": Color(0.2, 1.0, 0.54, 1.0),
			"trim": Color(0.95, 0.23, 0.8, 1.0),
			"net": Color(0.6, 1.0, 0.95, 0.22),
			"backdrop": Color(0.045, 0.075, 0.12, 1.0),
			"pulse": Color(1.0, 0.35, 0.9, 1.0),
		}
	if level_index <= 14:
		return {
			"sky": Color(0.34, 0.72, 0.91, 1.0),
			"ambient": Color(0.92, 0.98, 1.0, 1.0),
			"sun": Color(1.0, 0.96, 0.78, 1.0),
			"sun_energy": 1.52,
			"field": Color(0.08, 0.5, 0.31, 1.0),
			"field_line": Color(0.88, 1.0, 0.78, 0.2),
			"static": Color(0.96, 0.3, 0.23, 1.0),
			"static_accent": Color(0.5, 0.3, 0.84, 1.0),
			"gate": Color(0.05, 0.7, 0.95, 1.0),
			"route": Color(1.0, 0.84, 0.16, 0.72),
			"bounce": Color(0.05, 0.86, 0.68, 1.0),
			"trim": Color(1.0, 0.78, 0.12, 1.0),
			"net": Color(0.9, 0.97, 1.0, 0.3),
			"backdrop": Color(0.08, 0.22, 0.34, 1.0),
			"pulse": Color(1.0, 0.82, 0.12, 1.0),
		}
	if level_index <= 17:
		return {
			"sky": Color(0.94, 0.57, 0.48, 1.0),
			"ambient": Color(1.0, 0.88, 0.76, 1.0),
			"sun": Color(1.0, 0.88, 0.62, 1.0),
			"sun_energy": 1.48,
			"field": Color(0.04, 0.43, 0.38, 1.0),
			"field_line": Color(1.0, 0.9, 0.62, 0.2),
			"static": Color(0.9, 0.24, 0.32, 1.0),
			"static_accent": Color(0.48, 0.25, 0.76, 1.0),
			"gate": Color(0.1, 0.76, 0.96, 1.0),
			"route": Color(1.0, 0.85, 0.2, 0.72),
			"bounce": Color(0.08, 0.88, 0.72, 1.0),
			"trim": Color(1.0, 0.69, 0.16, 1.0),
			"net": Color(1.0, 0.96, 0.9, 0.28),
			"backdrop": Color(0.25, 0.13, 0.22, 1.0),
			"pulse": Color(0.32, 1.0, 0.78, 1.0),
		}
	if level_index <= 19:
		return {
			"sky": Color(0.22, 0.39, 0.72, 1.0),
			"ambient": Color(0.72, 0.86, 1.0, 1.0),
			"sun": Color(0.92, 0.96, 1.0, 1.0),
			"sun_energy": 1.38,
			"field": Color(0.04, 0.34, 0.32, 1.0),
			"field_line": Color(0.58, 1.0, 0.88, 0.22),
			"static": Color(0.95, 0.27, 0.33, 1.0),
			"static_accent": Color(0.58, 0.32, 0.88, 1.0),
			"gate": Color(0.06, 0.8, 1.0, 1.0),
			"route": Color(1.0, 0.84, 0.18, 0.74),
			"bounce": Color(0.12, 0.94, 0.7, 1.0),
			"trim": Color(0.96, 0.72, 0.16, 1.0),
			"net": Color(0.82, 0.94, 1.0, 0.28),
			"backdrop": Color(0.07, 0.12, 0.25, 1.0),
			"pulse": Color(1.0, 0.82, 0.18, 1.0),
		}
	return {
		"sky": Color(0.18, 0.38, 0.72, 1.0),
		"ambient": Color(0.82, 0.9, 1.0, 1.0),
		"sun": Color(1.0, 0.9, 0.62, 1.0),
		"sun_energy": 1.58,
		"field": Color(0.045, 0.38, 0.3, 1.0),
		"field_line": Color(0.72, 1.0, 0.84, 0.22),
		"static": Color(0.96, 0.25, 0.29, 1.0),
		"static_accent": Color(0.56, 0.28, 0.84, 1.0),
		"gate": Color(0.12, 0.82, 1.0, 1.0),
		"route": Color(1.0, 0.82, 0.14, 0.75),
		"bounce": Color(0.12, 0.95, 0.72, 1.0),
		"trim": Color(1.0, 0.7, 0.14, 1.0),
		"net": Color(0.86, 0.95, 1.0, 0.3),
		"backdrop": Color(0.06, 0.12, 0.25, 1.0),
		"pulse": Color(1.0, 0.82, 0.14, 1.0),
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
		material.emission = Color(color.r, color.g, color.b, 1.0) * 0.45
	return material
