extends SceneTree

const MOUSE_POINTER_ID := -2
const BALL_RADIUS := 0.49


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := true
	passed = await _verify_level01_architecture() and passed
	passed = await _verify_proof_level_architecture() and passed
	print("PHASE2 verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _verify_level01_architecture() -> bool:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var level: Node3D = scene.instantiate() as Node3D
	get_root().add_child(level)
	await _warmup()

	var passed := true
	var definition: LevelDefinition = level.get("level_definition") as LevelDefinition
	var definition_ok := definition \
		and definition.is_valid_definition() \
		and definition.level_id == "level_01" \
		and definition.shot_limit == 3
	print("PHASE2 level01_definition ok=", definition_ok)
	passed = definition_ok and passed

	var target: GoalTarget = level.get_node("Goal") as GoalTarget
	var detector: GoalDetector = level.get_node("Goal/GoalDetection") as GoalDetector
	var goal_sync_ok := target \
		and detector \
		and target.geometry_matches_detector() \
		and _goal_visuals_match_target(target)
	print("PHASE2 level01_goal_sync ok=", goal_sync_ok)
	passed = goal_sync_ok and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	var launch_ok := await _shoot_real(level, "level01_launch", Vector2(170.0, -20.0))
	passed = launch_ok and passed
	var scored := _score_active_shot(level, target)
	await physics_frame
	var score_ok: bool = scored and int(level.get("level_state")) == level.LevelState.GOAL
	print("PHASE2 level01_score ok=", score_ok)
	passed = score_ok and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	passed = await _shoot_real(level, "level01_reset_launch", Vector2(170.0, -20.0)) and passed
	var shots_after_launch: int = level.get("shots_remaining")
	await level._on_reset_button_pressed()
	var reset_ok := await _wait_for_ready(level) \
		and int(level.get("shots_remaining")) == shots_after_launch \
		and _ready_ball_ok(level)
	print("PHASE2 level01_reset ok=", reset_ok)
	passed = reset_ok and passed

	await level._restart_level()
	var retry_ok := await _wait_for_ready(level) \
		and int(level.get("shots_remaining")) == definition.shot_limit \
		and _ready_ball_ok(level)
	print("PHASE2 level01_retry ok=", retry_ok)
	passed = retry_ok and passed

	detector.reset_shot_tracking()
	detector.begin_shot_tracking(44, Vector3(-9.0, 2.5, -8.0))
	var side_net_ok := detector.process_ball(Vector3(-10.5, 2.0, -12.8), BALL_RADIUS, 44)
	print("PHASE2 side_net_goal ok=", side_net_ok)
	passed = side_net_ok and passed

	level.queue_free()
	await process_frame
	return passed


func _verify_proof_level_architecture() -> bool:
	var baseline_scene: PackedScene = load("res://levels/level_01.tscn")
	var baseline: Node3D = baseline_scene.instantiate() as Node3D
	get_root().add_child(baseline)
	await _warmup()
	var baseline_tuning := _shooting_tuning_signature(baseline)
	baseline.queue_free()
	await process_frame

	var scene: PackedScene = load("res://levels/debug/level_architecture_test.tscn")
	var level: Node3D = scene.instantiate() as Node3D
	get_root().add_child(level)
	await _warmup()

	var passed := true
	var definition: LevelDefinition = level.get("level_definition") as LevelDefinition
	var definition_ok := definition \
		and definition.is_valid_definition() \
		and definition.level_id == "architecture_test" \
		and definition.shot_limit == 4 \
		and int(level.get("max_shots")) == 4 \
		and int(level.get("shots_remaining")) == 4
	print("PHASE2 proof_definition ok=", definition_ok)
	passed = definition_ok and passed

	var target: GoalTarget = level.get_node("Goal") as GoalTarget
	var moving: MovingObstacle = level.get_node("ProofMovingObstacle") as MovingObstacle
	var rotating: RotatingObstacle = level.get_node("ProofRotatingObstacle") as RotatingObstacle
	var timed_gate: TimedGate = level.get_node("ProofTimedGate") as TimedGate
	var components_ok := target and moving and rotating and timed_gate and target.geometry_matches_detector()
	print("PHASE2 proof_components ok=", components_ok)
	passed = components_ok and passed

	var proof_tuning := _shooting_tuning_signature(level)
	var tuning_ok := proof_tuning == baseline_tuning \
		and proof_tuning == "5.00|25.00|38.00|78.00"
	print("PHASE2 global_tuning_unchanged ok=", tuning_ok, " tuning=", proof_tuning)
	passed = tuning_ok and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	var initial_signature := _proof_reset_signature(moving, rotating, timed_gate)
	await _advance_frames(45)
	var moved_signature := _proof_reset_signature(moving, rotating, timed_gate)
	var moved_ok := moved_signature != initial_signature
	print("PHASE2 proof_motion_runs ok=", moved_ok)
	passed = moved_ok and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	var reset_signature := _proof_reset_signature(moving, rotating, timed_gate)
	var reset_ok := reset_signature == initial_signature
	print("PHASE2 proof_reset ok=", reset_ok)
	passed = reset_ok and passed

	await _advance_frames(30)
	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	var retry_signature_a := _proof_reset_signature(moving, rotating, timed_gate)
	await _advance_frames(15)
	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	var retry_signature_b := _proof_reset_signature(moving, rotating, timed_gate)
	var repeated_retry_ok := retry_signature_a == initial_signature \
		and retry_signature_b == initial_signature
	print("PHASE2 proof_repeated_retry ok=", repeated_retry_ok)
	passed = repeated_retry_ok and passed

	var shot_limit_ok := await _shoot_real(level, "proof_shot_limit", Vector2(170.0, -20.0)) \
		and int(level.get("shots_remaining")) == 3
	print("PHASE2 proof_shot_limit ok=", shot_limit_ok)
	passed = shot_limit_ok and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	level.set("shots_remaining", 1)
	level.set("shots_used", int(level.get("max_shots")) - 1)
	var final_launch_ok := await _shoot_real(level, "proof_final_goal_launch", Vector2(170.0, -20.0))
	var final_goal_scored := _score_active_shot(level, target)
	await physics_frame
	var final_goal_ok: bool = final_launch_ok \
		and final_goal_scored \
		and int(level.get("level_state")) == level.LevelState.GOAL \
		and not bool(level.get_node("UI/FailPanel").visible)
	print("PHASE2 final_shot_goal_beats_fail ok=", final_goal_ok)
	passed = final_goal_ok and passed

	level.queue_free()
	await process_frame
	return passed


func _shoot_real(level: Node, label: String, offset: Vector2) -> bool:
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var camera: Camera3D = level.get_node("Camera3D") as Camera3D
	var state_before: int = level.get("level_state")
	var shots_before: int = level.get("shots_remaining")
	_send_mouse_swipe(level, camera, ball, _line_offsets(offset, 8))
	await physics_frame
	await physics_frame
	var velocity: Vector3 = ball.linear_velocity
	var ok: bool = state_before == level.LevelState.READY \
		and int(level.get("level_state")) == level.LevelState.SHOT_ACTIVE \
		and int(level.get("shots_remaining")) == shots_before - 1 \
		and velocity.length() > 0.5 \
		and not ball.freeze
	print(
		"PHASE2 ", label,
		" ok=", ok,
		" before=", shots_before,
		" after=", level.get("shots_remaining"),
		" vel=", velocity
	)
	return ok


func _score_active_shot(level: Node, target: GoalTarget) -> bool:
	var active_shot_id: int = level.get("active_shot_id")
	target.reset_shot_tracking()
	target.begin_shot_tracking(active_shot_id, Vector3(0.0, 2.5, -8.0))
	return target.process_ball(Vector3(0.0, 2.5, -12.0), BALL_RADIUS, active_shot_id)


func _goal_visuals_match_target(target: GoalTarget) -> bool:
	var mouth_shape := target.get_node(
		"GoalDetection/GoalMouthTrigger/CollisionShape3D"
	) as CollisionShape3D
	var mouth_box := mouth_shape.shape as BoxShape3D
	var crossbar_mesh_instance := target.get_node("Crossbar/MeshInstance3D") as MeshInstance3D
	var crossbar_mesh := crossbar_mesh_instance.mesh as BoxMesh
	return (
		is_equal_approx(mouth_box.size.x, target.opening_half_width * 2.0)
		and is_equal_approx(mouth_box.size.y, target.crossbar_height)
		and is_equal_approx(crossbar_mesh.size.x, target.opening_half_width * 2.0 + target.post_radius * 2.0)
	)


func _proof_reset_signature(
	moving: MovingObstacle,
	rotating: RotatingObstacle,
	timed_gate: TimedGate
) -> String:
	return "%s||%s||%s" % [
		moving.get_reset_signature(),
		rotating.get_reset_signature(),
		timed_gate.get_reset_signature(),
	]


func _shooting_tuning_signature(level: Node) -> String:
	return "%.2f|%.2f|%.2f|%.2f" % [
		float(level.get("minimum_launch_speed")),
		float(level.get("maximum_launch_speed")),
		float(level.get("maximum_elevation_degrees")),
		float(level.get("maximum_curve_heading_degrees")),
	]


func _send_mouse_swipe(
	level: Node,
	camera: Camera3D,
	ball: RigidBody3D,
	offset_points: PackedVector2Array
) -> void:
	var start := camera.unproject_position(ball.global_position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	level._unhandled_input(press)

	for point_offset in offset_points:
		var motion := InputEventMouseMotion.new()
		motion.position = start + point_offset
		level._unhandled_input(motion)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start + offset_points[-1]
	level._unhandled_input(release)


func _wait_for_ready(level: Node, max_frames: int = 120) -> bool:
	for _i in range(max_frames):
		if int(level.get("level_state")) == level.LevelState.READY \
			and not bool(level.get("reset_in_progress")):
			return true
		await physics_frame
	return false


func _ready_ball_ok(level: Node) -> bool:
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	return (
		int(level.get("level_state")) == level.LevelState.READY
		and not ball.freeze
		and ball.linear_velocity.length() <= float(level.get("stopped_velocity_threshold"))
		and ball.angular_velocity.length() <= float(level.get("stopped_velocity_threshold"))
	)


func _line_offsets(offset: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(offset * (float(i + 1) / float(count)))
	return points


func _warmup() -> void:
	await process_frame
	await process_frame
	await physics_frame


func _advance_frames(count: int) -> void:
	for _i in range(count):
		await physics_frame
