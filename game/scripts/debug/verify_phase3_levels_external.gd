extends SceneTree

const BALL_RADIUS := 0.49
const BASE_TUNING := "5.00|25.00|38.00|78.00"
const BASE_BALL_TUNING := "0.49|0.43|0.08|0.25|0.28|0.22"
const LEVEL_CONTROLLER_SCRIPT := "res://scripts/level_controller.gd"
const DEBUG_SCRIPT_PREFIX := "res://scripts/debug/"

const LEVEL_SPECS := [
	{
		"scene": "res://levels/level_01.tscn",
		"id": "level_01",
		"next": "level_02",
		"shots": 3,
		"par": 1,
		"offset": Vector2(0.0, -220.0),
		"curve": 0.0,
		"wait": 0.0,
	},
	{
		"scene": "res://levels/level_02.tscn",
		"id": "level_02",
		"next": "level_03",
		"shots": 3,
		"par": 1,
		"offset": Vector2(0.0, -230.0),
		"curve": 0.0,
		"wait": 0.25,
	},
	{
		"scene": "res://levels/level_03.tscn",
		"id": "level_03",
		"next": "level_04",
		"shots": 3,
		"par": 1,
		"offset": Vector2(18.0, -235.0),
		"curve": 0.0,
		"wait": 0.0,
	},
	{
		"scene": "res://levels/level_04.tscn",
		"id": "level_04",
		"next": "level_05",
		"shots": 4,
		"par": 2,
		"offset": Vector2(-145.0, -245.0),
		"curve": -12.0,
		"wait": 0.0,
	},
	{
		"scene": "res://levels/level_05.tscn",
		"id": "level_05",
		"next": "level_06",
		"shots": 4,
		"par": 2,
		"offset": Vector2(0.0, -235.0),
		"curve": 0.0,
		"wait": 0.0,
	},
	{
		"scene": "res://levels/level_06.tscn",
		"id": "level_06",
		"next": "level_07",
		"shots": 3,
		"par": 1,
		"offset": Vector2(0.0, -135.0),
		"curve": 0.0,
		"wait": 0.0,
	},
	{
		"scene": "res://levels/level_07.tscn",
		"id": "level_07",
		"next": "level_08",
		"shots": 4,
		"par": 2,
		"offset": Vector2(0.0, -230.0),
		"curve": 0.0,
		"wait": 0.45,
	},
	{
		"scene": "res://levels/level_08.tscn",
		"id": "level_08",
		"next": "level_09",
		"shots": 4,
		"par": 2,
		"offset": Vector2(135.0, -185.0),
		"curve": 0.0,
		"wait": 0.0,
	},
	{
		"scene": "res://levels/level_09.tscn",
		"id": "level_09",
		"next": "level_10",
		"shots": 5,
		"par": 3,
		"offset": Vector2(0.0, -230.0),
		"curve": 0.0,
		"wait": 0.45,
	},
	{
		"scene": "res://levels/level_10.tscn",
		"id": "level_10",
		"next": "level_11",
		"shots": 5,
		"par": 3,
		"offset": Vector2(-4.0, -305.0),
		"curve": -4.0,
		"wait": 0.5,
	},
	{
		"scene": "res://levels/level_11.tscn",
		"id": "level_11", "next": "level_12", "shots": 4, "par": 2,
		"offset": Vector2(25.0, -230.0), "curve": 11.0, "wait": 0.0,
		"entry": "right",
	},
	{
		"scene": "res://levels/level_12.tscn",
		"id": "level_12", "next": "level_13", "shots": 4, "par": 2,
		"offset": Vector2(0.0, -140.0), "curve": 0.0, "wait": 0.8,
	},
	{
		"scene": "res://levels/level_13.tscn",
		"id": "level_13", "next": "level_14", "shots": 4, "par": 2,
		"offset": Vector2(0.0, -225.0), "curve": 0.0, "wait": 0.45,
	},
	{
		"scene": "res://levels/level_14.tscn",
		"id": "level_14", "next": "level_15", "shots": 4, "par": 2,
		"offset": Vector2(0.0, -130.0), "curve": 0.0, "wait": 0.0,
	},
	{
		"scene": "res://levels/level_15.tscn",
		"id": "level_15", "next": "level_16", "shots": 5, "par": 3,
		"offset": Vector2(-165.0, -260.0), "curve": -16.0, "wait": 0.0,
	},
	{
		"scene": "res://levels/level_16.tscn",
		"id": "level_16", "next": "level_17", "shots": 4, "par": 2,
		"offset": Vector2(-115.0, -145.0), "curve": -8.0, "wait": 0.0,
	},
	{
		"scene": "res://levels/level_17.tscn",
		"id": "level_17", "next": "level_18", "shots": 5, "par": 3,
		"offset": Vector2(0.0, -230.0), "curve": 0.0, "wait": 0.4,
	},
	{
		"scene": "res://levels/level_18.tscn",
		"id": "level_18", "next": "level_19", "shots": 5, "par": 3,
		"offset": Vector2(230.0, -205.0), "curve": 0.0, "wait": 0.0,
	},
	{
		"scene": "res://levels/level_19.tscn",
		"id": "level_19", "next": "level_20", "shots": 5, "par": 3,
		"offset": Vector2(0.0, -225.0), "curve": 0.0, "wait": 0.55,
	},
	{
		"scene": "res://levels/level_20.tscn",
		"id": "level_20", "next": "", "shots": 6, "par": 4,
		"offset": Vector2(75.0, -230.0), "curve": 20.0, "wait": 0.0,
		"entry": "right",
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var passed := true
	var count_ok := LEVEL_SPECS.size() == 20
	print("PHASE3 level_count ok=", count_ok)
	passed = count_ok and passed
	var seen_ids: Dictionary = {}
	for spec in LEVEL_SPECS:
		passed = await _verify_level(spec, seen_ids) and passed
	print("PHASE3 verify=", "PASS" if passed else "FAIL")
	quit(0 if passed else 1)


func _verify_level(spec: Dictionary, seen_ids: Dictionary) -> bool:
	var scene: PackedScene = load(spec.scene)
	if not scene:
		print("PHASE3 missing_scene scene=", spec.scene)
		return false

	var level: Node3D = scene.instantiate() as Node3D
	get_root().add_child(level)
	await _warmup()

	var passed := true
	var definition: LevelDefinition = level.get("level_definition") as LevelDefinition
	var definition_ok: bool = definition \
		and definition.is_valid_definition() \
		and definition.level_id == spec.id \
		and definition.next_level_id == spec.next \
		and definition.shot_limit == int(spec.shots) \
		and definition.par_shots == int(spec.par) \
		and not seen_ids.has(definition.level_id)
	if definition:
		seen_ids[definition.level_id] = true
	print("PHASE3 definition id=", spec.id, " ok=", definition_ok)
	passed = definition_ok and passed

	var no_tuning_override: bool = _shooting_tuning_signature(level) == BASE_TUNING
	print("PHASE3 tuning id=", spec.id, " ok=", no_tuning_override)
	passed = no_tuning_override and passed

	var ball_tuning_ok: bool = _ball_tuning_signature(level) == BASE_BALL_TUNING
	print("PHASE3 ball_tuning id=", spec.id, " ok=", ball_tuning_ok)
	passed = ball_tuning_ok and passed

	var integrity_ok: bool = _production_scene_integrity_ok(level)
	print("PHASE3 integrity id=", spec.id, " ok=", integrity_ok)
	passed = integrity_ok and passed

	var goal_sync_ok: bool = _all_goal_targets_sync(level)
	print("PHASE3 goals id=", spec.id, " ok=", goal_sync_ok)
	passed = goal_sync_ok and passed

	await level._restart_level()
	var ready_ok: bool = await _wait_for_ready(level) and _ready_ball_ok(level)
	print("PHASE3 ready id=", spec.id, " ok=", ready_ok)
	passed = ready_ok and passed

	var reset_signature := _resettable_signature(level)
	await _advance_frames(45)
	await level._restart_level()
	var retry_ok: bool = await _wait_for_ready(level) \
		and _resettable_signature(level) == reset_signature
	print("PHASE3 retry_signature id=", spec.id, " ok=", retry_ok)
	passed = retry_ok and passed

	var completed: bool = await _complete_with_swipe(
		level,
		spec.offset,
		float(spec.curve),
		float(spec.wait)
	)
	if completed and spec.has("entry"):
		var detector := level.get_node_or_null("Goal/GoalDetection")
		var actual_entry := String(detector.get("entry_boundary")) if detector else ""
		var entry_ok := actual_entry == String(spec.entry)
		print(
			"PHASE3 completion_entry id=", spec.id,
			" expected=", spec.entry,
			" actual=", actual_entry,
			" ok=", entry_ok
		)
		completed = entry_ok
	print("PHASE3 completion id=", spec.id, " ok=", completed)
	passed = completed and passed

	level.queue_free()
	await process_frame
	return passed


func _complete_with_swipe(
	level: Node,
	offset: Vector2,
	curve_px: float,
	wait_seconds: float
) -> bool:
	await level._restart_level()
	if not await _wait_for_ready(level):
		return false
	await _advance_seconds(wait_seconds)
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	var camera: Camera3D = level.get_node("Camera3D") as Camera3D
	_send_mouse_swipe(level, camera, ball, _curve_offsets(offset, curve_px, 13))
	for _i in range(360):
		await physics_frame
		var state: int = level.get("level_state")
		if state == level.LevelState.GOAL:
			return true
		if state == level.LevelState.FAILED:
			print(
				"PHASE3 completion_failed state=FAILED pos=",
				ball.global_position,
				" vel=",
				ball.linear_velocity
			)
			return false
	print(
		"PHASE3 completion_failed state=",
		level.get("level_state"),
		" pos=",
		ball.global_position,
		" vel=",
		ball.linear_velocity
	)
	return false


func _all_goal_targets_sync(level: Node) -> bool:
	var targets := level.find_children("*", "GoalTarget", true, false)
	if targets.is_empty():
		return false
	for node in targets:
		var target := node as GoalTarget
		if not target or not target.geometry_matches_detector():
			return false
	return true


func _resettable_signature(level: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for node in level.find_children("*", "", true, false):
		if not node.is_in_group("netbound_level_resettable"):
			continue
		if node.has_method("get_reset_signature"):
			parts.append("%s=%s" % [node.get_path(), node.call("get_reset_signature")])
		elif node is GoalTarget:
			var target := node as GoalTarget
			parts.append("%s=%s" % [target.get_path(), target.geometry_matches_detector()])
	parts.sort()
	return "|".join(parts)


func _shooting_tuning_signature(level: Node) -> String:
	return "%.2f|%.2f|%.2f|%.2f" % [
		float(level.get("minimum_launch_speed")),
		float(level.get("maximum_launch_speed")),
		float(level.get("maximum_elevation_degrees")),
		float(level.get("maximum_curve_heading_degrees")),
	]


func _ball_tuning_signature(level: Node) -> String:
	return "%.2f|%.2f|%.2f|%.2f|%.2f|%.2f" % [
		float(level.get("ball_radius")),
		float(level.get("ball_mass")),
		float(level.get("linear_damping")),
		float(level.get("angular_damping")),
		float(level.get("ball_bounce")),
		float(level.get("ground_bounce")),
	]


func _production_scene_integrity_ok(level: Node) -> bool:
	var controller_count := 0
	var debug_script_found := false
	for node in _all_nodes_with_root(level):
		var script := node.get_script() as Script
		if not script:
			continue
		var path := script.resource_path
		if path == LEVEL_CONTROLLER_SCRIPT:
			controller_count += 1
		if path.begins_with(DEBUG_SCRIPT_PREFIX):
			debug_script_found = true
	return controller_count == 1 and not debug_script_found


func _all_nodes_with_root(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	return nodes


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


func _wait_for_ready(level: Node, max_frames: int = 160) -> bool:
	for _i in range(max_frames):
		if int(level.get("level_state")) == level.LevelState.READY \
			and not bool(level.get("reset_in_progress")):
			return true
		await physics_frame
	return false


func _ready_ball_ok(level: Node) -> bool:
	var ball: RigidBody3D = level.get_node("Ball") as RigidBody3D
	return (
		int(level.get("level_state")) == level.LevelState.READY
		and not ball.freeze
		and ball.linear_velocity.length() <= float(level.get("stopped_velocity_threshold"))
		and ball.angular_velocity.length() <= float(level.get("stopped_velocity_threshold"))
	)


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


func _line_offsets(offset: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(offset * (float(i + 1) / float(count)))
	return points


func _warmup() -> void:
	await process_frame
	await process_frame
	await physics_frame


func _advance_seconds(seconds: float) -> void:
	var frames := ceili(seconds * 60.0)
	await _advance_frames(frames)


func _advance_frames(count: int) -> void:
	for _i in range(count):
		await physics_frame
