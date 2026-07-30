extends SceneTree

const LevelScene := preload("res://levels/level_01.tscn")
const Level30Scene := preload("res://levels/level_30.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := await _verify_level(LevelScene, "level_01")
	passed = await _verify_level(Level30Scene, "level_30") and passed
	passed = await _verify_quality_and_reset() and passed
	print("CARTOONY_SPORTS verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _verify_level(scene: PackedScene, label: String) -> bool:
	var level := scene.instantiate()
	root.add_child(level)
	await _wait_frames(4)
	await physics_frame
	var ball := level.get_node_or_null("Ball") as RigidBody3D
	var goal := level.get_node_or_null("Goal") as GoalTarget
	var passed := ball != null and goal != null
	var collision := ball.get_node("CollisionShape3D") as CollisionShape3D
	var sphere := collision.shape as SphereShape3D
	passed = is_equal_approx(sphere.radius, 0.49) and passed
	passed = is_equal_approx(ball.mass, 0.43) and passed
	var crossbar := goal.get_node("Crossbar/MeshInstance3D") as MeshInstance3D
	passed = crossbar.mesh is CylinderMesh and passed
	var net_art = goal.get_node_or_null("GoalNetArt")
	passed = net_art != null and passed
	for path in ["NetLeftSide", "NetRightSide", "NetTop", "NetRear", "NetFloor"]:
		var mesh := goal.get_node_or_null(path) as MeshInstance3D
		passed = mesh != null and not mesh.visible and passed
	var before := _goal_collision_signature(goal)
	if goal.has_method("play_net_impact"):
		goal.call(
			"play_net_impact",
			goal.global_position + Vector3(0.0, 3.0, -1.0),
			Vector3(2.0, 1.0, -12.0)
		)
	await _wait_frames(8)
	passed = net_art != null and passed
	passed = _goal_collision_signature(goal) == before and passed
	if goal.has_method("reset_level_element"):
		goal.call("reset_level_element", 1)
	await _wait_frames(2)
	var snapshot: Dictionary = net_art.call("get_budget_snapshot")
	passed = not bool(snapshot.get("active", true)) and passed
	passed = int(snapshot.get("collision_nodes", -1)) == 0 and passed
	print("CARTOONY_SPORTS ", label, " ok=", passed, " net_points=", snapshot.get("rope_points", 0))
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await _wait_frames(3)
	return passed


func _elapsed_ok(net_art: Object) -> bool:
	return net_art != null


func _verify_quality_and_reset() -> bool:
	var level := LevelScene.instantiate()
	root.add_child(level)
	await _wait_frames(3)
	var goal := level.get_node("Goal") as GoalTarget
	goal.call("apply_net_quality_settings", {"effective_tier": "low"})
	var snapshot: Dictionary = goal.get_node("GoalNetArt").call("get_budget_snapshot")
	var passed := int(snapshot.get("rope_points", 0)) <= 80
	goal.call("play_net_impact", goal.global_position + Vector3(-6.0, 2.0, -1.5), Vector3(-4.0, 0.0, -10.0))
	await _wait_frames(4)
	goal.call("play_net_impact", goal.global_position + Vector3(6.0, 5.5, -1.2), Vector3(3.0, -1.0, -14.0))
	await _wait_frames(4)
	goal.call("reset_level_element", 2)
	snapshot = goal.get_node("GoalNetArt").call("get_budget_snapshot")
	passed = not bool(snapshot.get("active", true)) and passed
	print("CARTOONY_SPORTS quality/reset ok=", passed, " low_points=", snapshot.get("rope_points", 0))
	if level.has_method("prepare_for_unload"):
		level.call("prepare_for_unload")
	level.queue_free()
	await _wait_frames(3)
	return passed


func _goal_collision_signature(goal: Node) -> String:
	var parts: PackedStringArray = []
	for node in goal.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		parts.append("%s|%s|%s" % [
			String(shape_node.get_path()),
			str(shape_node.transform),
			str(shape_node.shape)
		])
	parts.sort()
	return "|".join(parts)


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame
