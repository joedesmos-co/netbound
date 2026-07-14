class_name LevelResult
extends Resource

@export var level_id: String = ""
@export var completed: bool = false
@export var shots_used: int = 0
@export var shot_limit: int = 0
@export var par_shots: int = 0


static func completed_result(
	level_definition: LevelDefinition,
	used_shots: int
) -> LevelResult:
	var result := LevelResult.new()
	result.level_id = level_definition.level_id if level_definition else ""
	result.completed = true
	result.shots_used = used_shots
	result.shot_limit = level_definition.shot_limit if level_definition else 0
	result.par_shots = level_definition.par_shots if level_definition else 0
	return result


static func failed_result(
	level_definition: LevelDefinition,
	used_shots: int
) -> LevelResult:
	var result := LevelResult.new()
	result.level_id = level_definition.level_id if level_definition else ""
	result.completed = false
	result.shots_used = used_shots
	result.shot_limit = level_definition.shot_limit if level_definition else 0
	result.par_shots = level_definition.par_shots if level_definition else 0
	return result
