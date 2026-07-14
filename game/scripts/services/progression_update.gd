class_name ProgressionUpdate
extends RefCounted

var level_id: String = ""
var completed: bool = false
var stars_earned: int = 0
var previous_best_stars: int = 0
var new_best_stars: int = 0
var previous_fewest_shots: int = -1
var new_fewest_shots: int = -1
var unlocked_level_id: String = ""
var did_unlock_new_level: bool = false
var total_stars_before: int = 0
var total_stars_after: int = 0
var save_succeeded: bool = false
var changed: bool = false


func to_dictionary() -> Dictionary:
	return {
		"level_id": level_id,
		"completed": completed,
		"stars_earned": stars_earned,
		"previous_best_stars": previous_best_stars,
		"new_best_stars": new_best_stars,
		"previous_fewest_shots": previous_fewest_shots,
		"new_fewest_shots": new_fewest_shots,
		"unlocked_level_id": unlocked_level_id,
		"did_unlock_new_level": did_unlock_new_level,
		"total_stars_before": total_stars_before,
		"total_stars_after": total_stars_after,
		"save_succeeded": save_succeeded,
		"changed": changed,
	}
