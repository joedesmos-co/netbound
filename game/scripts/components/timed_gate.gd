class_name TimedGate
extends Node3D

const RESET_GROUP := "netbound_level_resettable"

@export var target_path: NodePath = NodePath(".")
@export var closed_position: Vector3 = Vector3.ZERO
@export var open_position: Vector3 = Vector3(0.0, 4.0, 0.0)
@export var closed_duration: float = 1.0
@export var open_duration: float = 1.0
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
	is_open = _is_open_at_time(elapsed)
	if target:
		target.position = open_position if is_open else closed_position


func _is_open_at_time(time_seconds: float) -> bool:
	var cycle_length := maxf(open_duration + closed_duration, 0.001)
	var cycle_time := fposmod(time_seconds, cycle_length)
	if starts_open:
		return cycle_time < open_duration
	return cycle_time >= closed_duration
