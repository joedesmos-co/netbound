extends SceneTree

const MOUSE_POINTER_ID := -2
const BALL_RADIUS := 0.49


func _initialize() -> void:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var root: Node3D = scene.instantiate() as Node3D
	get_root().add_child(root)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	await process_frame

	var level: Node = get_root().get_node("Level01")
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var camera: Camera3D = level.get_node("Camera3D") as Camera3D
	var detector: GoalDetector = level.get_node("Goal/GoalDetection") as GoalDetector
	var passed := true

	level.set("max_shots", 12)
	await level._restart_level()
	await _wait_for_ready(level)

	passed = await _shoot_real(level, ball, camera, "fresh_launch", Vector2(170.0, -20.0)) and passed

	await level._on_reset_button_pressed()
	passed = await _wait_for_ready(level) and passed
	passed = _ready_ball_ok(level, ball) and passed
	passed = await _shoot_real(level, ball, camera, "after_reset", Vector2(170.0, -20.0)) and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	passed = await _shoot_real(level, ball, camera, "after_retry", Vector2(170.0, -20.0)) and passed

	level.call("_on_goal_scored")
	var goal_state_ok: bool = int(level.get("level_state")) == level.LevelState.GOAL
	await level._restart_level()
	passed = goal_state_ok and await _wait_for_ready(level) and passed
	passed = await _shoot_real(level, ball, camera, "score_retry_shoot", Vector2(170.0, -20.0)) and passed

	level.call("_resolve_miss", level.get("active_shot_id"), "test_miss")
	passed = await _wait_for_ready(level, 180) and passed
	passed = await _shoot_real(level, ball, camera, "after_auto_reset", Vector2(170.0, -20.0)) and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	var invalid_before: int = level.get("shots_remaining")
	_send_mouse_swipe(level, camera, ball, _line_offsets(Vector2(6.0, -2.0), 3))
	await physics_frame
	var invalid_after: int = level.get("shots_remaining")
	var invalid_ok: bool = invalid_before == invalid_after and int(level.get("level_state")) == level.LevelState.READY
	print("PHASE1 invalid_swipe ok=", invalid_ok, " before=", invalid_before, " after=", invalid_after)
	passed = invalid_ok and passed

	var ground_peak := await _measure_direct_peak(level, ball, _ground_samples(), "ground")
	var driven_peak := await _measure_direct_peak(level, ball, _driven_samples(), "driven")
	var air_peak := await _measure_direct_peak(level, ball, _air_samples(), "air")
	var lob_peak := await _measure_direct_peak(level, ball, _lob_samples(), "lob")
	var height_ok := (
		ground_peak >= 0.5 and ground_peak <= 0.85
		and driven_peak >= 1.0 and driven_peak <= 2.0
		and air_peak >= 3.0 and air_peak <= 7.0
		and lob_peak >= 10.0 and lob_peak <= 18.0
	)
	print(
		"PHASE1 heights ground=", ground_peak,
		" driven=", driven_peak,
		" air=", air_peak,
		" lob=", lob_peak,
		" ok=", height_ok
	)
	passed = height_ok and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	var mild_curve := _measure_curve_rotation(level, "mild_curve", 0.25, 1.0 / 60.0)
	var strong_curve := _measure_curve_rotation(level, "strong_curve", 0.5, 1.0 / 60.0)
	var extreme_curve := _measure_curve_rotation(level, "extreme_curve", 1.0, 1.0 / 60.0)
	var extreme_curve_30hz := _measure_curve_rotation(level, "extreme_curve_30hz", 1.0, 1.0 / 30.0)
	var curve_ok := (
		mild_curve >= 10.0 and mild_curve <= 30.0
		and strong_curve >= 25.0 and strong_curve <= 55.0
		and extreme_curve >= 50.0 and extreme_curve <= 80.0
		and absf(extreme_curve - extreme_curve_30hz) <= 1.0
	)
	print(
		"PHASE1 curves mild=", mild_curve,
		" strong=", strong_curve,
		" extreme=", extreme_curve,
		" extreme_30hz=", extreme_curve_30hz,
		" ok=", curve_ok
	)
	passed = curve_ok and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	passed = await _shoot_real(level, ball, camera, "curve_lob", Vector2(70.0, -260.0), 50.0) and passed
	var camera_ok := await _verify_camera_follow_and_return(level, ball, camera)
	passed = camera_ok and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	passed = await _shoot_real(level, ball, camera, "final_shot_goal_launch", Vector2(170.0, -20.0)) and passed
	level.call("_on_goal_scored")
	var final_goal_ok: bool = int(level.get("level_state")) == level.LevelState.GOAL \
		and not bool(level.get_node("UI/FailPanel").visible)
	print("PHASE1 final_goal ok=", final_goal_ok)
	passed = final_goal_ok and passed

	await level._restart_level()
	passed = await _wait_for_ready(level) and passed
	level.set("shots_remaining", 1)
	level.set("shots_used", 2)
	passed = await _shoot_real(level, ball, camera, "final_shot_miss_launch", Vector2(170.0, -20.0)) and passed
	level.call("_resolve_miss", level.get("active_shot_id"), "test_final_miss")
	var final_miss_ok: bool = int(level.get("level_state")) == level.LevelState.FAILED \
		and bool(level.get_node("UI/FailPanel").visible)
	print("PHASE1 final_miss ok=", final_miss_ok)
	passed = final_miss_ok and passed

	detector.reset_shot_tracking()
	detector.begin_shot_tracking(77, Vector3(-9.0, 2.5, -8.0))
	var side_net_ok := detector.process_ball(Vector3(-10.5, 2.0, -12.8), BALL_RADIUS, 77)
	print("PHASE1 side_net_goal ok=", side_net_ok)
	passed = side_net_ok and passed

	await level._restart_level()
	level.set("max_shots", 12)
	await _wait_for_ready(level)
	var reset_cycles_ok := true
	for i in 5:
		reset_cycles_ok = await _shoot_real(
			level,
			ball,
			camera,
			"reset_cycle_%d" % i,
			Vector2(170.0, -20.0)
		) and reset_cycles_ok
		await level._on_reset_button_pressed()
		reset_cycles_ok = await _wait_for_ready(level) and _ready_ball_ok(level, ball) and reset_cycles_ok
	print("PHASE1 reset_cycles ok=", reset_cycles_ok)
	passed = reset_cycles_ok and passed

	var retry_cycles_ok := true
	for i in 5:
		await level._restart_level()
		retry_cycles_ok = await _wait_for_ready(level) and retry_cycles_ok
		retry_cycles_ok = await _shoot_real(
			level,
			ball,
			camera,
			"retry_cycle_%d" % i,
			Vector2(170.0, -20.0)
		) and retry_cycles_ok
	print("PHASE1 retry_cycles ok=", retry_cycles_ok)
	passed = retry_cycles_ok and passed

	print("PHASE1 verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _shoot_real(
	level: Node,
	ball: RigidBody3D,
	camera: Camera3D,
	label: String,
	offset: Vector2,
	curve_px: float = 0.0
) -> bool:
	var state_before: int = level.get("level_state")
	var shots_before: int = level.get("shots_remaining")
	var points := _curve_offsets(offset, curve_px, 13)
	_send_mouse_swipe(level, camera, ball, points)
	await physics_frame
	await physics_frame

	var velocity: Vector3 = ball.linear_velocity
	var shot_active: bool = int(level.get("level_state")) == level.LevelState.SHOT_ACTIVE
	var consumed_once := int(level.get("shots_remaining")) == shots_before - 1
	var launched := velocity.length() > 0.5 and not ball.freeze
	var ok: bool = state_before == level.LevelState.READY and shot_active and consumed_once and launched
	print(
		"PHASE1 ", label,
		" ok=", ok,
		" state=", level.get("level_state"),
		" shots_before=", shots_before,
		" shots_after=", level.get("shots_remaining"),
		" velocity=", velocity,
		" category=", level.get("last_shot_category"),
		" curve_cap=", level.get("last_curve_heading_degrees")
	)
	return ok


func _measure_curve_rotation(level: Node, label: String, curve_amount: float, delta: float) -> float:
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var initial_velocity := Vector3(0.0, 0.0, -16.0)
	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = initial_velocity
	ball.angular_velocity = Vector3.ZERO
	level.call("_begin_bounded_curve", 1.0, curve_amount, initial_velocity)
	var start_dir := Vector3(initial_velocity.x, 0.0, initial_velocity.z).normalized()
	var cap := float(level.get("last_curve_heading_degrees"))
	for _i in range(180):
		level.call("_apply_arcade_curve", delta)
		if absf(float(level.get("active_curve_remaining_heading_radians"))) <= 0.001:
			break
	var current_velocity := ball.linear_velocity
	var current_dir := Vector3(current_velocity.x, 0.0, current_velocity.z).normalized()
	var measured := absf(rad_to_deg(level.call("_signed_horizontal_angle", start_dir, current_dir)))
	print("PHASE1 ", label, " measured=", measured, " cap=", cap)
	return measured


func _verify_camera_follow_and_return(level: Node, ball: RigidBody3D, camera: Camera3D) -> bool:
	var setup_position: Vector3 = level.get("camera_position")
	var highest_camera_y := camera.global_position.y
	for _i in range(90):
		await physics_frame
		highest_camera_y = maxf(highest_camera_y, camera.global_position.y)

	await level._restart_level()
	var ready := await _wait_for_ready(level)
	for _i in range(180):
		await physics_frame
	var returned := camera.global_position.distance_to(setup_position) <= 1.25
	var followed := highest_camera_y >= setup_position.y + 1.0
	var ok := ready and followed and returned and _ready_ball_ok(level, ball)
	print(
		"PHASE1 camera ok=", ok,
		" highest_y=", highest_camera_y,
		" setup_y=", setup_position.y,
		" returned_distance=", camera.global_position.distance_to(setup_position)
	)
	return ok


func _measure_direct_peak(
	level: Node,
	ball: RigidBody3D,
	samples: PackedVector2Array,
	label: String
) -> float:
	await level._restart_level()
	await _wait_for_ready(level)
	level.set("swipe_screen_points", samples)
	level.call("_recalculate_swipe_state")
	var velocity: Vector3 = level.call(
		"_compute_launch_velocity",
		level.get("current_power_ratio"),
		level.get("current_shot_direction"),
		samples
	)
	ball.freeze = false
	ball.sleeping = false
	ball.global_position.y = maxf(
		ball.global_position.y,
		float(level.get("ball_radius"))
		+ float(level.get("ball_ground_clearance"))
		+ float(level.get("launch_clearance_boost"))
	)
	ball.linear_velocity = velocity
	ball.angular_velocity = Vector3.ZERO
	var peak_y := ball.global_position.y
	for _i in range(240):
		await physics_frame
		peak_y = maxf(peak_y, ball.global_position.y)
	print(
		"PHASE1 direct_peak ", label,
		" peak=", peak_y,
		" velocity=", velocity,
		" category=", level.get("last_shot_category"),
		" elev=", level.get("last_elevation_degrees")
	)
	return peak_y


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


func _wait_for_ready(level: Node, max_frames: int = 90) -> bool:
	for _i in range(max_frames):
		if int(level.get("level_state")) == level.LevelState.READY \
			and not bool(level.get("reset_in_progress")):
			return true
		await physics_frame
	return false


func _ready_ball_ok(level: Node, ball: RigidBody3D) -> bool:
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


func _curve_offsets(offset: Vector2, curve_px: float, count: int) -> PackedVector2Array:
	if absf(curve_px) <= 0.001:
		return _line_offsets(offset, count)
	var points := PackedVector2Array()
	var perpendicular := Vector2(-offset.y, offset.x).normalized()
	for i in count:
		var t := float(i + 1) / float(count)
		var bend := sin(t * PI) * curve_px
		points.append((offset * t) + (perpendicular * bend))
	return points


func _ground_samples() -> PackedVector2Array:
	return _samples(Vector2(420.0, 360.0), Vector2(520.0, 620.0))


func _driven_samples() -> PackedVector2Array:
	return _samples(Vector2(300.0, 550.0), Vector2(620.0, 500.0))


func _air_samples() -> PackedVector2Array:
	return _samples(Vector2(300.0, 640.0), Vector2(600.0, 360.0))


func _lob_samples() -> PackedVector2Array:
	return _samples(Vector2(420.0, 680.0), Vector2(460.0, 240.0))


func _samples(start: Vector2, end: Vector2) -> PackedVector2Array:
	var samples := PackedVector2Array()
	var count := 11
	for i in count:
		samples.append(start.lerp(end, float(i) / float(count - 1)))
	return samples
