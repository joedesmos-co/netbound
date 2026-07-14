class_name NetboundCosmeticPreview
extends SubViewportContainer

const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const CosmeticVisualsScript := preload("res://scripts/cosmetics/cosmetic_visuals.gd")

var current_category: String = CosmeticRegistryScript.CATEGORY_BALL
var current_cosmetic_id: String = "ball_classic"
var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _ball: RigidBody3D
var _goal_root: Node3D
var _goal_material: StandardMaterial3D
var _goal_preview_ring: MeshInstance3D
var _goal_preview_ring_material: StandardMaterial3D
var _goal_preview_pieces: Array[MeshInstance3D] = []
var _time: float = 0.0
var _last_ball_position: Vector3 = Vector3.ZERO
var _goal_effect_timer: float = 0.0
var _goal_effect_age: float = 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(360.0, 260.0)
	stretch = true
	_build_preview_world()
	set_preview(CosmeticRegistryScript.CATEGORY_BALL, "ball_classic")


func set_preview(category: String, cosmetic_id: String) -> void:
	current_category = category
	current_cosmetic_id = cosmetic_id
	_goal_effect_timer = 0.0
	if not is_node_ready():
		return
	var skin_id := "ball_classic"
	var trail_id := "trail_none"
	match category:
		CosmeticRegistryScript.CATEGORY_BALL:
			skin_id = cosmetic_id
		CosmeticRegistryScript.CATEGORY_TRAIL:
			trail_id = cosmetic_id
		CosmeticRegistryScript.CATEGORY_GOAL_EFFECT:
			skin_id = "ball_classic"
		_:
			pass
	CosmeticVisualsScript.apply_to_ball(_ball, skin_id, trail_id)
	CosmeticVisualsScript.clear_goal_effects(_world)
	_hide_goal_preview_effect()
	_reset_preview_ball()
	if category == CosmeticRegistryScript.CATEGORY_GOAL_EFFECT:
		_trigger_goal_preview()


func _process(delta: float) -> void:
	if not _ball:
		return
	_time += delta
	_ball.rotation_degrees.y += delta * 52.0
	_ball.rotation_degrees.x += delta * 24.0
	if current_category == CosmeticRegistryScript.CATEGORY_TRAIL:
		var next_position := Vector3(sin(_time * 2.2) * 1.4, 0.62, cos(_time * 2.2) * 0.18)
		_ball.linear_velocity = (next_position - _last_ball_position) / maxf(delta, 0.001)
		_ball.global_position = next_position
		_last_ball_position = next_position
	else:
		_ball.linear_velocity = Vector3.ZERO
		_ball.global_position = Vector3(0.0, 0.62, 0.0)
		_last_ball_position = _ball.global_position

	if current_category == CosmeticRegistryScript.CATEGORY_GOAL_EFFECT:
		_update_goal_preview(delta)
		_goal_effect_timer -= delta
		if _goal_effect_timer <= 0.0:
			_trigger_goal_preview()


func _build_preview_world() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_world = Node3D.new()
	_world.name = "PreviewWorld"
	_viewport.add_child(_world)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = NetboundUITheme.SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.65
	world_environment.environment = environment
	_world.add_child(world_environment)

	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.position = Vector3(0.0, 2.3, 5.0)
	_world.add_child(_camera)
	_camera.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)
	_camera.fov = 48.0
	_camera.current = true

	var light := DirectionalLight3D.new()
	light.name = "PreviewLight"
	light.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	light.light_energy = 1.8
	_world.add_child(light)

	var ground := MeshInstance3D.new()
	ground.name = "PreviewGround"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(5.0, 0.04, 2.4)
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = NetboundUITheme.GRASS
	ground_material.roughness = 0.9
	ground.material_override = ground_material
	ground.position = Vector3(0.0, -0.03, 0.0)
	_world.add_child(ground)

	_ball = RigidBody3D.new()
	_ball.name = "PreviewBall"
	_ball.freeze = true
	_ball.mass = 0.43
	_world.add_child(_ball)
	_add_ball_visual_children(_ball)

	_goal_root = Node3D.new()
	_goal_root.name = "PreviewGoal"
	_goal_root.position = Vector3(0.0, 0.0, -1.3)
	_world.add_child(_goal_root)
	_add_goal_preview_geometry(_goal_root)
	_add_goal_preview_effects(_goal_root)


func _add_ball_visual_children(parent_ball: RigidBody3D) -> void:
	var main := MeshInstance3D.new()
	main.name = "MeshInstance3D"
	var sphere := SphereMesh.new()
	sphere.radius = 0.49
	sphere.height = 0.98
	main.mesh = sphere
	parent_ball.add_child(main)

	var band := MeshInstance3D.new()
	band.name = "Band"
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.5
	band_mesh.bottom_radius = 0.5
	band_mesh.height = 0.09
	band.mesh = band_mesh
	band.rotation_degrees.x = 90.0
	parent_ball.add_child(band)

	for patch_name in ["PatchFront", "PatchBack"]:
		var patch := MeshInstance3D.new()
		patch.name = patch_name
		var patch_mesh := BoxMesh.new()
		patch_mesh.size = Vector3(0.21, 0.14, 0.06)
		patch.mesh = patch_mesh
		patch.position = Vector3(0.0, 0.09 if patch_name == "PatchFront" else -0.09, 0.44 if patch_name == "PatchFront" else -0.44)
		parent_ball.add_child(patch)


func _add_goal_preview_geometry(parent_goal: Node3D) -> void:
	_goal_material = StandardMaterial3D.new()
	_goal_material.albedo_color = Color.WHITE
	_goal_material.emission_enabled = true
	_goal_material.emission = Color(0.18, 0.18, 0.18, 1.0)
	for x in [-1.45, 1.45]:
		var post := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.045
		mesh.bottom_radius = 0.045
		mesh.height = 1.8
		post.mesh = mesh
		post.material_override = _goal_material
		post.position = Vector3(x, 0.9, 0.0)
		parent_goal.add_child(post)
	var crossbar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(2.95, 0.07, 0.07)
	crossbar.mesh = bar_mesh
	crossbar.material_override = _goal_material
	crossbar.position = Vector3(0.0, 1.8, 0.0)
	parent_goal.add_child(crossbar)


func _add_goal_preview_effects(parent_goal: Node3D) -> void:
	_goal_preview_ring = MeshInstance3D.new()
	_goal_preview_ring.name = "PreviewCelebrationRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.88
	ring_mesh.outer_radius = 1.02
	ring_mesh.ring_segments = 28
	ring_mesh.rings = 6
	_goal_preview_ring.mesh = ring_mesh
	_goal_preview_ring.position = Vector3(0.0, 0.92, 0.12)
	_goal_preview_ring.rotation_degrees.x = 90.0
	_goal_preview_ring_material = StandardMaterial3D.new()
	_goal_preview_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_goal_preview_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_goal_preview_ring_material.albedo_color = Color(NetboundUITheme.CURVE, 0.0)
	_goal_preview_ring.material_override = _goal_preview_ring_material
	parent_goal.add_child(_goal_preview_ring)

	for index in 12:
		var piece := MeshInstance3D.new()
		piece.name = "PreviewCelebrationPiece%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.055, 0.055)
		piece.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		piece.material_override = material
		parent_goal.add_child(piece)
		_goal_preview_pieces.append(piece)
	_hide_goal_preview_effect()


func _reset_preview_ball() -> void:
	_ball.global_position = Vector3(0.0, 0.62, 0.0)
	_ball.linear_velocity = Vector3.ZERO
	_last_ball_position = _ball.global_position


func _trigger_goal_preview() -> void:
	_goal_effect_timer = 1.45
	_goal_effect_age = 0.0
	var colors := _goal_preview_colors()
	for index in _goal_preview_pieces.size():
		var piece := _goal_preview_pieces[index]
		piece.visible = current_cosmetic_id not in ["goal_shockwave", "goal_portal"] or index < 6
		var material := piece.material_override as StandardMaterial3D
		material.albedo_color = colors[index % colors.size()]
	_goal_preview_ring.visible = current_cosmetic_id in ["goal_shockwave", "goal_supporter", "goal_fireworks", "goal_portal"]


func _update_goal_preview(delta: float) -> void:
	_goal_effect_age += delta
	var progress := clampf(_goal_effect_age / 0.78, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	for index in _goal_preview_pieces.size():
		var piece := _goal_preview_pieces[index]
		if not piece.visible:
			continue
		var angle := TAU * float(index) / float(_goal_preview_pieces.size())
		var radius := lerpf(0.18, 1.75, eased)
		piece.position = Vector3(
			cos(angle) * radius,
			0.95 + sin(angle * 2.0) * radius * 0.42 + eased * 0.42,
			0.12 + sin(angle) * 0.12
		)
		piece.rotation_degrees = Vector3(index * 19.0, eased * 220.0, index * 31.0)
		piece.scale = Vector3.ONE * (1.0 - progress * 0.55)
	if _goal_preview_ring.visible:
		_goal_preview_ring.scale = Vector3.ONE * lerpf(0.42, 2.15, eased)
		var ring_color := _goal_preview_colors()[0]
		ring_color.a = 0.72 * (1.0 - progress)
		_goal_preview_ring_material.albedo_color = ring_color
	# The goal stays recognizably white; celebration energy only changes its brightness.
	var pulse := sin(progress * PI) * 0.22
	_goal_material.emission = Color(0.18 + pulse, 0.18 + pulse, 0.18 + pulse, 1.0)
	if progress >= 1.0:
		_hide_goal_preview_effect()


func _hide_goal_preview_effect() -> void:
	for piece in _goal_preview_pieces:
		piece.visible = false
	if _goal_preview_ring:
		_goal_preview_ring.visible = false
	if _goal_material:
		_goal_material.albedo_color = Color.WHITE
		_goal_material.emission = Color(0.18, 0.18, 0.18, 1.0)


func _goal_preview_colors() -> Array[Color]:
	match current_cosmetic_id:
		"goal_confetti":
			return [
				NetboundUITheme.CORAL,
				NetboundUITheme.SIGNAL,
				NetboundUITheme.CURVE,
				NetboundUITheme.SUCCESS,
			]
		"goal_shockwave":
			return [NetboundUITheme.CURVE, Color("b8f4ff")]
		"goal_supporter":
			return [NetboundUITheme.SUCCESS, NetboundUITheme.SIGNAL]
		"goal_ribbons":
			return [NetboundUITheme.CORAL, NetboundUITheme.SIGNAL, NetboundUITheme.CHALK]
		"goal_splash":
			return [NetboundUITheme.SUCCESS, NetboundUITheme.CURVE, NetboundUITheme.CHALK]
		"goal_fireworks":
			return [NetboundUITheme.SIGNAL, NetboundUITheme.CORAL, NetboundUITheme.CURVE]
		"goal_portal":
			return [Color("8c58ff"), NetboundUITheme.CURVE]
		_:
			return [NetboundUITheme.SIGNAL, NetboundUITheme.CHALK]
