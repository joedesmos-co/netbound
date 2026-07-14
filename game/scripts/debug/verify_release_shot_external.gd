extends SceneTree

const START := Vector2(400.0, 620.0)
const END := Vector2(500.0, 420.0)


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

	var samples := PackedVector2Array()
	for i in 11:
		samples.append(START.lerp(END, float(i) / 10.0))

	level.set("is_swiping", true)
	level.set("active_pointer_id", -2)
	level.set("swipe_screen_points", samples)
	level.call("_recalculate_swipe_state")

	var valid := bool(level.get("is_swipe_valid"))
	var launch_velocity: Vector3 = level.call(
		"_compute_launch_velocity",
		level.get("current_power_ratio"),
		level.get("current_shot_direction"),
		samples
	)

	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.linear_velocity = launch_velocity
	var vel_after := ball.linear_velocity
	await physics_frame
	var vel_next := ball.linear_velocity

	print("RELEASE_TEST valid=", valid, " launch_velocity=", launch_velocity)
	print("RELEASE_TEST vel_after=", vel_after, " vel_next=", vel_next)

	passed = passed and valid
	passed = passed and launch_velocity.length() > 0.1
	passed = passed and vel_next.length() > 0.05

	level.set("is_swiping", true)
	level.set("active_pointer_id", -2)
	level.set("swipe_screen_points", samples)
	level.call("_commit_swipe_release_sample", END)
	level.call("_recalculate_swipe_state")
	level.call("_fire_shot")

	await physics_frame
	var fired_vel := ball.linear_velocity
	var fired_moved := ball.global_position.distance_to(Vector3(0, 0.67, 0)) > 0.05
	print("RELEASE_TEST fire_path vel=", fired_vel, " moved=", fired_moved)
	passed = passed and fired_vel.length() > 0.05
	passed = passed and fired_moved

	print("RELEASE_TEST verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)
