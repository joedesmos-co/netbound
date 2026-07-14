class_name GoalDetector
extends Node3D

signal goal_scored

@export var goal_line_z: float = -10.0
@export var post_half_width: float = 11.0
@export var crossbar_height: float = 8.4
@export var interior_depth: float = 5.0
@export var ball_radius: float = 0.49
@export var debug_goal_detection: bool = false
@export var show_debug_volumes: bool = false

var crossed_goal_line: bool = false
var entered_goal_interior: bool = false
var goal_emitted: bool = false
var crossing_point: Vector3 = Vector3.ZERO

var _previous_ball_position: Vector3 = Vector3.ZERO
var _tracking_active: bool = false
var _tracked_shot_id: int = -1
var _ball: RigidBody3D
var _active_level_state_name: String = ""

@onready var mouth_trigger: Area3D = $GoalMouthTrigger
@onready var interior_trigger: Area3D = $GoalInteriorTrigger
@onready var debug_mouth_visual: MeshInstance3D = $DebugMouthVisual
@onready var debug_interior_visual: MeshInstance3D = $DebugInteriorVisual


func _ready() -> void:
	_update_debug_volumes()


func setup(ball: RigidBody3D) -> void:
	_ball = ball


func sync_geometry(
	line_z: float,
	half_width: float,
	bar_height: float,
	depth: float,
	radius: float
) -> void:
	goal_line_z = line_z
	post_half_width = half_width
	crossbar_height = bar_height
	interior_depth = depth
	ball_radius = radius
	_debug_print(
		"sync line_z=%s half_width=%s bar=%s depth=%s radius=%s" % [
			goal_line_z,
			post_half_width,
			crossbar_height,
			interior_depth,
			ball_radius,
		]
	)


func set_level_state_name(state_name: String) -> void:
	_active_level_state_name = state_name


func reset_shot_tracking() -> void:
	crossed_goal_line = false
	entered_goal_interior = false
	goal_emitted = false
	crossing_point = Vector3.ZERO
	_previous_ball_position = Vector3.ZERO
	_tracking_active = false
	_tracked_shot_id = -1


func begin_shot_tracking(shot_id: int, ball_position: Vector3) -> void:
	reset_shot_tracking()
	_tracking_active = true
	_tracked_shot_id = shot_id
	_previous_ball_position = ball_position
	_debug_print("track_begin shot_id=%d prev=%s" % [shot_id, ball_position])


func process_ball(ball_position: Vector3, radius: float, shot_id: int) -> bool:
	if goal_emitted:
		return false
	if not _tracking_active:
		return false
	if shot_id != _tracked_shot_id:
		_debug_print("stale_shot expected=%d got=%d" % [_tracked_shot_id, shot_id])
		return false

	var previous := _previous_ball_position
	if not crossed_goal_line:
		var sweep := _detect_swept_crossing(previous, ball_position, radius)
		if sweep.valid:
			var opening := _evaluate_opening_at_point(sweep.point, radius)
			_log_crossing_detail(
				previous,
				ball_position,
				sweep.point,
				radius,
				opening.reason if not opening.valid else "ok",
				shot_id
			)
			if opening.valid:
				crossed_goal_line = true
				crossing_point = sweep.point
				# Score immediately on valid mouth crossing.
				# Do not re-check width/height as the ball enters the side net.
				entered_goal_interior = _is_in_interior(ball_position, radius)
				_previous_ball_position = ball_position
				return _emit_goal()
		elif sweep.reason != "not_fully_crossed":
			_debug_print(sweep.reason)

	_previous_ball_position = ball_position
	return false


func is_ball_fully_in_goal(ball_position: Vector3, radius: float) -> bool:
	if ball_position.z + radius > goal_line_z:
		return false
	if absf(ball_position.x) + radius > post_half_width:
		return false
	if ball_position.y + radius > crossbar_height:
		return false
	return true


func check_ball(ball_position: Vector3, radius: float) -> bool:
	if goal_emitted:
		return false
	if not is_ball_fully_in_goal(ball_position, radius):
		return false
	return _emit_goal()


func _emit_goal() -> bool:
	if goal_emitted:
		_debug_print("already_scored")
		return false
	goal_emitted = true
	_debug_print(
		"scored crossing=%s interior=%s shot_id=%d state=%s" % [
			crossing_point,
			entered_goal_interior,
			_tracked_shot_id,
			_active_level_state_name,
		]
	)
	goal_scored.emit()
	return true


func _detect_swept_crossing(previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	var prev_rear_z := previous.z + radius
	var curr_rear_z := current.z + radius

	if prev_rear_z <= goal_line_z and curr_rear_z > goal_line_z:
		return {"valid": false, "reason": "wrong_direction"}

	if prev_rear_z <= goal_line_z and curr_rear_z <= goal_line_z:
		return {"valid": false, "reason": "not_fully_crossed"}

	if prev_rear_z > goal_line_z and curr_rear_z <= goal_line_z:
		var delta_z := current.z - previous.z
		if absf(delta_z) <= 0.0001:
			return {"valid": false, "reason": "not_fully_crossed"}
		var target_center_z := goal_line_z - radius
		var t := clampf((target_center_z - previous.z) / delta_z, 0.0, 1.0)
		return {"valid": true, "point": previous.lerp(current, t), "reason": "ok"}

	return {"valid": false, "reason": "not_fully_crossed"}


func _evaluate_opening_at_point(center: Vector3, radius: float) -> Dictionary:
	# Whole-ball inside posts/crossbar at the crossing moment only.
	if absf(center.x) + radius > post_half_width:
		return {"valid": false, "reason": "outside_left_right_opening_at_crossing"}
	if center.y + radius > crossbar_height:
		return {"valid": false, "reason": "above_crossbar_at_crossing"}
	# Soft ground clamp: penetration from resting contact should not reject goals.
	if center.y + radius * 0.25 < 0.0:
		return {"valid": false, "reason": "below_ground_at_crossing"}
	return {"valid": true, "reason": "ok"}


func _is_in_interior(ball_position: Vector3, radius: float) -> bool:
	var rear_z := goal_line_z - interior_depth
	return ball_position.z + radius <= goal_line_z and ball_position.z >= rear_z - radius


func _log_crossing_detail(
	previous: Vector3,
	current: Vector3,
	point: Vector3,
	radius: float,
	reason: String,
	shot_id: int
) -> void:
	_debug_print(
		"crossing prev=%s curr=%s point=%s radius=%s half_width=%s crossbar=%s reason=%s shot_id=%d state=%s" % [
			previous,
			current,
			point,
			radius,
			post_half_width,
			crossbar_height,
			reason,
			shot_id,
			_active_level_state_name,
		]
	)


func _debug_print(message: String) -> void:
	if debug_goal_detection:
		print("GOAL ", message)


func _update_debug_volumes() -> void:
	if debug_mouth_visual:
		debug_mouth_visual.visible = show_debug_volumes
	if debug_interior_visual:
		debug_interior_visual.visible = show_debug_volumes
