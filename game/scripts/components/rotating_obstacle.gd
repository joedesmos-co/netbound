class_name RotatingObstacle
extends Node3D

const RESET_GROUP := "netbound_level_resettable"

@export var axis: Vector3 = Vector3.UP
@export var degrees_per_second: float = 90.0
@export var start_angle_degrees: float = 0.0
@export var active: bool = true

var elapsed: float = 0.0
var initial_basis: Basis = Basis.IDENTITY


func _enter_tree() -> void:
	add_to_group(RESET_GROUP)


func _ready() -> void:
	initial_basis = transform.basis
	reset_level_element(0)


func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	_apply_rotation()


func reset_level_element(_generation: int) -> void:
	elapsed = 0.0
	_apply_rotation()


func get_reset_signature() -> String:
	return "%s|%.4f" % [transform.basis.get_rotation_quaternion(), elapsed]


func _apply_rotation() -> void:
	var normalized_axis := axis.normalized() if axis.length() > 0.001 else Vector3.UP
	var angle := deg_to_rad(start_angle_degrees + degrees_per_second * elapsed)
	transform.basis = initial_basis * Basis(normalized_axis, angle)
