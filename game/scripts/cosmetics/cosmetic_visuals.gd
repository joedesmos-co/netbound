class_name CosmeticVisuals
extends RefCounted

const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const BallTrailScript := preload("res://scripts/cosmetics/ball_trail.gd")

const GOAL_EFFECT_GROUP := "netbound_cosmetic_goal_effect"


static func apply_to_ball(ball: RigidBody3D, ball_skin_id: String, trail_id: String) -> void:
	if not ball:
		return
	apply_ball_skin(ball, ball_skin_id)
	apply_ball_trail(ball, trail_id)


static func apply_ball_skin(ball: RigidBody3D, ball_skin_id: String) -> void:
	if not ball:
		return
	var skin_id := CosmeticRegistryScript.normalize_id_for_category(
		CosmeticRegistryScript.CATEGORY_BALL,
		ball_skin_id
	)
	var main_mesh := ball.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var band := ball.get_node_or_null("Band") as MeshInstance3D
	var patch_front := ball.get_node_or_null("PatchFront") as MeshInstance3D
	var patch_back := ball.get_node_or_null("PatchBack") as MeshInstance3D
	if not main_mesh:
		return

	var main_material := _ball_main_material(skin_id)
	var accent_material := _ball_accent_material(skin_id)
	main_mesh.material_override = main_material
	for accent in [band, patch_front, patch_back]:
		if accent:
			accent.visible = true
			accent.material_override = accent_material


static func apply_ball_trail(ball: RigidBody3D, trail_id: String) -> void:
	if not ball:
		return
	var trail = ball.get_node_or_null("NetboundBallTrail")
	if not trail:
		trail = BallTrailScript.new()
		ball.add_child(trail)
	trail.configure(trail_id)


static func reset_ball_trail(ball: RigidBody3D) -> void:
	var trail = ball.get_node_or_null("NetboundBallTrail") if ball else null
	if trail:
		trail.reset_trail()


static func trigger_goal_effect(
	level_root: Node,
	goal_root: Node3D,
	goal_flash: ColorRect,
	goal_particles: CPUParticles3D,
	goal_effect_id: String
) -> void:
	if not level_root:
		return
	var effect_id := CosmeticRegistryScript.normalize_id_for_category(
		CosmeticRegistryScript.CATEGORY_GOAL_EFFECT,
		goal_effect_id
	)
	clear_goal_effects(level_root)
	_configure_goal_flash(goal_flash, effect_id)
	_configure_goal_particles(goal_particles, effect_id)
	if goal_particles:
		goal_particles.restart()
		goal_particles.emitting = true
	if effect_id == "goal_confetti":
		_spawn_confetti(level_root, goal_root)
	elif effect_id == "goal_shockwave":
		_spawn_shockwave(level_root, goal_root)


static func clear_goal_effects(level_root: Node) -> void:
	if not level_root:
		return
	for child in level_root.find_children("*", "", true, false):
		if child.is_in_group(GOAL_EFFECT_GROUP):
			child.queue_free()


static func _ball_main_material(skin_id: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.36
	match skin_id:
		"ball_neon":
			material.albedo_color = Color(0.025, 0.045, 0.06, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.0, 0.28, 0.34, 1.0)
		"ball_fire":
			material.albedo_color = Color(1.0, 0.24, 0.04, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.85, 0.16, 0.02, 1.0)
		"ball_ice":
			material.albedo_color = Color(0.76, 0.94, 1.0, 0.92)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.emission_enabled = true
			material.emission = Color(0.12, 0.38, 0.58, 1.0)
		"ball_galaxy":
			material.albedo_color = Color(0.055, 0.035, 0.13, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.18, 0.08, 0.42, 1.0)
		"ball_gold":
			material.albedo_color = Color(1.0, 0.68, 0.16, 1.0)
			material.metallic = 0.72
			material.roughness = 0.22
			material.emission_enabled = true
			material.emission = Color(0.28, 0.16, 0.02, 1.0)
		_:
			material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.16, 0.16, 0.16, 1.0)
	return material


static func _ball_accent_material(skin_id: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.42
	match skin_id:
		"ball_neon":
			material.albedo_color = Color(0.0, 0.96, 1.0, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.0, 0.8, 1.0, 1.0)
		"ball_fire":
			material.albedo_color = Color(0.18, 0.02, 0.0, 1.0)
			material.emission_enabled = true
			material.emission = Color(1.0, 0.36, 0.05, 1.0)
		"ball_ice":
			material.albedo_color = Color(0.2, 0.62, 0.9, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.06, 0.38, 0.55, 1.0)
		"ball_galaxy":
			material.albedo_color = Color(0.86, 0.88, 1.0, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.7, 0.55, 1.0, 1.0)
		"ball_gold":
			material.albedo_color = Color(0.18, 0.12, 0.025, 1.0)
			material.metallic = 0.4
			material.emission_enabled = true
			material.emission = Color(0.75, 0.42, 0.04, 1.0)
		_:
			material.albedo_color = Color(0.035, 0.035, 0.035, 1.0)
	return material


static func _configure_goal_flash(goal_flash: ColorRect, effect_id: String) -> void:
	if not goal_flash:
		return
	match effect_id:
		"goal_confetti":
			goal_flash.color = Color(0.2, 1.0, 0.55, 1.0)
		"goal_shockwave":
			goal_flash.color = Color(0.22, 0.82, 1.0, 1.0)
		_:
			goal_flash.color = Color(1.0, 0.9, 0.22, 1.0)


static func _configure_goal_particles(goal_particles: CPUParticles3D, effect_id: String) -> void:
	if not goal_particles:
		return
	match effect_id:
		"goal_confetti":
			goal_particles.amount = 96
			goal_particles.lifetime = 0.95
			goal_particles.color = Color(0.55, 1.0, 0.72, 1.0)
			goal_particles.initial_velocity_min = 2.2
			goal_particles.initial_velocity_max = 5.8
		"goal_shockwave":
			goal_particles.amount = 48
			goal_particles.lifetime = 0.55
			goal_particles.color = Color(0.25, 0.9, 1.0, 1.0)
			goal_particles.initial_velocity_min = 1.5
			goal_particles.initial_velocity_max = 3.0
		_:
			goal_particles.amount = 64
			goal_particles.lifetime = 0.8
			goal_particles.color = Color(1.0, 0.9, 0.2, 1.0)
			goal_particles.initial_velocity_min = 2.0
			goal_particles.initial_velocity_max = 5.0


static func _spawn_confetti(level_root: Node, goal_root: Node3D) -> void:
	var origin := _goal_effect_origin(goal_root)
	var container := Node3D.new()
	container.name = "NetboundConfettiEffect"
	container.add_to_group(GOAL_EFFECT_GROUP)
	level_root.add_child(container)
	container.global_position = origin
	var colors := [
		Color(1.0, 0.2, 0.24, 1.0),
		Color(0.2, 0.78, 1.0, 1.0),
		Color(1.0, 0.9, 0.16, 1.0),
		Color(0.32, 1.0, 0.5, 1.0),
		Color(0.95, 0.35, 1.0, 1.0),
	]
	for i in 24:
		var piece := MeshInstance3D.new()
		piece.name = "Confetti%02d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.16, 0.035, 0.09)
		piece.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = colors[i % colors.size()]
		material.emission_enabled = true
		material.emission = Color(material.albedo_color.r, material.albedo_color.g, material.albedo_color.b, 1.0) * 0.45
		piece.material_override = material
		container.add_child(piece)
		piece.position = Vector3.ZERO
		piece.rotation = Vector3(i * 0.37, i * 0.19, i * 0.51)
		var x := sin(float(i) * 2.31) * 4.0
		var y := 1.2 + fposmod(float(i) * 0.73, 2.8)
		var z := cos(float(i) * 1.83) * 1.8
		var tween := container.create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "position", Vector3(x, y, z), 0.85)
		tween.tween_property(piece, "rotation", piece.rotation + Vector3(4.0, 2.0, 3.0), 0.85)
	var cleanup := container.create_tween()
	cleanup.tween_interval(1.05)
	cleanup.tween_callback(container.queue_free)


static func _spawn_shockwave(level_root: Node, goal_root: Node3D) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "NetboundShockwaveEffect"
	ring.add_to_group(GOAL_EFFECT_GROUP)
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.92
	mesh.outer_radius = 1.08
	mesh.ring_segments = 48
	mesh.rings = 8
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.9, 1.0, 0.62)
	material.emission_enabled = true
	material.emission = Color(0.18, 0.78, 1.0, 1.0)
	ring.material_override = material
	level_root.add_child(ring)
	ring.global_position = _goal_effect_origin(goal_root)
	ring.rotation_degrees.x = 90.0
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 7.5, 0.65)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.65)
	tween.chain().tween_callback(ring.queue_free)


static func _goal_effect_origin(goal_root: Node3D) -> Vector3:
	if goal_root:
		return goal_root.global_position + Vector3(0.0, 3.6, 0.35)
	return Vector3(0.0, 3.6, -10.0)
