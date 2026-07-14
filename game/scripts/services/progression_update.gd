class_name ProgressionUpdate
extends RefCounted

var level_id: String = ""
var completed: bool = false
var first_completion: bool = false
var stars_earned: int = 0
var previous_best_stars: int = 0
var new_best_stars: int = 0
var previous_fewest_shots: int = -1
var new_fewest_shots: int = -1
var unlocked_level_id: String = ""
var did_unlock_new_level: bool = false
var unlocked_cosmetic_ids: Array[String] = []
var total_stars_before: int = 0
var total_stars_after: int = 0
var save_succeeded: bool = false
var changed: bool = false
var reward_transaction_id: String = ""
var completion_coins: int = 0
var first_completion_coins: int = 0
var new_star_coins: int = 0
var personal_best_coins: int = 0
var coins_earned: int = 0
var coin_balance_before: int = 0
var coin_balance_after: int = 0


func to_dictionary() -> Dictionary:
	return {
		"level_id": level_id,
		"completed": completed,
		"first_completion": first_completion,
		"stars_earned": stars_earned,
		"previous_best_stars": previous_best_stars,
		"new_best_stars": new_best_stars,
		"previous_fewest_shots": previous_fewest_shots,
		"new_fewest_shots": new_fewest_shots,
		"unlocked_level_id": unlocked_level_id,
		"did_unlock_new_level": did_unlock_new_level,
		"unlocked_cosmetic_ids": unlocked_cosmetic_ids.duplicate(),
		"total_stars_before": total_stars_before,
		"total_stars_after": total_stars_after,
		"save_succeeded": save_succeeded,
		"changed": changed,
		"reward_transaction_id": reward_transaction_id,
		"completion_coins": completion_coins,
		"first_completion_coins": first_completion_coins,
		"new_star_coins": new_star_coins,
		"personal_best_coins": personal_best_coins,
		"coins_earned": coins_earned,
		"coin_balance_before": coin_balance_before,
		"coin_balance_after": coin_balance_after,
	}
