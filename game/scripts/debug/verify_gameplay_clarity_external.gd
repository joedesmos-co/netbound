extends SceneTree

const MovingObstacleScript = preload("res://scripts/components/moving_obstacle.gd")
const TimedGateScript = preload("res://scripts/components/timed_gate.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := true
	passed = _verify_moving_obstacle_continuity() and passed
	passed = _verify_timed_gate_continuity() and passed
	passed = await _verify_production_side_goal_flow() and passed
	print("GAMEPLAY_CLARITY verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _verify_moving_obstacle_continuity() -> bool:
	var at_30 := _sample_moving_obstacle(30)
	var at_60 := _sample_moving_obstacle(60)
	var reset_position: Vector3 = at_30.reset_position
	var continuous := (
		Vector3(at_30.position).distance_to(Vector3(at_60.position)) <= 0.001
		and reset_position.distance_to(Vector3.ZERO) <= 0.001
		and float(at_30.max_step) < 0.35
		and float(at_60.max_step) < 0.2
	)
	print("GAMEPLAY_CLARITY moving_obstacle=", at_30, " fps60=", at_60, " ok=", continuous)
	return continuous


func _sample_moving_obstacle(fps: int) -> Dictionary:
	var obstacle: Node3D = MovingObstacleScript.new()
	obstacle.point_a = Vector3.ZERO
	obstacle.point_b = Vector3(6.0, 0.0, 0.0)
	obstacle.duration = 1.0
	obstacle.start_phase = 0.0
	obstacle.reset_level_element(0)
	var previous := obstacle.position
	var max_step := 0.0
	for _step in range(fps * 2):
		obstacle._physics_process(1.0 / float(fps))
		max_step = maxf(max_step, obstacle.position.distance_to(previous))
		previous = obstacle.position
	var sampled_position := obstacle.position
	obstacle.reset_level_element(1)
	var result := {
		"position": sampled_position,
		"reset_position": obstacle.position,
		"max_step": max_step,
	}
	obstacle.free()
	return result


func _verify_timed_gate_continuity() -> bool:
	var at_30 := _sample_timed_gate(30)
	var at_60 := _sample_timed_gate(60)
	var continuous := (
		bool(at_30.has_transition)
		and Vector3(at_30.position).distance_to(Vector3(at_60.position)) <= 0.02
		and float(at_30.max_step) < 0.8
		and float(at_60.max_step) < 0.45
		and bool(at_30.visited_midpoint)
		and bool(at_60.visited_midpoint)
		and Vector3(at_30.reset_position).distance_to(Vector3.ZERO) <= 0.001
	)
	print("GAMEPLAY_CLARITY timed_gate=", at_30, " fps60=", at_60, " ok=", continuous)
	return continuous


func _sample_timed_gate(fps: int) -> Dictionary:
	var gate: Node3D = TimedGateScript.new()
	var body := Node3D.new()
	body.name = "GateBody"
	gate.add_child(body)
	gate.target_path = NodePath("GateBody")
	gate.closed_position = Vector3.ZERO
	gate.open_position = Vector3(0.0, 6.0, 0.0)
	gate.closed_duration = 0.5
	gate.open_duration = 0.5
	gate.starts_open = false
	gate.start_phase_seconds = 0.0
	var has_transition := gate.get("transition_duration") != null
	if has_transition:
		gate.set("transition_duration", 0.42)
	gate.target = body
	gate.reset_level_element(0)
	var previous := body.position
	var max_step := 0.0
	var visited_midpoint := false
	for _step in range(fps * 2):
		gate._physics_process(1.0 / float(fps))
		max_step = maxf(max_step, body.position.distance_to(previous))
		visited_midpoint = visited_midpoint or (body.position.y > 0.2 and body.position.y < 5.8)
		previous = body.position
	var sampled_position := body.position
	gate.reset_level_element(1)
	var result := {
		"has_transition": has_transition,
		"position": sampled_position,
		"reset_position": body.position,
		"max_step": max_step,
		"visited_midpoint": visited_midpoint,
	}
	gate.free()
	return result


func _verify_production_side_goal_flow() -> bool:
	var packed: PackedScene = load("res://levels/level_01.tscn")
	var level: Node3D = packed.instantiate() as Node3D
	get_root().add_child(level)
	for _frame in 4:
		await process_frame
	await physics_frame

	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var camera: Camera3D = level.get_node("Camera3D") as Camera3D
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	var start := camera.unproject_position(ball.global_position)
	var finish := start + Vector2(170.0, -20.0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	level._unhandled_input(press)
	for index in 12:
		var motion := InputEventMouseMotion.new()
		motion.position = start.lerp(finish, float(index + 1) / 12.0)
		level._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	level._unhandled_input(release)
	await physics_frame

	var launched: bool = (
		int(level.get("level_state")) == level.LevelState.SHOT_ACTIVE
		and int(level.get("shots_remaining")) == 0
		and ball.linear_velocity.length() > 0.5
	)
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	var shot_id: int = level.get("active_shot_id")
	var side_outside := Vector3(12.4, 2.8, -12.5)
	level.call("_reset_all_goal_tracking")
	level.call("_begin_goal_tracking", shot_id, side_outside)
	ball.global_position = Vector3(9.8, 2.8, -12.5)
	var scored: bool = level.call("_process_goal_targets")
	var duplicate: bool = level.call("_process_goal_targets")
	var final_goal_wins: bool = (
		int(level.get("level_state")) == level.LevelState.GOAL
		and not bool(level.get_node("UI/FailPanel").visible)
	)
	var ok: bool = launched and scored and not duplicate and final_goal_wins
	print(
		"GAMEPLAY_CLARITY production_side_goal launched=", launched,
		" scored=", scored,
		" duplicate=", duplicate,
		" final_goal_wins=", final_goal_wins,
		" ok=", ok
	)
	level.queue_free()
	await process_frame
	return ok
