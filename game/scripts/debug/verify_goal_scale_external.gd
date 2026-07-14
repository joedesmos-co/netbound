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

	print("SCALE goal_z=", goal.global_position.z)
	print("SCALE opening_width=", opening_width)
	print("SCALE crossbar_underside=", crossbar_underside)
	print("SCALE post_half_width=", detector.post_half_width)
	print("SCALE crossbar_height=", detector.crossbar_height)
	print("SCALE goal_line_z=", detector.goal_line_z)
	print("SCALE ball_radius_export=", level.get("ball_radius"))

	var goal_line_z := detector.goal_line_z
	var valid := Vector3(0.0, 3.0, goal_line_z - BALL_RADIUS - 0.2)
	var wide_miss := Vector3(detector.post_half_width + 0.8, 3.0, goal_line_z - BALL_RADIUS - 0.2)
	var high_miss := Vector3(0.0, detector.crossbar_height + 0.8, goal_line_z - BALL_RADIUS - 0.2)
	var not_crossed := Vector3(0.0, 3.0, goal_line_z + 0.5)

	print("SCALE scores_valid=", detector.is_ball_fully_in_goal(valid, BALL_RADIUS))
	print("SCALE scores_wide_miss=", detector.is_ball_fully_in_goal(wide_miss, BALL_RADIUS))
	print("SCALE scores_high_miss=", detector.is_ball_fully_in_goal(high_miss, BALL_RADIUS))
	print("SCALE scores_not_crossed=", detector.is_ball_fully_in_goal(not_crossed, BALL_RADIUS))

	var corners := [
		left_post.global_position + Vector3(POST_RADIUS, 8.4, 0.0),
		right_post.global_position + Vector3(-POST_RADIUS, 8.4, 0.0),
		goal.global_position + Vector3(0.0, 0.0, -5.0),
	]
	print(
		"SCALE goal_in_frustum=",
		camera.is_position_in_frustum(corners[0]) and camera.is_position_in_frustum(corners[1])
	)
	print("SCALE opening_minus_ball=", opening_width - (BALL_RADIUS * 2.0))

	quit()
