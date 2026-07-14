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
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var detector: GoalDetector = level.get_node("Goal/GoalDetection") as GoalDetector
	var reset_button: Button = level.get_node("UI/TopLeftUI/ResetButton") as Button

	print("M2 shots=", level.get("shots_remaining"))
	print("M2 goal_line_z=", detector.goal_line_z)

	var inside := Vector3(0.0, 1.0, detector.goal_line_z - 0.9)
	var outside := Vector3(0.0, 1.0, detector.goal_line_z + 0.5)
	print("M2 full_goal_inside=", detector.is_ball_fully_in_goal(inside, 0.49))
	print("M2 full_goal_outside=", detector.is_ball_fully_in_goal(outside, 0.49))

	level.set("shots_remaining", 1)
	level.set("level_state", level.LevelState.SHOT_ACTIVE)
	detector.begin_shot_tracking(1, inside + Vector3(0, 0, 1.5))
	var scored_once := detector.process_ball(inside, 0.49, 1)
	var scored_twice := detector.process_ball(inside, 0.49, 1)
	print("M2 duplicate_block=", scored_once and not scored_twice)

	await level._restart_level()
	await process_frame
	print("M2 retry_shots=", level.get("shots_remaining"))

	ball.global_position = Vector3(0, 0.67, 0)
	ball.linear_velocity = Vector3(0, 0, -8)
	reset_button.emit_signal("pressed")
	await process_frame
	await process_frame
	print("M2 reset_while_moving=", ball.global_position)

	quit()
