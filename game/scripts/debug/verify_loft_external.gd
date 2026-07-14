extends SceneTree

const POWER_RATIO := 0.75


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/prototype.tscn")
	var root: Node3D = scene.instantiate() as Node3D
	get_root().add_child(root)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame

	var controller: Node = get_root().get_node("Prototype")
	var passed := true
	var world_dir := Vector3(0.0, 0.0, -1.0).normalized()

	var driven := _driven_swipe()
	controller.call("_analyze_elevation_from_samples", driven)
	var driven_cat: String = controller.get("current_shot_category")
	var driven_elev := float(controller.get("current_elevation_degrees"))
	var driven_ok := driven_cat == "DRIVEN" and driven_elev <= 18.0
	passed = passed and driven_ok
	print(
		"ELEV driven category=",
		driven_cat,
		" elev=",
		driven_elev,
		" ok=",
		driven_ok
	)

	var lofted := _lofted_swipe()
	controller.call("_analyze_elevation_from_samples", lofted)
	var lofted_cat: String = controller.get("current_shot_category")
	var lofted_intent := float(controller.get("current_elevation_intent"))
	var lofted_elev := float(controller.get("current_elevation_degrees"))
	var lofted_ok := lofted_cat == "LOB" and lofted_intent > 0.75 and lofted_elev >= 32.0
	passed = passed and lofted_ok
	print(
		"ELEV lofted category=",
		lofted_cat,
		" intent=",
		lofted_intent,
		" elev=",
		lofted_elev,
		" ok=",
		lofted_ok
	)

	var ground := _ground_swipe()
	controller.call("_analyze_elevation_from_samples", ground)
	var ground_cat: String = controller.get("current_shot_category")
	var ground_elev := float(controller.get("current_elevation_degrees"))
	var ground_ok := ground_cat == "GROUND" and ground_elev <= 1.0
	passed = passed and ground_ok
	print(
		"ELEV ground category=",
		ground_cat,
		" elev=",
		ground_elev,
		" ok=",
		ground_ok
	)

	controller._compute_launch_velocity(POWER_RATIO, world_dir, driven)
	var driven_lift := float(controller.get("last_vertical_launch_speed"))
	controller._compute_launch_velocity(POWER_RATIO, world_dir, lofted)
	var lofted_lift := float(controller.get("last_vertical_launch_speed"))
	controller._compute_launch_velocity(POWER_RATIO, world_dir, ground)
	var ground_lift := float(controller.get("last_vertical_launch_speed"))
	var lift_ok := (
		driven_lift >= 0.5
		and driven_lift <= 3.0
		and lofted_lift >= 10.0
		and lofted_lift > driven_lift * 3.0
		and ground_lift <= 0.35
	)
	passed = passed and lift_ok
	print(
		"ELEV lift driven=",
		driven_lift,
		" lofted=",
		lofted_lift,
		" ground=",
		ground_lift,
		" ok=",
		lift_ok
	)

	print("ELEV verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _driven_swipe() -> PackedVector2Array:
	# Nearly horizontal mild-up swipe -> low driven elevation.
	return _line_swipe(Vector2(400.0, 550.0), Vector2(580.0, 540.0))


func _lofted_swipe() -> PackedVector2Array:
	# Sharply upward overall swipe -> high elevation.
	return _line_swipe(Vector2(420.0, 680.0), Vector2(460.0, 240.0))


func _ground_swipe() -> PackedVector2Array:
	# Downward overall swipe -> ground skim.
	return _line_swipe(Vector2(420.0, 360.0), Vector2(520.0, 620.0))


func _line_swipe(start: Vector2, end: Vector2) -> PackedVector2Array:
	var samples := PackedVector2Array()
	var count := 11
	for i in count:
		var t := float(i) / float(count - 1)
		samples.append(start.lerp(end, t))
	return samples
