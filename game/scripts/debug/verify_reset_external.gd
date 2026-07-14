extends SceneTree

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
	var spawn: Marker3D = controller.get_node("BallSpawn") as Marker3D
	var reset_button: Button = controller.get_node("UI/TopLeftUI/ResetButton") as Button

	print("EXT startup=", ball.global_position)
	for i in range(3):
		await process_frame
	print("EXT after_3_frames=", ball.global_position)

	ball.global_position = Vector3(6, 0.65, -10)
	ball.linear_velocity = Vector3(2, 0, -5)
	reset_button.emit_signal("pressed")
	await process_frame
	await process_frame
	await process_frame
	print("EXT reset_immediate=", ball.global_position)
	await process_frame
	print("EXT reset_frame+1=", ball.global_position, " vel=", ball.linear_velocity)
	print("EXT spawn=", spawn.global_position)
	print("EXT ok=", ball.global_position.distance_to(spawn.global_position) < 0.01)
	quit()
