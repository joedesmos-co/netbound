class_name CosmeticVisuals
extends RefCounted

const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const BallTrailScript := preload("res://scripts/cosmetics/ball_trail.gd")

const GOAL_EFFECT_GROUP := "netbound_cosmetic_goal_effect"
const BALL_ATTACHMENT_NAME := "NetboundBallVisualAttachments"

static var _ball_main_material_cache: Dictionary = {}
static var _ball_accent_material_cache: Dictionary = {}
static var _ball_detail_material_cache: Dictionary = {}
static var _ball_detail_mesh_cache: Dictionary = {}
static var _classic_patch_mesh: CylinderMesh


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
	_clear_ball_visual_attachments(ball)
	for accent in [band, patch_front, patch_back]:
		if accent:
			accent.visible = false
			accent.material_override = accent_material
	_add_ball_concept(ball, skin_id, accent_material)


static func _clear_ball_visual_attachments(ball: RigidBody3D) -> void:
	var attachments := ball.get_node_or_null(BALL_ATTACHMENT_NAME)
	if attachments:
		attachments.free()


static func _add_ball_concept(
	ball: RigidBody3D,
	skin_id: String,
	accent_material: StandardMaterial3D
) -> void:
	var attachments := Node3D.new()
	attachments.name = BALL_ATTACHMENT_NAME
	attachments.set_meta("cosmetic_id", skin_id)
	attachments.set_meta("concept", _ball_concept_name(skin_id))
	attachments.set_meta("visual_radius", 0.66)
	ball.add_child(attachments)

	match skin_id:
		"ball_classic":
			_add_soccer_panels(attachments, accent_material, 0.12)
		"ball_neon":
			_add_soccer_panels(attachments, accent_material, 0.105)
			_add_ring(attachments, "NeonLane", accent_material, Vector3(18.0, 0.0, 28.0), Vector3.ONE)
		"ball_fire":
			_add_soccer_panels(attachments, accent_material, 0.11)
			_add_radial_marks(attachments, accent_material, 6, "ember")
		"ball_ice":
			_add_soccer_panels(attachments, accent_material, 0.09)
			_add_axis_facets(attachments, accent_material, "ice")
		"ball_galaxy":
			_add_ring(attachments, "GalaxyOrbitA", accent_material, Vector3(24.0, 8.0, 0.0), Vector3(1.08, 1.08, 1.08))
			_add_ring(attachments, "GalaxyOrbitB", _detail_material(skin_id, "orbit", Color("ff86e8"), 0.75), Vector3(-20.0, 48.0, 12.0), Vector3(0.92, 0.92, 0.92))
			_add_radial_marks(attachments, _detail_material(skin_id, "stars", Color.WHITE, 0.9), 9, "stars")
		"ball_champion":
			_add_ring(attachments, "ChampionMedal", accent_material, Vector3(0.0, 0.0, 0.0), Vector3(1.08, 1.08, 1.08))
			_add_crown_fins(attachments, accent_material)
		"ball_gold":
			_add_soccer_panels(attachments, accent_material, 0.105)
			_add_ring(attachments, "GoldLatitudeA", accent_material, Vector3(0.0, 0.0, 0.0), Vector3(1.02, 1.02, 1.02))
			_add_ring(attachments, "GoldLatitudeB", accent_material, Vector3(90.0, 0.0, 0.0), Vector3(1.02, 1.02, 1.02))
		"ball_supporter":
			_add_ring(attachments, "SupporterRingA", accent_material, Vector3(28.0, 0.0, 18.0), Vector3(1.04, 1.04, 1.04))
			_add_ring(attachments, "SupporterRingB", _detail_material(skin_id, "teal", Color("45f3c4"), 0.55), Vector3(-28.0, 38.0, 0.0), Vector3(0.92, 0.92, 0.92))
			_add_crown_fins(attachments, accent_material, 2)
		"ball_candy":
			_add_ring(attachments, "CandySpiralA", accent_material, Vector3(28.0, 12.0, 0.0), Vector3(1.02, 1.02, 1.02))
			_add_ring(attachments, "CandySpiralB", accent_material, Vector3(-28.0, 52.0, 14.0), Vector3(1.02, 1.02, 1.02))
			_add_ring(attachments, "CandySpiralC", accent_material, Vector3(62.0, 18.0, 36.0), Vector3(0.9, 0.9, 0.9))
			_add_radial_marks(attachments, accent_material, 8, "candy")
		"ball_mint":
			_add_radial_marks(attachments, accent_material, 11, "chips")
		"ball_watermelon":
			_add_ring(attachments, "WatermelonRind", accent_material, Vector3.ZERO, Vector3(1.08, 1.08, 1.08))
			_add_radial_marks(attachments, _detail_material(skin_id, "seeds", Color("351525"), 0.0), 10, "seeds")
		"ball_sunset":
			_add_ring(attachments, "SunsetArcA", accent_material, Vector3(14.0, 0.0, 18.0), Vector3(1.05, 1.05, 1.05))
			_add_ring(attachments, "SunsetArcB", _detail_material(skin_id, "sun", Color("ffd13d"), 0.55), Vector3(-24.0, 40.0, 8.0), Vector3(0.94, 0.94, 0.94))
			_add_surface_disc(attachments, "SunDisc", Vector3(0.0, 0.25, 0.97).normalized(), 0.14, _detail_material(skin_id, "sun", Color("ffd13d"), 0.55), 20)
		"ball_checker":
			_add_radial_marks(attachments, accent_material, 12, "checks")
		"ball_cloud":
			_add_cloud_puffs(attachments, accent_material)
		"ball_comet":
			_add_ring(attachments, "CometStrike", accent_material, Vector3(26.0, 0.0, 34.0), Vector3(1.05, 1.05, 1.05))
			_add_comet_fins(attachments, accent_material)
		"ball_lava":
			_add_radial_marks(attachments, accent_material, 9, "lava")
		"ball_prism":
			_add_axis_facets(attachments, accent_material, "prism")
			_add_ring(attachments, "PrismSpectrum", _detail_material(skin_id, "spectrum", Color("ff72cb"), 0.7), Vector3(32.0, 42.0, 0.0), Vector3(0.95, 0.95, 0.95))
		"ball_void":
			_add_ring(attachments, "VoidHorizonA", accent_material, Vector3(18.0, 0.0, 30.0), Vector3(1.12, 1.12, 1.12))
			_add_ring(attachments, "VoidHorizonB", _detail_material(skin_id, "horizon", Color("e45cff"), 0.9), Vector3(-24.0, 48.0, 8.0), Vector3(0.92, 0.92, 0.92))
			_add_radial_marks(attachments, _detail_material(skin_id, "satellites", Color("8cecff"), 0.9), 4, "satellites")


static func _add_soccer_panels(
	attachments: Node3D,
	material: StandardMaterial3D,
	radius: float
) -> void:
	var normals: Array[Vector3] = [
		Vector3(0.0, 0.0, 1.0),
		Vector3(0.0, 0.0, -1.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, -1.0, 0.0),
		Vector3(0.82, 0.28, 0.5).normalized(),
		Vector3(-0.82, 0.28, 0.5).normalized(),
		Vector3(0.72, -0.42, -0.54).normalized(),
		Vector3(-0.72, -0.42, -0.54).normalized(),
	]
	for index in normals.size():
		_add_surface_disc(
			attachments,
			"SoccerPanel%02d" % index,
			normals[index],
			radius,
			material,
			5
		)


static func _get_classic_patch_mesh() -> CylinderMesh:
	if _classic_patch_mesh:
		return _classic_patch_mesh
	_classic_patch_mesh = CylinderMesh.new()
	_classic_patch_mesh.top_radius = 0.12
	_classic_patch_mesh.bottom_radius = 0.12
	_classic_patch_mesh.height = 0.018
	_classic_patch_mesh.radial_segments = 5
	_classic_patch_mesh.rings = 1
	return _classic_patch_mesh


static func _add_surface_disc(
	root: Node3D,
	piece_name: String,
	normal: Vector3,
	radius: float,
	material: StandardMaterial3D,
	sides: int = 12
) -> void:
	var mesh_key := "disc:%0.3f:%d" % [radius, sides]
	var mesh: CylinderMesh = _ball_detail_mesh_cache.get(mesh_key) as CylinderMesh
	if not mesh:
		mesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 0.018
		mesh.radial_segments = sides
		mesh.rings = 1
		_ball_detail_mesh_cache[mesh_key] = mesh
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	piece.mesh = mesh
	piece.material_override = material
	piece.position = normal.normalized() * 0.488
	piece.basis = Basis(Quaternion(Vector3.UP, normal.normalized()))
	root.add_child(piece)


static func _add_ring(
	root: Node3D,
	piece_name: String,
	material: StandardMaterial3D,
	rotation_degrees: Vector3,
	scale_value: Vector3
) -> void:
	var mesh: TorusMesh = _ball_detail_mesh_cache.get("ball_ring") as TorusMesh
	if not mesh:
		mesh = TorusMesh.new()
		mesh.inner_radius = 0.455
		mesh.outer_radius = 0.505
		mesh.ring_segments = 28
		mesh.rings = 6
		_ball_detail_mesh_cache["ball_ring"] = mesh
	var ring := MeshInstance3D.new()
	ring.name = piece_name
	ring.mesh = mesh
	ring.material_override = material
	ring.rotation_degrees = rotation_degrees
	ring.scale = scale_value
	root.add_child(ring)


static func _add_radial_marks(
	root: Node3D,
	material: StandardMaterial3D,
	count: int,
	style: String
) -> void:
	for index in count:
		var angle := TAU * float(index) / float(count)
		var elevation := sin(float(index) * 2.17) * 0.62
		var normal := Vector3(cos(angle), elevation, sin(angle)).normalized()
		var sides := 5
		var radius := 0.052
		match style:
			"chips":
				sides = 12
				radius = 0.045 + 0.012 * float(index % 3)
			"seeds":
				sides = 10
				radius = 0.04
			"checks":
				sides = 4
				radius = 0.07
			"lava":
				sides = 4
				radius = 0.035 + 0.012 * float(index % 2)
			"stars":
				sides = 5
				radius = 0.025 + 0.012 * float(index % 3)
			"satellites":
				sides = 12
				radius = 0.055
			"ember":
				sides = 3
				radius = 0.05
			"candy":
				sides = 12
				radius = 0.055
		_add_surface_disc(root, "%s%02d" % [style.capitalize(), index], normal, radius, material, sides)


static func _add_axis_facets(
	root: Node3D,
	material: StandardMaterial3D,
	style: String
) -> void:
	var mesh_key := "facet:%s" % style
	var mesh: PrismMesh = _ball_detail_mesh_cache.get(mesh_key) as PrismMesh
	if not mesh:
		mesh = PrismMesh.new()
		mesh.size = Vector3(0.2, 0.16 if style == "ice" else 0.22, 0.065)
		_ball_detail_mesh_cache[mesh_key] = mesh
	var normals: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for index in normals.size():
		var facet := MeshInstance3D.new()
		facet.name = "%sFacet%02d" % [style.capitalize(), index]
		facet.mesh = mesh
		facet.material_override = material
		facet.position = normals[index] * 0.515
		facet.basis = Basis(Quaternion(Vector3.UP, normals[index]))
		root.add_child(facet)


static func _add_crown_fins(root: Node3D, material: StandardMaterial3D, count: int = 3) -> void:
	var mesh: PrismMesh = _ball_detail_mesh_cache.get("crown_fin") as PrismMesh
	if not mesh:
		mesh = PrismMesh.new()
		mesh.size = Vector3(0.14, 0.15, 0.045)
		_ball_detail_mesh_cache["crown_fin"] = mesh
	for index in count:
		var fin := MeshInstance3D.new()
		fin.name = "CrownFin%02d" % index
		fin.mesh = mesh
		fin.material_override = material
		fin.position = Vector3((float(index) - float(count - 1) * 0.5) * 0.13, 0.51, 0.0)
		fin.rotation_degrees = Vector3(0.0, 0.0, (float(index) - 1.0) * -8.0)
		root.add_child(fin)


static func _add_cloud_puffs(root: Node3D, material: StandardMaterial3D) -> void:
	var mesh: SphereMesh = _ball_detail_mesh_cache.get("cloud_puff") as SphereMesh
	if not mesh:
		mesh = SphereMesh.new()
		mesh.radius = 0.115
		mesh.height = 0.23
		mesh.radial_segments = 12
		mesh.rings = 6
		_ball_detail_mesh_cache["cloud_puff"] = mesh
	var positions: Array[Vector3] = [
		Vector3(-0.18, 0.2, 0.43), Vector3(0.0, 0.26, 0.43), Vector3(0.18, 0.18, 0.43),
		Vector3(-0.12, -0.24, -0.43), Vector3(0.12, -0.2, -0.44),
	]
	for index in positions.size():
		var puff := MeshInstance3D.new()
		puff.name = "CloudPuff%02d" % index
		puff.mesh = mesh
		puff.material_override = material
		puff.position = positions[index]
		puff.scale = Vector3.ONE * (0.8 + float(index % 3) * 0.12)
		root.add_child(puff)


static func _add_comet_fins(root: Node3D, material: StandardMaterial3D) -> void:
	var mesh: PrismMesh = _ball_detail_mesh_cache.get("comet_fin") as PrismMesh
	if not mesh:
		mesh = PrismMesh.new()
		mesh.size = Vector3(0.24, 0.26, 0.065)
		_ball_detail_mesh_cache["comet_fin"] = mesh
	for index in 3:
		var fin := MeshInstance3D.new()
		fin.name = "CometFin%02d" % index
		fin.mesh = mesh
		fin.material_override = material
		fin.position = Vector3(-0.49, 0.0, 0.0)
		fin.rotation_degrees = Vector3(float(index) * 120.0, 0.0, 90.0)
		root.add_child(fin)


static func _detail_material(
	skin_id: String,
	key: String,
	color: Color,
	emission_strength: float = 0.0
) -> StandardMaterial3D:
	var cache_key := "%s:%s" % [skin_id, key]
	if _ball_detail_material_cache.has(cache_key):
		return _ball_detail_material_cache[cache_key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.32
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0) * emission_strength
	_ball_detail_material_cache[cache_key] = material
	return material


static func _ball_concept_name(skin_id: String) -> String:
	match skin_id:
		"ball_classic", "ball_neon", "ball_fire": return "soccer_panel_variation"
		"ball_ice": return "frosted_facets"
		"ball_galaxy": return "star_map_orbits"
		"ball_champion": return "trophy_crown"
		"ball_gold": return "golden_match_trophy"
		"ball_supporter": return "supporter_medallion"
		"ball_candy": return "candy_spiral"
		"ball_mint": return "mint_chip"
		"ball_watermelon": return "watermelon_rind"
		"ball_sunset": return "sunset_orbits"
		"ball_checker": return "checker_tiles"
		"ball_cloud": return "cloud_puffs"
		"ball_comet": return "comet_fins"
		"ball_lava": return "lava_seams"
		"ball_prism": return "prism_facets"
		"ball_void": return "orbital_horizon"
		_: return "soccer_panel_variation"


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
	match effect_id:
		"goal_classic":
			_spawn_celebration(level_root, goal_root, effect_id, 18)
			_spawn_shockwave(level_root, goal_root, _goal_effect_color(effect_id), 0.72)
		"goal_confetti":
			_spawn_celebration(level_root, goal_root, effect_id, 38)
		"goal_shockwave":
			_spawn_shockwave(level_root, goal_root, _goal_effect_color(effect_id), 1.25)
			_spawn_shockwave(level_root, goal_root, Color("c8f7ff"), 0.88, 0.12)
		"goal_supporter":
			_spawn_celebration(level_root, goal_root, effect_id, 28)
			_spawn_shockwave(level_root, goal_root, _goal_effect_color(effect_id), 1.05)
		"goal_ribbons":
			_spawn_celebration(level_root, goal_root, effect_id, 26)
		"goal_splash":
			_spawn_celebration(level_root, goal_root, effect_id, 22)
		"goal_fireworks":
			_spawn_celebration(level_root, goal_root, effect_id, 36)
			_spawn_shockwave(level_root, goal_root, _goal_effect_color(effect_id), 0.92, 0.18)
		"goal_portal":
			_spawn_shockwave(level_root, goal_root, _goal_effect_color(effect_id), 1.35)
			_spawn_shockwave(level_root, goal_root, Color(0.25, 0.92, 1.0, 1.0), 1.05, 0.12, Vector3(18.0, 0.0, 0.0))
			_spawn_shockwave(level_root, goal_root, Color("ff72d9"), 0.74, 0.24, Vector3(-18.0, 0.0, 0.0))


static func clear_goal_effects(level_root: Node) -> void:
	if not level_root:
		return
	for child in level_root.find_children("*", "", true, false):
		if child.is_in_group(GOAL_EFFECT_GROUP):
			child.queue_free()


static func _ball_main_material(skin_id: String) -> StandardMaterial3D:
	if _ball_main_material_cache.has(skin_id):
		return _ball_main_material_cache[skin_id]
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
		"ball_supporter":
			material.albedo_color = Color(0.02, 0.22, 0.2, 1.0)
			material.metallic = 0.35
			material.roughness = 0.24
			material.emission_enabled = true
			material.emission = Color(0.0, 0.32, 0.28, 1.0)
		"ball_champion":
			material.albedo_color = Color(0.03, 0.28, 0.72, 1.0)
			material.metallic = 0.32
			material.emission_enabled = true
			material.emission = Color(0.02, 0.12, 0.35, 1.0)
		"ball_candy":
			material.albedo_color = Color(1.0, 0.91, 0.83, 1.0)
		"ball_mint":
			material.albedo_color = Color(0.42, 0.9, 0.7, 1.0)
		"ball_watermelon":
			material.albedo_color = Color(1.0, 0.3, 0.45, 1.0)
		"ball_sunset":
			material.albedo_color = Color(1.0, 0.32, 0.18, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.28, 0.04, 0.12, 1.0)
		"ball_checker":
			material.albedo_color = Color(0.97, 0.94, 0.82, 1.0)
			material.roughness = 0.5
		"ball_cloud":
			material.albedo_color = Color(0.5, 0.83, 1.0, 1.0)
			material.metallic = 0.18
			material.roughness = 0.2
		"ball_comet":
			material.albedo_color = Color(0.025, 0.07, 0.16, 1.0)
			material.metallic = 0.48
			material.emission_enabled = true
			material.emission = Color(0.04, 0.14, 0.32, 1.0)
		"ball_lava":
			material.albedo_color = Color(0.055, 0.045, 0.04, 1.0)
			material.roughness = 0.62
			material.emission_enabled = true
			material.emission = Color(0.42, 0.055, 0.0, 1.0)
		"ball_prism":
			material.albedo_color = Color(0.82, 0.96, 1.0, 1.0)
			material.metallic = 0.55
			material.roughness = 0.12
			material.emission_enabled = true
			material.emission = Color(0.15, 0.22, 0.3, 1.0)
		"ball_void":
			material.albedo_color = Color(0.005, 0.004, 0.012, 1.0)
			material.metallic = 0.62
			material.roughness = 0.18
			material.emission_enabled = true
			material.emission = Color(0.05, 0.0, 0.12, 1.0)
		_:
			material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.16, 0.16, 0.16, 1.0)
	_ball_main_material_cache[skin_id] = material
	return material


static func _ball_accent_material(skin_id: String) -> StandardMaterial3D:
	if _ball_accent_material_cache.has(skin_id):
		return _ball_accent_material_cache[skin_id]
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
		"ball_supporter":
			material.albedo_color = Color(1.0, 0.72, 0.18, 1.0)
			material.metallic = 0.55
			material.roughness = 0.2
			material.emission_enabled = true
			material.emission = Color(0.28, 0.72, 0.55, 1.0)
		"ball_champion":
			material.albedo_color = Color(1.0, 0.72, 0.12, 1.0)
			material.metallic = 0.58
			material.emission_enabled = true
			material.emission = Color(0.35, 0.18, 0.01, 1.0)
		"ball_candy":
			material.albedo_color = Color(0.96, 0.12, 0.24, 1.0)
		"ball_mint":
			material.albedo_color = Color(0.12, 0.055, 0.035, 1.0)
		"ball_watermelon":
			material.albedo_color = Color(0.05, 0.58, 0.24, 1.0)
		"ball_sunset":
			material.albedo_color = Color(0.34, 0.08, 0.62, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.28, 0.04, 0.42, 1.0)
		"ball_checker":
			material.albedo_color = Color(0.015, 0.018, 0.025, 1.0)
		"ball_cloud":
			material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
			material.metallic = 0.3
		"ball_comet":
			material.albedo_color = Color(0.86, 0.96, 1.0, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.62, 0.9, 1.0, 1.0)
		"ball_lava":
			material.albedo_color = Color(1.0, 0.2, 0.01, 1.0)
			material.emission_enabled = true
			material.emission = Color(1.0, 0.14, 0.0, 1.0)
		"ball_prism":
			material.albedo_color = Color(0.8, 0.34, 1.0, 1.0)
			material.metallic = 0.38
			material.emission_enabled = true
			material.emission = Color(0.2, 0.65, 1.0, 1.0)
		"ball_void":
			material.albedo_color = Color(0.48, 0.18, 1.0, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.42, 0.06, 1.0, 1.0)
		_:
			material.albedo_color = Color(0.035, 0.035, 0.035, 1.0)
	_ball_accent_material_cache[skin_id] = material
	return material


static func _configure_goal_flash(goal_flash: ColorRect, _effect_id: String) -> void:
	if not goal_flash:
		return
	goal_flash.color = Color(0.18, 0.86, 0.42, 1.0)


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
		"goal_supporter":
			goal_particles.amount = 72
			goal_particles.lifetime = 0.72
			goal_particles.color = Color(0.16, 1.0, 0.72, 1.0)
			goal_particles.initial_velocity_min = 2.0
			goal_particles.initial_velocity_max = 4.5
		"goal_ribbons":
			goal_particles.amount = 72
			goal_particles.lifetime = 0.78
			goal_particles.color = Color(1.0, 0.36, 0.3, 1.0)
			goal_particles.initial_velocity_min = 2.0
			goal_particles.initial_velocity_max = 4.8
		"goal_splash":
			goal_particles.amount = 56
			goal_particles.lifetime = 0.62
			goal_particles.color = Color(0.12, 0.9, 0.75, 1.0)
			goal_particles.initial_velocity_min = 1.7
			goal_particles.initial_velocity_max = 4.0
		"goal_fireworks":
			goal_particles.amount = 80
			goal_particles.lifetime = 0.85
			goal_particles.color = Color(1.0, 0.66, 0.18, 1.0)
			goal_particles.initial_velocity_min = 2.6
			goal_particles.initial_velocity_max = 6.0
		"goal_portal":
			goal_particles.amount = 40
			goal_particles.lifetime = 0.7
			goal_particles.color = Color(0.52, 0.28, 1.0, 1.0)
			goal_particles.initial_velocity_min = 1.0
			goal_particles.initial_velocity_max = 2.4
		_:
			goal_particles.amount = 64
			goal_particles.lifetime = 0.8
			goal_particles.color = Color(1.0, 0.9, 0.2, 1.0)
			goal_particles.initial_velocity_min = 2.0
			goal_particles.initial_velocity_max = 5.0


static func _spawn_celebration(
	level_root: Node,
	goal_root: Node3D,
	effect_id: String,
	base_piece_count: int
) -> void:
	var origin := _goal_effect_origin(goal_root)
	var container := Node3D.new()
	container.name = "Netbound%sEffect" % effect_id.trim_prefix("goal_").capitalize().replace(" ", "")
	container.add_to_group(GOAL_EFFECT_GROUP)
	level_root.add_child(container)
	container.global_position = origin
	var colors := _goal_effect_colors(effect_id)
	var material_cache: Array[StandardMaterial3D] = []
	for color in colors:
		var shared_material := StandardMaterial3D.new()
		shared_material.albedo_color = color
		shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_material.no_depth_test = true
		shared_material.emission_enabled = true
		shared_material.emission = Color(color.r, color.g, color.b, 1.0) * 0.45
		material_cache.append(shared_material)
	var reduced_motion := _reduced_motion_enabled(level_root)
	var piece_count := maxi(6, roundi(float(base_piece_count) * _goal_effect_quality_multiplier(level_root)))
	if reduced_motion:
		piece_count = maxi(6, roundi(float(piece_count) * 0.65))
	var duration := 0.62 if reduced_motion else 1.18
	for i in piece_count:
		var piece := MeshInstance3D.new()
		piece.name = "CelebrationPiece%02d" % i
		var mesh: PrimitiveMesh
		if effect_id == "goal_splash":
			var splash_mesh := SphereMesh.new()
			splash_mesh.radius = 0.46 + float(i % 3) * 0.1
			splash_mesh.height = splash_mesh.radius * 2.0
			splash_mesh.radial_segments = 10
			splash_mesh.rings = 5
			mesh = splash_mesh
		else:
			var paper_mesh := BoxMesh.new()
			match effect_id:
				"goal_ribbons":
					paper_mesh.size = Vector3(1.45, 0.11, 0.18)
				"goal_fireworks", "goal_supporter":
					paper_mesh.size = Vector3(0.82, 0.12, 0.12)
				"goal_classic":
					paper_mesh.size = Vector3(1.0, 0.12, 0.15)
				_:
					paper_mesh.size = Vector3(0.58, 0.16, 0.32)
			mesh = paper_mesh
		piece.mesh = mesh
		piece.material_override = material_cache[i % material_cache.size()]
		container.add_child(piece)
		piece.position = Vector3.ZERO
		piece.rotation = Vector3(i * 0.37, i * 0.19, i * 0.51)
		var angle := TAU * float(i) / float(maxi(piece_count, 1))
		var x := sin(float(i) * 2.31) * 8.2
		var y := -2.0 + fposmod(float(i) * 1.17, 8.2)
		var z := cos(float(i) * 1.83) * 2.2
		if effect_id == "goal_fireworks":
			var burst_center_x: float = [-5.4, 0.0, 5.4][i % 3]
			var burst_radius := 2.2 + float(i % 4) * 0.34
			x = burst_center_x + cos(angle * 3.0) * burst_radius
			y = 1.8 + sin(angle * 3.0) * burst_radius
		elif effect_id == "goal_classic":
			x = cos(angle) * 7.2
			y = sin(angle) * 4.2
		elif effect_id == "goal_supporter":
			x = cos(angle) * 7.6
			y = sin(angle) * 4.6
		elif effect_id == "goal_splash":
			piece.scale = Vector3(1.35, 0.6, 0.35)
		var tween := container.create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "position", Vector3(x, y, z), duration)
		if not reduced_motion:
			tween.tween_property(piece, "rotation", piece.rotation + Vector3(4.0, 2.0, 3.0), duration)
		tween.tween_property(piece, "scale", piece.scale * 0.2, duration * 0.28).set_delay(duration * 0.72)
	var cleanup := container.create_tween()
	cleanup.tween_interval(duration + 0.18)
	cleanup.tween_callback(container.queue_free)


static func _spawn_shockwave(
	level_root: Node,
	goal_root: Node3D,
	color: Color,
	scale_multiplier: float = 1.0,
	delay: float = 0.0,
	rotation_offset: Vector3 = Vector3.ZERO
) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "NetboundShockwaveEffect"
	ring.add_to_group(GOAL_EFFECT_GROUP)
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.2
	mesh.ring_segments = 48
	mesh.rings = 8
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = Color(color.r, color.g, color.b, 0.62)
	material.emission_enabled = true
	material.emission = color
	ring.material_override = material
	level_root.add_child(ring)
	ring.global_position = _goal_effect_origin(goal_root)
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0) + rotation_offset
	var reduced_motion := _reduced_motion_enabled(level_root)
	var duration := 0.52 if reduced_motion else 0.92
	var tween := ring.create_tween()
	if delay > 0.0:
		tween.tween_interval(minf(delay, 0.06) if reduced_motion else delay)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3.ONE * 10.5 * scale_multiplier, duration)
	tween.tween_property(material, "albedo_color:a", 0.0, duration * 0.35).set_delay(duration * 0.65)
	tween.chain().tween_callback(ring.queue_free)


static func _goal_effect_quality_multiplier(level_root: Node) -> float:
	var config: Dictionary = {}
	if level_root:
		for property in level_root.get_property_list():
			if String(property.get("name", "")) == "current_quality_config":
				config = level_root.get("current_quality_config") as Dictionary
				break
	if config.is_empty():
		return 1.0
	return clampf(float(config.get("particle_multiplier", 1.0)), 0.35, 1.0)


static func _reduced_motion_enabled(level_root: Node) -> bool:
	if not level_root:
		return false
	var save_service := level_root.get_node_or_null("/root/SaveService")
	return bool(save_service.call("get_setting_value", "reduced_motion_enabled", false)) \
		if save_service and save_service.has_method("get_setting_value") else false


static func _goal_effect_origin(goal_root: Node3D) -> Vector3:
	if goal_root:
		return goal_root.global_position + Vector3(0.0, 3.6, 0.35)
	return Vector3(0.0, 3.6, -10.0)


static func _goal_effect_color(effect_id: String) -> Color:
	return _goal_effect_colors(effect_id)[0]


static func _goal_effect_colors(effect_id: String) -> Array[Color]:
	match effect_id:
		"goal_classic":
			return [Color("ffd83d"), Color("ffffff")]
		"goal_ribbons":
			return [Color("ff5f65"), Color("ffd739"), Color("ffffff")]
		"goal_splash":
			return [Color("24d6b0"), Color("2a9df4"), Color("f4f0d9")]
		"goal_fireworks":
			return [Color("ffb52e"), Color("ff4e78"), Color("58d5ff"), Color("fff3ca")]
		"goal_portal":
			return [Color("8c58ff"), Color("4ce7ff")]
		"goal_supporter":
			return [Color("26efb4"), Color("ffc83d")]
		"goal_shockwave":
			return [Color("3edcff"), Color("b8f4ff")]
		_:
			return [Color("ff4258"), Color("36c7ff"), Color("ffe52d"), Color("4df28a"), Color("ef58ff")]
