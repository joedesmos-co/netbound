extends SceneTree

## Production release-path regression probe for level_01.tscn


func _initialize() -> void:
	var scene: PackedScene = load("res://levels/level_01.tscn")
	var root: Node3D = scene.instantiate() as Node3D
	get_root().add_child(root)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	await process_frame
	await process_frame

	var level: Node = get_root().get_node("Level01")
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var camera: Camera3D = level.get_node("Camera3D") as Camera3D
	var passed := true

	# Case A: normal READY launch
	passed = await _shoot_once(level, ball, camera, "normal", false) and passed

	# Case B: ball left frozen after GOAL-like state (the live regression)
	await level._restart_level()
	await process_frame
	ball.freeze = true
	ball.sleeping = true
	passed = await _shoot_once(level, ball, camera, "from_frozen", true) and passed

	# Case C: Retry then shoot five cycles
	for i in 5:
		await level._restart_level()
		await process_frame
		var ok := await _shoot_once(level, ball, camera, "retry_%d" % i, false)
		passed = passed and ok
		await process_frame

	print("REGRESS final=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _shoot_once(
	level: Node,
	ball: RigidBody3D,
	camera: Camera3D,
	label: String,
	start_frozen: bool
) -> bool:
	level.set("level_state", level.LevelState.READY)
	level.set("shots_remaining", 3)
	level.set("reset_in_progress", false)

	var ball_screen: Vector2 = camera.unproject_position(ball.global_position)
	var end: Vector2 = ball_screen + Vector2(8.0, -210.0)

	print(
		"REGRESS ", label,
		" start_frozen=", start_frozen,
		" freeze=", ball.freeze,
		" state=", level.get("level_state"),
		" reset_in_progress=", level.get("reset_in_progress")
	)

	level.call("_begin_swipe", ball_screen, -2)
	for i in 10:
		level.call("_update_swipe", ball_screen.lerp(end, float(i) / 9.0))

	var state_before = level.get("level_state")
	var freeze_before := ball.freeze
	level.call("_end_swipe", end, -2)

	var impulse: Vector3 = level.get("last_final_impulse")
	var vel_immediate := ball.linear_velocity
	print(
		"REGRESS ", label,
		" distance_ok samples fired impulse=", impulse,
		" state_before=", state_before,
		" state_after=", level.get("level_state"),
		" freeze_before=", freeze_before,
		" freeze_after=", ball.freeze,
		" vel_immediate=", vel_immediate
	)

	await physics_frame
	var vel1 := ball.linear_velocity
	print(
		"REGRESS ", label,
		" vel_frame+1=", vel1,
		" safeguard=", level.get("launch_safeguard_pending")
	)
	await physics_frame
	await physics_frame

	var xz := Vector2(ball.linear_velocity.x, ball.linear_velocity.z).length()
	var moved := ball.global_position.distance_to(Vector3(0.0, ball.global_position.y, 0.0)) > 0.2 \
		or absf(ball.global_position.z) > 0.2
	var ok := (
		impulse.length() > 1.0
		and not ball.freeze
		and vel_immediate.length() > 0.5
		and xz > 0.5
		and moved
	)
	print("REGRESS ", label, " ok=", ok, " xz=", xz, " moved=", moved)
	return ok
