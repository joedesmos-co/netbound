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

	await level._restart_level()
	await process_frame

	# Case 1: final shot scores — must be GOAL, not FAILED
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	level.set("level_state", level.LevelState.READY)
	level.call("_fire_shot")
	await physics_frame
	print("ORDER after_fire state=", level.get("level_state"), " remaining=", level.get("shots_remaining"))
	detector.reset_shot_tracking()
	level.call("_on_goal_scored")
	print("ORDER final_goal state=", level.get("level_state"), " fail=", level.get_node("UI/FailPanel").visible)

	await level._restart_level()
	await process_frame

	# Case 2: final shot misses after settling
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	level.set("level_state", level.LevelState.READY)
	level.call("_fire_shot")
	level.set("shot_active_elapsed", 1.0)
	level.call("_resolve_miss", level.get("active_shot_id"), "stopped")
	print("ORDER final_miss state=", level.get("level_state"), " fail=", level.get_node("UI/FailPanel").visible)

	await level._restart_level()
	await process_frame

	# Case 3: goal cancels stale miss callback
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	level.set("level_state", level.LevelState.READY)
	level.call("_fire_shot")
	var shot_id: int = level.get("active_shot_id")
	level.call("_schedule_auto_reset", shot_id - 1)
	level.call("_on_goal_scored")
	await process_frame
	level.call("_auto_reset_after_miss", shot_id - 1)
	print("ORDER stale_callback state=", level.get("level_state"))

	# Case 4: stopped grace blocks instant fail on fire frame
	await level._restart_level()
	await process_frame
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	level.set("level_state", level.LevelState.READY)
	level.call("_fire_shot")
	level.call("_resolve_miss", level.get("active_shot_id"), "stopped")
	print("ORDER grace_blocked=", level.get("level_state") == level.LevelState.SHOT_ACTIVE)

	quit()
