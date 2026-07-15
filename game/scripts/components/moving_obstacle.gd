class_name MovingObstacle
extends Node3D

const RESET_GROUP := "netbound_level_resettable"

@export var point_a: Vector3 = Vector3.ZERO
@export var point_b: Vector3 = Vector3.ZERO
@export var target_path: NodePath = NodePath(".")
@export var duration: float = 2.0
@export var ping_pong: bool = true
@export var loop: bool = true
@export_range(0.0, 1.0, 0.001) var start_phase: float = 0.0
@export var active: bool = true

var phase: float = 0.0
var target: Node3D


func _enter_tree() -> void:
	add_to_group(RESET_GROUP)


func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	if not target:
		target = self
	if point_a == Vector3.ZERO and point_b == Vector3.ZERO:
		point_a = target.position
		point_b = target.position
	reset_level_element(0)


func _physics_process(delta: float) -> void:
	if not active or duration <= 0.0:
		return
	phase += delta / duration
	_apply_phase()


func reset_level_element(_generation: int) -> void:
	phase = start_phase
	_apply_phase()


func get_reset_signature() -> String:
	return "%s|%.4f" % [target.position if target else position, phase]


func _apply_phase() -> void:
	var t := _normalized_motion_phase(phase)
	if target:
		target.position = point_a.lerp(point_b, t)


func _normalized_motion_phase(value: float) -> float:
	if not loop:
		return clampf(value, 0.0, 1.0)
	if ping_pong:
		var cycle := fposmod(value, 2.0)
		return cycle if cycle <= 1.0 else 2.0 - cycle
	return fposmod(value, 1.0)
