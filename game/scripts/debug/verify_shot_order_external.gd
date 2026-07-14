extends SceneTree

func _initialize() -> void:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var root: Node3D = scene.instantiate() as Node3D
	get_root().add_child(root)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame

	var level: Node = get_root().get_node("Level01")
	var detector: GoalDetector = level.get_node("Goal/GoalDetection") as GoalDetector
	var passed := true

	await level._restart_level()
	await process_frame

	# Case 1: final shot scores; must be GOAL, not FAILED.
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	level.set("level_state", level.LevelState.READY)
	_prime_valid_shot(level)
	level.call("_fire_shot")
	await physics_frame
	print("ORDER after_fire state=", level.get("level_state"), " remaining=", level.get("shots_remaining"))
	detector.reset_shot_tracking()
	level.call("_on_goal_scored")
	var final_goal_ok: bool = int(level.get("level_state")) == level.LevelState.GOAL \
		and not bool(level.get_node("UI/FailPanel").visible)
	passed = final_goal_ok and passed
	print("ORDER final_goal ok=", final_goal_ok, " state=", level.get("level_state"))

	await level._restart_level()
	await process_frame

	# Case 2: final shot misses after settling
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	level.set("level_state", level.LevelState.READY)
	_prime_valid_shot(level)
	level.call("_fire_shot")
	level.set("shot_active_elapsed", 1.0)
	level.call("_resolve_miss", level.get("active_shot_id"), "stopped")
	var final_miss_ok: bool = int(level.get("level_state")) == level.LevelState.FAILED \
		and bool(level.get_node("UI/FailPanel").visible)
	passed = final_miss_ok and passed
	print("ORDER final_miss ok=", final_miss_ok, " state=", level.get("level_state"))

	await level._restart_level()
	await process_frame

	# Case 3: goal cancels stale miss callback
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	level.set("level_state", level.LevelState.READY)
	_prime_valid_shot(level)
	level.call("_fire_shot")
	var shot_id: int = level.get("active_shot_id")
	level.call("_schedule_auto_reset", shot_id - 1)
	level.call("_on_goal_scored")
	await process_frame
	level.call("_auto_reset_after_miss", shot_id - 1, level.get("state_generation") - 1)
	var stale_callback_ok: bool = int(level.get("level_state")) == level.LevelState.GOAL
	passed = stale_callback_ok and passed
	print("ORDER stale_callback ok=", stale_callback_ok, " state=", level.get("level_state"))

	# Case 4: retry restores READY with an unfrozen stationary ball
	await level._restart_level()
	await process_frame
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var retry_ready_ok: bool = int(level.get("level_state")) == level.LevelState.READY \
		and not ball.freeze \
		and ball.linear_velocity.length() <= float(level.get("stopped_velocity_threshold"))
	passed = retry_ready_ok and passed
	print("ORDER retry_ready ok=", retry_ready_ok)

	print("ORDER verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _prime_valid_shot(level: Node) -> void:
	var samples := PackedVector2Array()
	var start := Vector2(400.0, 620.0)
	var end := Vector2(500.0, 430.0)
	for i in 11:
		samples.append(start.lerp(end, float(i) / 10.0))
	level.set("swipe_screen_points", samples)
	level.call("_recalculate_swipe_state")
