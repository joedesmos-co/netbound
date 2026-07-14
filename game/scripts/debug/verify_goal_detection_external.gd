extends SceneTree

const RADIUS := 0.49
const GOAL_Z := -10.0
const CENTER_X := 0.0
const HALF_W := 11.0
const BAR_H := 8.4


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
	var detector: GoalDetector = level.get_node("Goal/GoalDetection") as GoalDetector
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var left_post: Node3D = level.get_node("Goal/LeftPost") as Node3D
	var right_post: Node3D = level.get_node("Goal/RightPost") as Node3D
	var crossbar: Node3D = level.get_node("Goal/Crossbar") as Node3D
	var passed := true

	detector.sync_geometry(GOAL_Z, CENTER_X, HALF_W, BAR_H, 5.0, RADIUS)

	var opening := (right_post.global_position.x - 0.28) - (left_post.global_position.x + 0.28)
	var bar_underside := crossbar.global_position.y - 0.14
	print("SCALE_LIVE opening=", opening, " bar_underside=", bar_underside, " ball_r=", ball.get_node("CollisionShape3D").shape.radius)
	passed = passed and is_equal_approx(opening, 22.0)
	passed = passed and is_equal_approx(bar_underside, 8.4)

	passed = _check_case(detector, "center", Vector3(0, 3, -8.5), Vector3(0, 3, -12.5), true) and passed
	passed = _check_case(detector, "inside_left", Vector3(-9.5, 3, -8.5), Vector3(-10.0, 3, -12.5), true) and passed
	passed = _check_case(detector, "inside_right", Vector3(9.5, 3, -8.5), Vector3(10.0, 3, -12.5), true) and passed
	passed = _check_case(
		detector,
		"diagonal_side_net",
		Vector3(-8.0, 3, -8.5),
		Vector3(-10.8, 2.2, -13.0),
		true
	) and passed
	passed = _check_case(
		detector,
		"ground_hugging",
		Vector3(0, 0.52, -8.5),
		Vector3(0, 0.51, -12.0),
		true
	) and passed
	passed = _check_case(
		detector,
		"wide_miss",
		Vector3(12.0, 3, -8.5),
		Vector3(12.5, 3, -12.5),
		false
	) and passed
	passed = _check_case(
		detector,
		"over_bar",
		Vector3(0, 8.5, -8.5),
		Vector3(0, 8.8, -12.5),
		false
	) and passed
	passed = _check_case(
		detector,
		"from_behind",
		Vector3(0, 3, -12.5),
		Vector3(0, 3, -8.5),
		false
	) and passed

	detector.sync_geometry(GOAL_Z, -4.0, HALF_W, BAR_H, 5.0, RADIUS)
	passed = _check_case(
		detector,
		"off_center_inside_left",
		Vector3(-13.0, 3, -8.5),
		Vector3(-13.6, 3, -12.5),
		true
	) and passed
	passed = _check_case(
		detector,
		"off_center_outside_right",
		Vector3(8.0, 3, -8.5),
		Vector3(8.5, 3, -12.5),
		false
	) and passed
	detector.sync_geometry(GOAL_Z, CENTER_X, HALF_W, BAR_H, 5.0, RADIUS)

	# Live-style production path: fire tracking then physics-like positions.
	detector.begin_shot_tracking(7, Vector3(-9.0, 2.5, -8.0))
	var live_score := detector.process_ball(Vector3(-10.5, 2.0, -12.8), RADIUS, 7)
	print("SCALE_LIVE side_entry_score=", live_score)
	passed = passed and live_score

	print("SCALE_LIVE verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _check_case(
	detector: GoalDetector,
	label: String,
	start: Vector3,
	end: Vector3,
	should_score: bool
) -> bool:
	detector.reset_shot_tracking()
	detector.begin_shot_tracking(1, start)
	var scored := detector.process_ball(end, RADIUS, 1)
	var ok := scored == should_score
	print("GOAL_DET ", label, " scored=", scored, " expected=", should_score, " ok=", ok)
	return ok
