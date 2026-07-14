class_name BounceSurface
extends StaticBody3D

const RESET_GROUP := "netbound_level_resettable"

@export var arcade_bounce: float = 0.75
@export var arcade_friction: float = 0.08


func _enter_tree() -> void:
	add_to_group(RESET_GROUP)


func _ready() -> void:
	_apply_surface_material()


func reset_level_element(_generation: int) -> void:
	_apply_surface_material()


func _apply_surface_material() -> void:
	var material := PhysicsMaterial.new()
	material.bounce = arcade_bounce
	material.friction = arcade_friction
	physics_material_override = material
