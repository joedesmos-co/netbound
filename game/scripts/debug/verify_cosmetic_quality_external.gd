extends SceneTree

const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")
const CosmeticVisualsScript := preload("res://scripts/cosmetics/cosmetic_visuals.gd")
const LevelScene := preload("res://levels/level_01.tscn")

const EXPECTED_ACQUISITION_COUNTS := {
	"default": 3,
	"gameplay_unlock": 10,
	"coin_purchase": 12,
	"token_purchase": 8,
	"achievement": 2,
	"supporter_entitlement": 3,
}
const INTENTIONAL_SOCCER_VARIANTS := ["ball_classic", "ball_neon", "ball_fire"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var passed := _verify_catalog_balance()
	passed = await _verify_ball_concepts_and_physics() and passed
	passed = await _verify_goal_effect_budgets() and passed
	print("COSMETIC_QUALITY verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _verify_catalog_balance() -> bool:
	var counts: Dictionary = {}
	for definition in CosmeticRegistryScript.get_all():
		var method := String(definition.acquisition_method)
		counts[method] = int(counts.get(method, 0)) + 1
	var passed := CosmeticRegistryScript.get_all().size() == 38
	for method in EXPECTED_ACQUISITION_COUNTS:
		passed = int(counts.get(method, 0)) == int(EXPECTED_ACQUISITION_COUNTS[method]) and passed
	var directly_earned := int(counts.get("gameplay_unlock", 0))
	var coin_items := int(counts.get("coin_purchase", 0))
	var token_items := int(counts.get("token_purchase", 0))
	passed = directly_earned >= 10 and directly_earned <= 11 and passed
	passed = coin_items >= 11 and coin_items <= 15 and passed
	passed = token_items >= 8 and token_items <= 9 and passed
	print("COSMETIC_QUALITY acquisition ok=", passed, " counts=", counts)
	return passed


func _verify_ball_concepts_and_physics() -> bool:
	var level := LevelScene.instantiate()
	root.add_child(level)
	await _wait_frames(3)
	await physics_frame
	var ball := level.get_node("Ball") as RigidBody3D
	var collision := ball.get_node("CollisionShape3D") as CollisionShape3D
	var sphere := collision.shape as SphereShape3D
	var main_mesh := ball.get_node("MeshInstance3D") as MeshInstance3D
	var mesh_resource := main_mesh.mesh
	var mass_before := ball.mass
	var radius_before := sphere.radius
	var collision_scale_before := collision.scale
	var launch_speed_before := float(level.get("maximum_launch_speed"))
	var passed := true
	for definition in CosmeticRegistryScript.get_by_category("ball"):
		var cosmetic_id := String(definition.cosmetic_id)
		CosmeticVisualsScript.apply_ball_skin(ball, cosmetic_id)
		var attachments := ball.get_node_or_null(CosmeticVisualsScript.BALL_ATTACHMENT_NAME)
		var concept := String(attachments.get_meta("concept", "")) if attachments else ""
		var visual_radius := float(attachments.get_meta("visual_radius", 99.0)) if attachments else 99.0
		passed = attachments != null and attachments.get_child_count() >= 3 and passed
		passed = not concept.is_empty() and visual_radius <= 0.66 and passed
		if String(definition.rarity) in ["rare", "epic", "legendary"] \
			and cosmetic_id not in INTENTIONAL_SOCCER_VARIANTS:
			passed = concept != "soccer_panel_variation" and passed
		passed = is_equal_approx(ball.mass, mass_before) and passed
		passed = is_equal_approx(sphere.radius, radius_before) and passed
		passed = collision.scale.is_equal_approx(collision_scale_before) and passed
		passed = main_mesh.mesh == mesh_resource and passed
	passed = is_equal_approx(float(level.get("maximum_launch_speed")), launch_speed_before) and passed
	print("COSMETIC_QUALITY balls ok=", passed)
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await _wait_frames(3)
	return passed


func _verify_goal_effect_budgets() -> bool:
	var level := LevelScene.instantiate()
	root.add_child(level)
	await _wait_frames(3)
	level.call("apply_quality_settings", {
		"particle_multiplier": 0.35,
		"trail_point_limit": 8,
	})
	var passed := true
	for definition in CosmeticRegistryScript.get_by_category("goal_effect"):
		CosmeticVisualsScript.trigger_goal_effect(
			level,
			level.get("goal_root") as Node3D,
			level.get("goal_flash") as ColorRect,
			level.get("goal_particles") as CPUParticles3D,
			String(definition.cosmetic_id)
		)
		var effect_roots := get_nodes_in_group(CosmeticVisualsScript.GOAL_EFFECT_GROUP)
		passed = effect_roots.size() >= 1 and effect_roots.size() <= 3 and passed
		passed = _count_group_descendants(effect_roots) <= 20 and passed
		CosmeticVisualsScript.clear_goal_effects(level)
		await _wait_frames(2)
		passed = get_nodes_in_group(CosmeticVisualsScript.GOAL_EFFECT_GROUP).is_empty() and passed
	CosmeticVisualsScript.trigger_goal_effect(
		level,
		level.get("goal_root") as Node3D,
		level.get("goal_flash") as ColorRect,
		level.get("goal_particles") as CPUParticles3D,
		"goal_portal"
	)
	await create_timer(1.6, true, false, true).timeout
	passed = get_nodes_in_group(CosmeticVisualsScript.GOAL_EFFECT_GROUP).is_empty() and passed
	print("COSMETIC_QUALITY goal_effects ok=", passed)
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await _wait_frames(3)
	return passed


func _count_group_descendants(nodes: Array[Node]) -> int:
	var count := 0
	for node in nodes:
		count += node.find_children("*", "", true, false).size()
	return count


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame
