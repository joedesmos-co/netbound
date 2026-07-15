extends SceneTree

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")
const COURSE_GROUP := "netbound_course_art"
const DETAIL_GROUP := "netbound_course_art_detail"

const EXPECTED_ARCHETYPES := [
	"padded_blocker",
	"sliding_panel",
	"training_spinner",
	"rebound_board",
	"stacked_tower",
	"training_partition",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := true
	var archetype_totals: Dictionary = {}
	var wrapped_total := 0
	var maximum_visual_nodes := 0
	var level_ids := LevelRegistryScript.get_level_ids()
	passed = level_ids.size() == 20 and passed

	for level_id in level_ids:
		var scene: PackedScene = load(LevelRegistryScript.get_scene_path(level_id))
		if not scene:
			print("ENV_ART missing_scene id=", level_id)
			passed = false
			continue
		var level := scene.instantiate() as Node3D
		var collision_before := _collision_signature(level)
		get_root().add_child(level)
		await _wait_frames(3)
		await physics_frame
		var collision_after := _collision_signature(level)
		var visual := level.get_node_or_null("LevelVisualPolish")
		var course := visual.get_node_or_null("CourseArt") if visual else null
		var level_ok := (
			collision_before == collision_after
			and course != null
			and _prototype_marker_hidden(level)
		)
		var budget: Dictionary = course.call("get_budget_snapshot") if course else {}
		var wrappers: Array = course.call("get_wrappers") if course else []
		var wrapped_count := wrappers.size()
		if level_id not in ["level_01", "level_17"]:
			level_ok = wrapped_count > 0 and level_ok
		for wrapper_variant in wrappers:
			var wrapper := wrapper_variant as Node3D
			level_ok = _wrapper_matches_collision(wrapper) and level_ok
			var archetype := String(wrapper.get_meta("archetype", ""))
			archetype_totals[archetype] = int(archetype_totals.get(archetype, 0)) + 1
		wrapped_total += wrapped_count
		maximum_visual_nodes = maxi(maximum_visual_nodes, int(budget.get("visual_nodes", 0)))
		level_ok = int(budget.get("collision_nodes", -1)) == 0 and level_ok
		level_ok = int(budget.get("material_resources", 99)) <= 8 and level_ok
		level_ok = int(budget.get("visual_nodes", 999)) <= 96 and level_ok
		print(
			"ENV_ART level=", level_id,
			" wrapped=", wrapped_count,
			" visuals=", budget.get("visual_nodes", 0),
			" collisions_unchanged=", collision_before == collision_after,
			" ok=", level_ok
		)
		passed = level_ok and passed
		level.queue_free()
		await _wait_frames(3)
		passed = get_nodes_in_group(COURSE_GROUP).is_empty() and passed

	for archetype in EXPECTED_ARCHETYPES:
		passed = int(archetype_totals.get(archetype, 0)) > 0 and passed
	passed = wrapped_total >= 30 and passed

	var low_quality_ok := await _verify_low_quality()
	passed = low_quality_ok and passed
	print(
		"ENV_ART totals wrapped=", wrapped_total,
		" max_visual_nodes=", maximum_visual_nodes,
		" archetypes=", archetype_totals,
		" low_quality=", low_quality_ok
	)
	print("ENV_ART verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _wrapper_matches_collision(wrapper: Node3D) -> bool:
	if not wrapper or not wrapper.get_parent() is StaticBody3D:
		return false
	var body := wrapper.get_parent() as StaticBody3D
	var source := body.get_node_or_null("MeshInstance3D") as MeshInstance3D
	var collision := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not source or source.visible or not collision or not (collision.shape is BoxShape3D):
		return false
	var visual_size := wrapper.get_meta("visual_size", Vector3.ZERO) as Vector3
	var collision_size := (collision.shape as BoxShape3D).size
	var base := wrapper.get_child(0) as MeshInstance3D if wrapper.get_child_count() > 0 else null
	if not base or not (base.mesh is BoxMesh):
		return false
	var collision_descendants := wrapper.find_children("*", "CollisionObject3D", true, false)
	return (
		visual_size.is_equal_approx(collision_size)
		and (base.mesh as BoxMesh).size.is_equal_approx(collision_size)
		and wrapper.transform.is_equal_approx(source.transform)
		and collision_descendants.is_empty()
		and not String(wrapper.get_meta("archetype", "")).is_empty()
	)


func _prototype_marker_hidden(level: Node) -> bool:
	var obstacle := level.get_node_or_null("Obstacle") as StaticBody3D
	if not obstacle:
		return true
	var source := obstacle.get_node_or_null("MeshInstance3D") as MeshInstance3D
	return source != null and not source.visible


func _verify_low_quality() -> bool:
	var scene: PackedScene = load(LevelRegistryScript.get_scene_path("level_20"))
	var level := scene.instantiate() as Node3D
	get_root().add_child(level)
	await _wait_frames(3)
	level.call("apply_quality_settings", {
		"decorative_geometry_enabled": false,
		"contact_shadow_enabled": true,
		"dynamic_shadows_enabled": false,
	})
	await process_frame
	var details := level.find_children("*", "MeshInstance3D", true, false).filter(
		func(node: Node) -> bool: return node.is_in_group(DETAIL_GROUP)
	)
	var bases := level.find_children("*", "MeshInstance3D", true, false).filter(
		func(node: Node) -> bool:
			return node.is_in_group(COURSE_GROUP) and not node.is_in_group(DETAIL_GROUP)
	)
	var passed := not details.is_empty() and not bases.is_empty()
	var visible_details := 0
	var hidden_details := 0
	for detail in details:
		if (detail as MeshInstance3D).visible:
			visible_details += 1
			passed = bool(detail.get_meta("keep_low", false)) and passed
		else:
			hidden_details += 1
	for base in bases:
		passed = (base as MeshInstance3D).visible and passed
	passed = visible_details > 0 and hidden_details > 0 and passed
	level.queue_free()
	await _wait_frames(3)
	return passed and get_nodes_in_group(COURSE_GROUP).is_empty()


func _collision_signature(level: Node) -> String:
	var parts := PackedStringArray()
	for node in level.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if _has_named_ancestor(collision, "Goal", level):
			continue
		var parent := collision.get_parent() as CollisionObject3D
		var shape_signature := _shape_signature(collision.shape)
		parts.append("%s|%s|%s|%d|%d|%s" % [
			level.get_path_to(collision),
			collision.transform,
			shape_signature,
			parent.collision_layer if parent else -1,
			parent.collision_mask if parent else -1,
			collision.disabled,
		])
	parts.sort()
	return "\n".join(parts)


func _has_named_ancestor(node: Node, ancestor_name: String, stop: Node) -> bool:
	var ancestor := node.get_parent()
	while ancestor and ancestor != stop:
		if ancestor.name == ancestor_name:
			return true
		ancestor = ancestor.get_parent()
	return false


func _shape_signature(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		return "box:%s" % (shape as BoxShape3D).size
	if shape is SphereShape3D:
		return "sphere:%.6f" % (shape as SphereShape3D).radius
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		return "capsule:%.6f:%.6f" % [capsule.radius, capsule.height]
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		return "cylinder:%.6f:%.6f" % [cylinder.radius, cylinder.height]
	return shape.get_class() if shape else "null"


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame
