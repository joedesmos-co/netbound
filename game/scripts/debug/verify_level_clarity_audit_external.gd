extends SceneTree

const LevelRegistryScript := preload("res://scripts/levels/level_registry.gd")

const EXPECTED_LEVEL_20_OBSTACLES := [
	"CrossSlider",
	"LiftBar",
	"FinalBeat/Body",
	"FrontShield",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_ids := LevelRegistryScript.get_level_ids()
	var passed := level_ids.size() == 20
	var collider_counts: Dictionary = {}
	for level_id in level_ids:
		var result := await _audit_level(level_id)
		collider_counts[level_id] = int(result.get("colliders", 0))
		passed = bool(result.get("ok", false)) and passed
	passed = await _verify_level_20_contract() and passed
	print("LEVEL_CLARITY_AUDIT counts=", collider_counts)
	print("LEVEL_CLARITY_AUDIT verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _audit_level(level_id: String) -> Dictionary:
	var packed := load(LevelRegistryScript.get_scene_path(level_id)) as PackedScene
	if not packed:
		return {"ok": false, "colliders": 0}
	var level := packed.instantiate() as Node3D
	get_root().add_child(level)
	for _frame in range(4):
		await process_frame
	await physics_frame

	var passed := true
	var colliders: Array[CollisionShape3D] = []
	var signatures: Dictionary = {}
	for node in level.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if not _is_course_collider(collision, level):
			continue
		colliders.append(collision)
		var body := collision.get_parent() as CollisionObject3D
		var source := body.get_node_or_null("MeshInstance3D") as MeshInstance3D
		var wrapper := body.get_node_or_null("NetboundCourseArt") as Node3D
		passed = source != null and wrapper != null and passed
		if source and collision.shape is BoxShape3D and source.mesh is BoxMesh:
			passed = (source.mesh as BoxMesh).size.is_equal_approx((collision.shape as BoxShape3D).size) and passed
			passed = Vector3(wrapper.get_meta("visual_size", Vector3.ZERO)).is_equal_approx((collision.shape as BoxShape3D).size) and passed
		var signature := "%s|%s" % [body.global_transform, _shape_signature(collision.shape)]
		passed = not signatures.has(signature) and passed
		signatures[signature] = true

	level.queue_free()
	await process_frame
	print("LEVEL_CLARITY_AUDIT level=", level_id, " colliders=", colliders.size(), " ok=", passed)
	return {"ok": passed, "colliders": colliders.size()}


func _verify_level_20_contract() -> bool:
	var packed := load(LevelRegistryScript.get_scene_path("level_20")) as PackedScene
	var level := packed.instantiate() as Node3D
	get_root().add_child(level)
	for _frame in range(4):
		await process_frame
	await physics_frame
	var passed := level.get_node_or_null("CurveTower") == null
	for path in EXPECTED_LEVEL_20_OBSTACLES:
		var body := level.get_node_or_null(path) as StaticBody3D
		passed = body != null and body.get_node_or_null("CollisionShape3D") != null and body.get_node_or_null("NetboundCourseArt") != null and passed
	var course_colliders := 0
	for node in level.find_children("*", "CollisionShape3D", true, false):
		if _is_course_collider(node as CollisionShape3D, level):
			course_colliders += 1
	passed = course_colliders == EXPECTED_LEVEL_20_OBSTACLES.size() and passed
	level.queue_free()
	await process_frame
	print("LEVEL_CLARITY_AUDIT level20 redundant_removed=", passed, " colliders=", course_colliders)
	return passed


func _is_course_collider(collision: CollisionShape3D, level: Node) -> bool:
	if not collision or collision.disabled:
		return false
	var body := collision.get_parent() as CollisionObject3D
	if not body or body.collision_layer == 0 or body.name in ["Ground", "Obstacle"]:
		return false
	var ancestor: Node = body
	while ancestor and ancestor != level:
		if ancestor.name in ["Goal", "Ball"] or ancestor is GoalTarget:
			return false
		ancestor = ancestor.get_parent()
	return body.has_node("MeshInstance3D")


func _shape_signature(shape: Shape3D) -> String:
	if shape is BoxShape3D:
		return "box:%s" % (shape as BoxShape3D).size
	if shape is SphereShape3D:
		return "sphere:%.4f" % (shape as SphereShape3D).radius
	return shape.get_class() if shape else "null"
