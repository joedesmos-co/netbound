class_name GoalDetector
extends Node3D

signal goal_scored

const ENTRY_NONE: StringName = &"none"
const ENTRY_FRONT: StringName = &"front"
const ENTRY_LEFT: StringName = &"left"
const ENTRY_RIGHT: StringName = &"right"
const ENTRY_REAR: StringName = &"rear"

@export var goal_line_z: float = -10.0
@export var goal_center_x: float = 0.0
@export var post_half_width: float = 11.0
@export var crossbar_height: float = 8.4
@export var interior_depth: float = 5.0
@export var ball_radius: float = 0.49
@export var debug_goal_detection: bool = false
@export var show_debug_volumes: bool = false

var crossed_entry_boundary: bool = false
var entered_goal_interior: bool = false
var goal_emitted: bool = false
var crossing_point: Vector3 = Vector3.ZERO
var entry_boundary: StringName = ENTRY_NONE

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
	center_x: float,
	half_width: float,
	bar_height: float,
	depth: float,
	radius: float
) -> void:
	goal_line_z = line_z
	goal_center_x = center_x
	post_half_width = half_width
	crossbar_height = bar_height
	interior_depth = depth
	ball_radius = radius
	_debug_print(
		"sync line_z=%s center_x=%s half_width=%s bar=%s depth=%s radius=%s" % [
			goal_line_z,
			goal_center_x,
			post_half_width,
			crossbar_height,
			interior_depth,
			ball_radius,
		]
	)


func set_level_state_name(state_name: String) -> void:
	_active_level_state_name = state_name


func reset_shot_tracking() -> void:
	crossed_entry_boundary = false
	entered_goal_interior = false
	goal_emitted = false
	crossing_point = Vector3.ZERO
	entry_boundary = ENTRY_NONE
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
	if not crossed_entry_boundary:
		var sweep := _detect_swept_entry(previous, ball_position, radius)
		if sweep.valid:
			_log_crossing_detail(
				previous,
				ball_position,
				sweep.point,
				radius,
				String(sweep.boundary),
				shot_id
			)
			crossed_entry_boundary = true
			crossing_point = sweep.point
			entry_boundary = sweep.boundary
			entered_goal_interior = entry_boundary != ENTRY_REAR
			_previous_ball_position = ball_position
			if entry_boundary == ENTRY_REAR:
				_debug_print("rear_entry_rejected shot_id=%d" % shot_id)
				return false
			return _emit_goal()
		elif sweep.reason != "no_entry_boundary_crossed":
			_debug_print(sweep.reason)

	_previous_ball_position = ball_position
	return false


func is_ball_fully_in_goal(ball_position: Vector3, radius: float) -> bool:
	if ball_position.z + radius > goal_line_z:
		return false
	if absf(ball_position.x - goal_center_x) + radius > post_half_width:
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


func _detect_swept_entry(previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var front_center_z := goal_line_z - radius
	var rear_center_z := goal_line_z - interior_depth + radius
	var left_center_x := goal_center_x - post_half_width + radius
	var right_center_x := goal_center_x + post_half_width - radius

	_add_axis_crossing_candidate(
		candidates, previous, current, 2, front_center_z, false, ENTRY_FRONT, radius
	)
	_add_axis_crossing_candidate(
		candidates, previous, current, 0, left_center_x, true, ENTRY_LEFT, radius
	)
	_add_axis_crossing_candidate(
		candidates, previous, current, 0, right_center_x, false, ENTRY_RIGHT, radius
	)
	_add_axis_crossing_candidate(
		candidates, previous, current, 2, rear_center_z, true, ENTRY_REAR, radius
	)

	if candidates.is_empty():
		return {"valid": false, "reason": "no_entry_boundary_crossed"}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	return candidates[0]


func _add_axis_crossing_candidate(
	candidates: Array[Dictionary],
	previous: Vector3,
	current: Vector3,
	axis: int,
	boundary: float,
	increasing: bool,
	boundary_name: StringName,
	radius: float
) -> void:
	var previous_value := previous[axis]
	var current_value := current[axis]
	var crossed := (
		(previous_value < boundary and current_value >= boundary)
		if increasing
		else (previous_value > boundary and current_value <= boundary)
	)
	if not crossed:
		return
	var delta := current_value - previous_value
	if absf(delta) <= 0.0001:
		return
	var t := clampf((boundary - previous_value) / delta, 0.0, 1.0)
	var point := previous.lerp(current, t)
	if not _entry_point_fits_boundary(point, boundary_name, radius):
		return
	candidates.append({
		"valid": true,
		"point": point,
		"boundary": boundary_name,
		"t": t,
		"reason": "ok",
	})


func _entry_point_fits_boundary(point: Vector3, boundary: StringName, radius: float) -> bool:
	if not _evaluate_height_at_point(point, radius):
		return false
	if boundary == ENTRY_FRONT or boundary == ENTRY_REAR:
		return absf(point.x - goal_center_x) + radius <= post_half_width
	var front_center_z := goal_line_z - radius
	var rear_center_z := goal_line_z - interior_depth + radius
	return point.z <= front_center_z and point.z >= rear_center_z


func _evaluate_opening_at_point(center: Vector3, radius: float) -> Dictionary:
	# Whole-ball inside posts/crossbar at the crossing moment only.
	if absf(center.x - goal_center_x) + radius > post_half_width:
		return {"valid": false, "reason": "outside_left_right_opening_at_crossing"}
	if not _evaluate_height_at_point(center, radius):
		return {"valid": false, "reason": "outside_vertical_opening_at_crossing"}
	return {"valid": true, "reason": "ok"}


func _evaluate_height_at_point(center: Vector3, radius: float) -> bool:
	if center.y + radius > crossbar_height:
		return false
	# Resting-contact penetration should not reject a ground-hugging arcade goal.
	return center.y + radius * 0.25 >= 0.0


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
		"entry prev=%s curr=%s point=%s radius=%s half_width=%s crossbar=%s boundary=%s shot_id=%d state=%s" % [
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
