extends SceneTree

const BALL_RADIUS := 0.49
const POST_RADIUS := 0.28
const TARGET_OPENING_WIDTH := 22.0
const TARGET_CROSSBAR_UNDERSIDE := 8.4


func _initialize() -> void:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var root: Node3D = scene.instantiate() as Node3D
	get_root().add_child(root)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame

	var level: Node = get_root().get_node("Level01")
	var camera: Camera3D = level.get_node("Camera3D") as Camera3D
	var detector: GoalDetector = level.get_node("Goal/GoalDetection") as GoalDetector
	var goal: Node3D = level.get_node("Goal") as Node3D
	var left_post: Node3D = level.get_node("Goal/LeftPost") as Node3D
	var right_post: Node3D = level.get_node("Goal/RightPost") as Node3D
	var crossbar: Node3D = level.get_node("Goal/Crossbar") as Node3D

	var opening_width := (right_post.global_position.x - POST_RADIUS) - (
		left_post.global_position.x + POST_RADIUS
	)
	var crossbar_underside := crossbar.global_position.y - 0.14
	print("ARCADE opening_width=", opening_width)
	print("ARCADE crossbar_underside=", crossbar_underside)
	print("ARCADE goal_z=", goal.global_position.z)

	var goal_line_z := detector.goal_line_z
	var valid := Vector3(0.0, 3.0, goal_line_z - BALL_RADIUS - 0.2)
	var wide_miss := Vector3(detector.post_half_width + 0.8, 3.0, goal_line_z - BALL_RADIUS - 0.2)
	var high_miss := Vector3(0.0, detector.crossbar_height + 0.8, goal_line_z - BALL_RADIUS - 0.2)
	var not_crossed := Vector3(0.0, 3.0, goal_line_z + 0.5)

	var passed := true
	passed = passed and is_equal_approx(opening_width, TARGET_OPENING_WIDTH)
	passed = passed and is_equal_approx(crossbar_underside, TARGET_CROSSBAR_UNDERSIDE)
	passed = passed and detector.is_ball_fully_in_goal(valid, BALL_RADIUS)
	passed = passed and not detector.is_ball_fully_in_goal(wide_miss, BALL_RADIUS)
	passed = passed and not detector.is_ball_fully_in_goal(high_miss, BALL_RADIUS)
	passed = passed and not detector.is_ball_fully_in_goal(not_crossed, BALL_RADIUS)

	var corners := [
		left_post.global_position + Vector3(POST_RADIUS, 8.4, 0.0),
		right_post.global_position + Vector3(-POST_RADIUS, 8.4, 0.0),
		goal.global_position + Vector3(0.0, 0.0, -5.0),
	]
	for corner in corners:
		passed = passed and camera.is_position_in_frustum(corner)

	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	await level._apply_physics_safe_reset()
	await physics_frame
	await physics_frame
	var spawn_y := ball.global_position.y

	var driven_peak := await _shoot_samples(level, ball, _driven_swipe(), "DRIVEN")
	var lofted_peak := await _shoot_samples(level, ball, _lofted_swipe(), "LOFTED")
	var ground_peak := await _shoot_samples(level, ball, _ground_swipe(), "GROUND")

	passed = passed and driven_peak > spawn_y + 0.35
	passed = passed and lofted_peak > 2.5
	passed = passed and lofted_peak > driven_peak + 0.6
	passed = passed and ground_peak <= spawn_y + 0.35
	print("ARCADE peak_spawn=", spawn_y)
	print("ARCADE peak_driven=", driven_peak)
	print("ARCADE peak_lofted=", lofted_peak)
	print("ARCADE peak_ground=", ground_peak)
	print("ARCADE verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _shoot_samples(level: Node, ball: RigidBody3D, samples: PackedVector2Array, label: String) -> float:
	await level._apply_physics_safe_reset()
	await physics_frame
	await physics_frame

	level.set("swipe_screen_points", samples)
	level.call("_recalculate_swipe_state")

	var impulse: Vector3 = level.call(
		"_compute_shot_impulse",
		level.get("current_power_ratio"),
		level.get("current_shot_direction"),
		samples
	)
	var launch_mass := maxf(ball.mass, 0.001)
	var launch_velocity := impulse / launch_mass

	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position.y = maxf(
		ball.global_position.y,
		float(level.get("ball_radius"))
		+ float(level.get("ball_ground_clearance"))
		+ float(level.get("launch_clearance_boost"))
	)
	ball.linear_velocity = launch_velocity
	level.set("tracking_shot_peak", true)
	level.set("shot_peak_y", ball.global_position.y)
	level.set("last_post_shot_y_velocity", launch_velocity.y)

	var peak_y := ball.global_position.y
	for frame_i in range(5):
		await physics_frame
		if frame_i == 0 and impulse.y >= float(level.get("launch_y_restore_threshold")):
			if ball.linear_velocity.y < launch_velocity.y * 0.45:
				var restored := ball.linear_velocity
				restored.y = launch_velocity.y
				ball.linear_velocity = restored
		peak_y = maxf(peak_y, ball.global_position.y)

	for _i in range(180):
		await physics_frame
		peak_y = maxf(peak_y, ball.global_position.y)

	print(
		"ARCADE shot=",
		label,
		" category=",
		level.get("last_shot_category"),
		" elev=",
		level.get("last_elevation_degrees"),
		" lift=",
		level.get("last_lift_impulse"),
		" peak=",
		peak_y
	)
	return peak_y


func _driven_swipe() -> PackedVector2Array:
	return _line_swipe(Vector2(400.0, 550.0), Vector2(580.0, 540.0))


func _lofted_swipe() -> PackedVector2Array:
	return _line_swipe(Vector2(420.0, 680.0), Vector2(460.0, 240.0))


func _ground_swipe() -> PackedVector2Array:
	return _line_swipe(Vector2(420.0, 360.0), Vector2(520.0, 620.0))


func _line_swipe(start: Vector2, end: Vector2) -> PackedVector2Array:
	var samples := PackedVector2Array()
	var count := 11
	for i in count:
		var t := float(i) / float(count - 1)
		samples.append(start.lerp(end, t))
	return samples
