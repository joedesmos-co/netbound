class_name TimedGate
extends Node3D

const RESET_GROUP := "netbound_level_resettable"

@export var target_path: NodePath = NodePath(".")
@export var closed_position: Vector3 = Vector3.ZERO
@export var open_position: Vector3 = Vector3(0.0, 4.0, 0.0)
@export var closed_duration: float = 1.0
@export var open_duration: float = 1.0
@export_range(0.05, 1.0, 0.01) var transition_duration: float = 0.42
@export var starts_open: bool = false
@export var start_phase_seconds: float = 0.0
@export var active: bool = true

var elapsed: float = 0.0
var is_open: bool = false
var target: Node3D


func _enter_tree() -> void:
	add_to_group(RESET_GROUP)


func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	if not target:
		target = self
	reset_level_element(0)


func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	_apply_gate_state()


func reset_level_element(_generation: int) -> void:
	elapsed = start_phase_seconds
	_apply_gate_state()


func get_reset_signature() -> String:
	return "%s|%s|%.4f" % [target.position if target else position, is_open, elapsed]


func _apply_gate_state() -> void:
	var openness := _openness_at_time(elapsed)
	is_open = openness >= 0.999
	if target:
		target.position = closed_position.lerp(open_position, openness)


func _is_open_at_time(time_seconds: float) -> bool:
	return _openness_at_time(time_seconds) >= 0.999


func _openness_at_time(time_seconds: float) -> float:
	var open_hold := maxf(open_duration, 0.0)
	var closed_hold := maxf(closed_duration, 0.0)
	var travel := maxf(transition_duration, 0.001)
	var cycle_length := maxf(open_hold + closed_hold + travel * 2.0, 0.001)
	var cycle_time := fposmod(time_seconds, cycle_length)

	if starts_open:
		if cycle_time < open_hold:
			return 1.0
		cycle_time -= open_hold
		if cycle_time < travel:
			return 1.0 - _smooth_motion(cycle_time / travel)
		cycle_time -= travel
		if cycle_time < closed_hold:
			return 0.0
		cycle_time -= closed_hold
		return _smooth_motion(cycle_time / travel)

	if cycle_time < closed_hold:
		return 0.0
	cycle_time -= closed_hold
	if cycle_time < travel:
		return _smooth_motion(cycle_time / travel)
	cycle_time -= travel
	if cycle_time < open_hold:
		return 1.0
	cycle_time -= open_hold
	return 1.0 - _smooth_motion(cycle_time / travel)


func _smooth_motion(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
