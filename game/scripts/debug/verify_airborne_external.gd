extends SceneTree


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
	var passed := true

	await level._apply_physics_safe_reset()
	await physics_frame
	await physics_frame
	var spawn_y := ball.global_position.y
	print("AIR spawn_y=", spawn_y, " radius=", level.get("ball_radius"))

	var driven := await _measure(level, ball, _driven_swipe(), "DRIVEN")
	var lofted := await _measure(level, ball, _lofted_swipe(), "LOFTED")
	var ground := await _measure(level, ball, _ground_swipe(), "GROUND")

	print("AIR driven_peak=", driven)
	print("AIR lofted_peak=", lofted)
	print("AIR ground_peak=", ground)

	passed = passed and driven > spawn_y + 0.55
	passed = passed and lofted > 3.4
	passed = passed and lofted > driven + 0.8
	passed = passed and ground < spawn_y + 0.35
	print("AIR verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _measure(level: Node, ball: RigidBody3D, samples: PackedVector2Array, label: String) -> float:
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

	var peak_y := ball.global_position.y
	for frame_i in range(5):
		await physics_frame
		if frame_i == 0 and impulse.y >= float(level.get("launch_y_restore_threshold")):
			if ball.linear_velocity.y < launch_velocity.y * 0.45:
				var restored := ball.linear_velocity
				restored.y = launch_velocity.y
				ball.linear_velocity = restored
		print(
			"AIR ", label, " frame=", frame_i + 1,
			" y=", ball.global_position.y,
			" vy=", ball.linear_velocity.y
		)
		peak_y = maxf(peak_y, ball.global_position.y)

	for _i in range(120):
		await physics_frame
		peak_y = maxf(peak_y, ball.global_position.y)

	print(
		"AIR ", label,
		" peak=", peak_y,
		" elev=", level.get("last_elevation_degrees"),
		" lift=", level.get("last_lift_impulse"),
		" category=", level.get("last_shot_category")
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
		samples.append(start.lerp(end, float(i) / float(count - 1)))
	return samples
