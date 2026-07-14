extends SceneTree

const SOFT_RATIO := 0.2
const MEDIUM_RATIO := 0.55
const STRONG_RATIO := 0.95


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/prototype.tscn")
	var root: Node3D = scene.instantiate() as Node3D
	get_root().add_child(root)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame

	var controller: Node = get_root().get_node("Prototype")
	var ball: RigidBody3D = controller.get_node("Ball") as RigidBody3D
	var camera: Camera3D = controller.get_node("Camera3D") as Camera3D

	await controller._apply_physics_safe_reset()
	await physics_frame
	await physics_frame

	print("TRAJ spawn_y=", ball.global_position.y)

	for label_ratio in [["soft", SOFT_RATIO], ["medium", MEDIUM_RATIO], ["strong", STRONG_RATIO]]:
		await _shoot_and_measure(controller, ball, camera, label_ratio[0], label_ratio[1])

	quit()


func _shoot_and_measure(
	controller: Node,
	ball: RigidBody3D,
	camera: Camera3D,
	label: String,
	power_ratio: float
) -> void:
	await controller._apply_physics_safe_reset()
	await physics_frame
	await physics_frame

	var ball_screen := camera.unproject_position(ball.global_position)
	var swipe_distance: float = controller.get("effective_max_swipe_distance")
	var end := ball_screen + Vector2(0.0, -swipe_distance * power_ratio)
	var screen_delta := end - ball_screen
	var straight_samples := PackedVector2Array([
		ball_screen,
		ball_screen + screen_delta * 0.5,
		end,
	])
	var world_dir: Vector3 = controller._screen_swipe_to_world_direction(ball_screen, end)
	var impulse: Vector3 = controller._compute_shot_impulse(
		power_ratio, world_dir, straight_samples
	)

	ball.sleeping = false
	ball.apply_central_impulse(impulse)

	var peak_y := ball.global_position.y
	for _i in range(240):
		await physics_frame
		peak_y = maxf(peak_y, ball.global_position.y)

	print(
		"TRAJ ", label,
		" ratio=", power_ratio,
		" horizontal=", controller.get("last_horizontal_impulse"),
		" lift=", controller.get("last_lift_impulse"),
		" impulse=", impulse,
		" peak_y=", peak_y,
		" dir_z=", world_dir.z
	)
