class_name LevelDefinition
extends Resource

@export var level_id: String = ""
@export var display_name: String = ""
@export var shot_limit: int = 3
@export var par_shots: int = 1
@export_multiline var tutorial_text: String = ""
@export var bounds_min: Vector3 = Vector3(-24.0, -2.0, -18.0)
@export var bounds_max: Vector3 = Vector3(24.0, 32.0, 12.0)
@export var camera_position: Vector3 = Vector3(0.0, 11.5, 14.0)
@export var camera_look_at: Vector3 = Vector3(0.0, 3.6, -8.5)
@export var mechanic_id: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var next_level_id: String = ""


func is_valid_definition() -> bool:
	return (
		not level_id.is_empty()
		and shot_limit > 0
		and par_shots > 0
		and bounds_min.x < bounds_max.x
		and bounds_min.y < bounds_max.y
		and bounds_min.z < bounds_max.z
	)
