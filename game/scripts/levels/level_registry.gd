class_name LevelRegistry
extends RefCounted

const EXPECTED_LEVEL_COUNT := 20

const PRODUCTION_LEVELS := [
	{
		"id": "level_01",
		"scene": "res://levels/level_01.tscn",
		"definition": "res://levels/definitions/level_01_definition.tres",
	},
	{
		"id": "level_02",
		"scene": "res://levels/level_02.tscn",
		"definition": "res://levels/definitions/level_02_definition.tres",
	},
	{
		"id": "level_03",
		"scene": "res://levels/level_03.tscn",
		"definition": "res://levels/definitions/level_03_definition.tres",
	},
	{
		"id": "level_04",
		"scene": "res://levels/level_04.tscn",
		"definition": "res://levels/definitions/level_04_definition.tres",
	},
	{
		"id": "level_05",
		"scene": "res://levels/level_05.tscn",
		"definition": "res://levels/definitions/level_05_definition.tres",
	},
	{
		"id": "level_06",
		"scene": "res://levels/level_06.tscn",
		"definition": "res://levels/definitions/level_06_definition.tres",
	},
	{
		"id": "level_07",
		"scene": "res://levels/level_07.tscn",
		"definition": "res://levels/definitions/level_07_definition.tres",
	},
	{
		"id": "level_08",
		"scene": "res://levels/level_08.tscn",
		"definition": "res://levels/definitions/level_08_definition.tres",
	},
	{
		"id": "level_09",
		"scene": "res://levels/level_09.tscn",
		"definition": "res://levels/definitions/level_09_definition.tres",
	},
	{
		"id": "level_10",
		"scene": "res://levels/level_10.tscn",
		"definition": "res://levels/definitions/level_10_definition.tres",
	},
	{
		"id": "level_11",
		"scene": "res://levels/level_11.tscn",
		"definition": "res://levels/definitions/level_11_definition.tres",
	},
	{
		"id": "level_12",
		"scene": "res://levels/level_12.tscn",
		"definition": "res://levels/definitions/level_12_definition.tres",
	},
	{
		"id": "level_13",
		"scene": "res://levels/level_13.tscn",
		"definition": "res://levels/definitions/level_13_definition.tres",
	},
	{
		"id": "level_14",
		"scene": "res://levels/level_14.tscn",
		"definition": "res://levels/definitions/level_14_definition.tres",
	},
	{
		"id": "level_15",
		"scene": "res://levels/level_15.tscn",
		"definition": "res://levels/definitions/level_15_definition.tres",
	},
	{
		"id": "level_16",
		"scene": "res://levels/level_16.tscn",
		"definition": "res://levels/definitions/level_16_definition.tres",
	},
	{
		"id": "level_17",
		"scene": "res://levels/level_17.tscn",
		"definition": "res://levels/definitions/level_17_definition.tres",
	},
	{
		"id": "level_18",
		"scene": "res://levels/level_18.tscn",
		"definition": "res://levels/definitions/level_18_definition.tres",
	},
	{
		"id": "level_19",
		"scene": "res://levels/level_19.tscn",
		"definition": "res://levels/definitions/level_19_definition.tres",
	},
	{
		"id": "level_20",
		"scene": "res://levels/level_20.tscn",
		"definition": "res://levels/definitions/level_20_definition.tres",
	},
]


static func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in PRODUCTION_LEVELS:
		entries.append((entry as Dictionary).duplicate(true))
	return entries


static func get_level_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in PRODUCTION_LEVELS:
		ids.append(String(entry.id))
	return ids


static func get_first_level_id() -> String:
	return String(PRODUCTION_LEVELS[0].id)


static func has_level_id(level_id: String) -> bool:
	return get_entry(level_id).size() > 0


static func get_entry(level_id: String) -> Dictionary:
	for entry in PRODUCTION_LEVELS:
		if String(entry.id) == level_id:
			return (entry as Dictionary).duplicate(true)
	return {}


static func get_scene_path(level_id: String) -> String:
	var entry := get_entry(level_id)
	return String(entry.get("scene", ""))


static func get_definition_path(level_id: String) -> String:
	var entry := get_entry(level_id)
	return String(entry.get("definition", ""))


static func load_definition(level_id: String) -> LevelDefinition:
	var path := get_definition_path(level_id)
	return load(path) as LevelDefinition if not path.is_empty() else null


static func get_next_level_id(level_id: String) -> String:
	var definition := load_definition(level_id)
	return definition.next_level_id if definition else ""


static func get_order_index(level_id: String) -> int:
	for i in PRODUCTION_LEVELS.size():
		if String(PRODUCTION_LEVELS[i].id) == level_id:
			return i
	return -1


static func validate_registry() -> Dictionary:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	if PRODUCTION_LEVELS.size() != EXPECTED_LEVEL_COUNT:
		errors.append(
			"expected %d levels, found %d" % [EXPECTED_LEVEL_COUNT, PRODUCTION_LEVELS.size()]
		)

	for i in PRODUCTION_LEVELS.size():
		var entry: Dictionary = PRODUCTION_LEVELS[i]
		var level_id := String(entry.get("id", ""))
		var scene_path := String(entry.get("scene", ""))
		var definition_path := String(entry.get("definition", ""))
		if level_id.is_empty():
			errors.append("level at index %d has an empty id" % i)
			continue
		if seen.has(level_id):
			errors.append("duplicate level id %s" % level_id)
		seen[level_id] = true

		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			errors.append("missing scene for %s at %s" % [level_id, scene_path])
		if definition_path.is_empty() or not ResourceLoader.exists(definition_path):
			errors.append("missing definition for %s at %s" % [level_id, definition_path])
			continue

		var definition := load(definition_path) as LevelDefinition
		if not definition:
			errors.append("definition failed to load for %s" % level_id)
			continue
		if not definition.is_valid_definition():
			errors.append("definition is invalid for %s" % level_id)
		if definition.level_id != level_id:
			errors.append(
				"definition id mismatch for %s: %s" % [level_id, definition.level_id]
			)

		var expected_next := ""
		if i < PRODUCTION_LEVELS.size() - 1:
			expected_next = String(PRODUCTION_LEVELS[i + 1].id)
		if definition.next_level_id != expected_next:
			errors.append(
				"next id mismatch for %s: expected %s got %s" % [
					level_id,
					expected_next,
					definition.next_level_id,
				]
			)
		if not definition.next_level_id.is_empty() and not has_level_id(definition.next_level_id):
			errors.append(
				"next id for %s does not resolve: %s" % [level_id, definition.next_level_id]
			)

	return {"ok": errors.is_empty(), "errors": errors}
