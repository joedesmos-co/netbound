class_name WorldCatalog
extends RefCounted

const WORLD_TRAINING := "training_yard"
const WORLD_STREET := "street_arcade"
const WORLD_STADIUM := "stadium_showdown"

const WORLDS := [
	{
		"id": WORLD_TRAINING,
		"display_name": "Training Yard",
		"short_label": "WORLD 1",
		"tagline": "Learn the shot language.",
		"level_start": 1,
		"level_end": 10,
		"accent": Color("2bb7ff"),
		"paper": Color("e8fff4"),
	},
	{
		"id": WORLD_STREET,
		"display_name": "Street Arcade",
		"short_label": "WORLD 2",
		"tagline": "Curve, gates, and side nets.",
		"level_start": 11,
		"level_end": 20,
		"accent": Color("ff7a3d"),
		"paper": Color("fff1e4"),
	},
	{
		"id": WORLD_STADIUM,
		"display_name": "Stadium Showdown",
		"short_label": "WORLD 3",
		"tagline": "Championship pressure.",
		"level_start": 21,
		"level_end": 30,
		"accent": Color("f2c14e"),
		"paper": Color("e8f0ff"),
	},
]


static func get_worlds() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	for world in WORLDS:
		worlds.append((world as Dictionary).duplicate(true))
	return worlds


static func get_world_for_level_index(level_index: int) -> Dictionary:
	var clamped := clampi(level_index, 1, 30)
	for world in WORLDS:
		if clamped >= int(world.level_start) and clamped <= int(world.level_end):
			return (world as Dictionary).duplicate(true)
	return (WORLDS[0] as Dictionary).duplicate(true)


static func get_world_for_level_id(level_id: String) -> Dictionary:
	return get_world_for_level_index(_level_number(level_id))


static func get_world_id_for_level_id(level_id: String) -> String:
	return String(get_world_for_level_id(level_id).get("id", WORLD_TRAINING))


static func get_level_ids_for_world(world_id: String) -> Array[String]:
	var ids: Array[String] = []
	for world in WORLDS:
		if String(world.id) != world_id:
			continue
		for index in range(int(world.level_start), int(world.level_end) + 1):
			ids.append("level_%02d" % index)
		break
	return ids


static func _level_number(level_id: String) -> int:
	var parts := level_id.split("_")
	if parts.size() >= 2:
		return clampi(int(parts[-1]), 1, 30)
	return 1
