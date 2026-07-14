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
var _goal_particles: CPUParticles3D
var _time: float = 0.0
var _last_ball_position: Vector3 = Vector3.ZERO
var _goal_effect_timer: float = 0.0


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
	if _goal_particles:
		_goal_particles.emitting = false
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
		_goal_effect_timer -= delta
		if _goal_effect_timer <= 0.0:
			_trigger_goal_preview()


func _build_preview_world() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_world = Node3D.new()
	_world.name = "PreviewWorld"
	_viewport.add_child(_world)

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
	ground_material.albedo_color = Color(0.04, 0.12, 0.15, 1.0)
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

	_goal_particles = CPUParticles3D.new()
	_goal_particles.name = "PreviewGoalParticles"
	_goal_particles.position = Vector3(0.0, 1.35, 0.08)
	_goal_particles.emitting = false
	_goal_particles.one_shot = true
	_goal_particles.explosiveness = 0.9
	_goal_particles.spread = 70.0
	_goal_particles.gravity = Vector3(0.0, -2.8, 0.0)
	_goal_root.add_child(_goal_particles)


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
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.18, 0.18, 0.18, 1.0)
	for x in [-1.45, 1.45]:
		var post := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.045
		mesh.bottom_radius = 0.045
		mesh.height = 1.8
		post.mesh = mesh
		post.material_override = material
		post.position = Vector3(x, 0.9, 0.0)
		parent_goal.add_child(post)
	var crossbar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(2.95, 0.07, 0.07)
	crossbar.mesh = bar_mesh
	crossbar.material_override = material
	crossbar.position = Vector3(0.0, 1.8, 0.0)
	parent_goal.add_child(crossbar)


func _reset_preview_ball() -> void:
	_ball.global_position = Vector3(0.0, 0.62, 0.0)
	_ball.linear_velocity = Vector3.ZERO
	_last_ball_position = _ball.global_position


func _trigger_goal_preview() -> void:
	_goal_effect_timer = 1.45
	CosmeticVisualsScript.trigger_goal_effect(
		_world,
		_goal_root,
		null,
		_goal_particles,
		current_cosmetic_id
	)
