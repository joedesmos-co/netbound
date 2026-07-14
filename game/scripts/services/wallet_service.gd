class_name NetboundWalletService
extends Node

signal balance_changed(currency: String, balance: int, delta: int, reason: String)
signal cosmetic_purchased(cosmetic_id: String, currency: String, price: int)

const CosmeticRegistryScript := preload("res://scripts/cosmetics/cosmetic_registry.gd")

const CURRENCY_COINS := "arcade_coins"
const CURRENCY_TOKENS := "net_tokens"
const COINS_PER_COMPLETION := 100
const FIRST_COMPLETION_BONUS := 150
const COINS_PER_NEW_STAR := 75
const PERSONAL_BEST_BONUS := 50
const REWARDED_TOKEN_AMOUNT := 2
const MAX_REWARDED_TOKEN_ADS_PER_DAY := 5
const MAX_FREE_TOKENS_PER_DAY := 10
const STARTER_PACK_COINS := 2500
const STARTER_PACK_TOKENS := 300
const STARTER_PACK_BONUS_TRANSACTION_ID := "starter_pack_bonus_v1"
const MAX_BALANCE := 2000000000
const MAX_PROCESSED_TRANSACTIONS := 2048
const MAX_TRANSACTION_HISTORY := 64

var _save_service_override: Node


func _ready() -> void:
	call_deferred("_reconcile_owned_products")


func configure_save_service(service: Node) -> void:
	_save_service_override = service
	if service and service.has_method("configure_wallet_service"):
		service.call("configure_wallet_service", self)


func get_coin_balance() -> int:
	return int(_economy_state().get(CURRENCY_COINS, 0))


func get_token_balance() -> int:
	return int(_economy_state().get(CURRENCY_TOKENS, 0))


func grant_coins(amount: int, reason: String, transaction_id: String) -> bool:
	return _grant_currency(CURRENCY_COINS, amount, reason, transaction_id, true)


func grant_tokens(amount: int, reason: String, transaction_id: String) -> bool:
	return _grant_currency(CURRENCY_TOKENS, amount, reason, transaction_id, true)


func spend_coins(amount: int, reason: String) -> bool:
	return _spend_currency(CURRENCY_COINS, amount, reason, true)


func spend_tokens(amount: int, reason: String) -> bool:
	return _spend_currency(CURRENCY_TOKENS, amount, reason, true)


func can_afford_coins(amount: int) -> bool:
	return amount >= 0 and get_coin_balance() >= amount


func can_afford_tokens(amount: int) -> bool:
	return amount >= 0 and get_token_balance() >= amount


func has_processed_transaction(transaction_id: String) -> bool:
	if transaction_id.is_empty():
		return false
	return (_economy_state().get("processed_transaction_ids", []) as Array).has(transaction_id)


func get_transaction_history() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _economy_state().get("transaction_history", []) as Array:
		result.append((entry as Dictionary).duplicate(true))
	return result


func reserve_transaction_id(prefix: String) -> String:
	var state := _economy_state()
	var sequence := maxi(int(state.get("next_transaction_sequence", 1)), 1)
	state.next_transaction_sequence = sequence + 1
	if not _persist_state(state):
		return ""
	return "%s:%d" % [prefix, sequence]


func process_level_completion_rewards(update: RefCounted) -> void:
	if not update or not bool(update.get("completed")):
		return
	var state := _economy_state()
	var balance_before := int(state.get(CURRENCY_COINS, 0))
	var sequence := maxi(int(state.get("next_transaction_sequence", 1)), 1)
	state.next_transaction_sequence = sequence + 1
	var level_id := String(update.get("level_id"))
	var run_transaction_id := String(update.get("reward_transaction_id"))
	if run_transaction_id.is_empty():
		run_transaction_id = "level_reward:%s:%d" % [level_id, sequence]
		update.set("reward_transaction_id", run_transaction_id)

	var completion_coins := _apply_grant(
		state,
		CURRENCY_COINS,
		COINS_PER_COMPLETION,
		"level_completion",
		"%s:completion" % run_transaction_id
	)
	var first_completion_coins := 0
	var first_rewards := state.get("first_completion_rewards", []) as Array
	if bool(update.get("first_completion")) and not first_rewards.has(level_id):
		first_completion_coins = _apply_grant(
			state,
			CURRENCY_COINS,
			FIRST_COMPLETION_BONUS,
			"first_completion",
			"first_completion:%s" % level_id
		)
		first_rewards.append(level_id)
		state.first_completion_rewards = first_rewards

	var star_rewards := state.get("rewarded_star_milestones", {}) as Dictionary
	var rewarded_stars := int(star_rewards.get(level_id, 0))
	var new_best_stars := int(update.get("new_best_stars"))
	var new_star_count := maxi(new_best_stars - rewarded_stars, 0)
	var new_star_coins := 0
	for star in range(rewarded_stars + 1, new_best_stars + 1):
		new_star_coins += _apply_grant(
			state,
			CURRENCY_COINS,
			COINS_PER_NEW_STAR,
			"new_star",
			"star_reward:%s:%d" % [level_id, star]
		)
	if new_star_count > 0:
		star_rewards[level_id] = new_best_stars
		state.rewarded_star_milestones = star_rewards

	var best_rewards := state.get("rewarded_best_shots", {}) as Dictionary
	var previous_fewest := int(update.get("previous_fewest_shots"))
	var new_fewest := int(update.get("new_fewest_shots"))
	var personal_best_coins := 0
	if previous_fewest >= 0 and new_fewest > 0 and new_fewest < previous_fewest:
		personal_best_coins = _apply_grant(
			state,
			CURRENCY_COINS,
			PERSONAL_BEST_BONUS,
			"personal_best",
			"personal_best:%s:%d" % [level_id, new_fewest]
		)
	if new_fewest > 0:
		var recorded_best := int(best_rewards.get(level_id, 999))
		best_rewards[level_id] = mini(recorded_best, new_fewest)
		state.rewarded_best_shots = best_rewards

	_save_service().call("set_economy_state_from_wallet", state, false)
	var total := completion_coins + first_completion_coins + new_star_coins + personal_best_coins
	update.set("completion_coins", completion_coins)
	update.set("first_completion_coins", first_completion_coins)
	update.set("new_star_coins", new_star_coins)
	update.set("personal_best_coins", personal_best_coins)
	update.set("coins_earned", total)
	update.set("coin_balance_before", balance_before)
	update.set("coin_balance_after", int(state.get(CURRENCY_COINS, 0)))
	if total > 0:
		balance_changed.emit(CURRENCY_COINS, int(state.get(CURRENCY_COINS, 0)), total, "level_rewards")


func get_rewarded_token_status(local_date: String = "") -> Dictionary:
	var date := local_date if not local_date.is_empty() else Time.get_date_string_from_system()
	var state := _economy_state()
	var daily := state.get("daily_rewarded_tokens", {}) as Dictionary
	var stored_date := String(daily.get("local_date", ""))
	if not stored_date.is_empty() and date < stored_date:
		return {
			"available": false,
			"reason": "clock_rollback",
			"completed_rewards": int(daily.get("completed_rewards", 0)),
			"tokens_granted": int(daily.get("tokens_granted", 0)),
			"rewards_remaining": 0,
			"tokens_remaining": 0,
			"local_date": stored_date,
		}
	if stored_date.is_empty() or date > stored_date:
		daily = {"local_date": date, "completed_rewards": 0, "tokens_granted": 0}
	var completed := clampi(int(daily.get("completed_rewards", 0)), 0, MAX_REWARDED_TOKEN_ADS_PER_DAY)
	var tokens := clampi(int(daily.get("tokens_granted", 0)), 0, MAX_FREE_TOKENS_PER_DAY)
	var rewards_remaining := maxi(MAX_REWARDED_TOKEN_ADS_PER_DAY - completed, 0)
	var tokens_remaining := maxi(MAX_FREE_TOKENS_PER_DAY - tokens, 0)
	return {
		"available": rewards_remaining > 0 and tokens_remaining >= REWARDED_TOKEN_AMOUNT,
		"reason": "" if rewards_remaining > 0 and tokens_remaining >= REWARDED_TOKEN_AMOUNT else "daily_limit",
		"completed_rewards": completed,
		"tokens_granted": tokens,
		"rewards_remaining": rewards_remaining,
		"tokens_remaining": tokens_remaining,
		"local_date": date,
	}


func claim_rewarded_token_ad(transaction_id: String, local_date: String = "") -> Dictionary:
	var status := get_rewarded_token_status(local_date)
	if not bool(status.get("available", false)):
		return {"granted": false, "reason": String(status.get("reason", "daily_limit")), "amount": 0}
	var state := _economy_state()
	if _has_processed(state, transaction_id):
		return {"granted": false, "reason": "duplicate_transaction", "amount": 0}
	var amount := _apply_grant(
		state,
		CURRENCY_TOKENS,
		REWARDED_TOKEN_AMOUNT,
		"rewarded_token_ad",
		transaction_id
	)
	if amount <= 0:
		return {"granted": false, "reason": "grant_failed", "amount": 0}
	var daily := state.get("daily_rewarded_tokens", {}) as Dictionary
	daily.local_date = String(status.get("local_date", ""))
	daily.completed_rewards = int(status.get("completed_rewards", 0)) + 1
	daily.tokens_granted = int(status.get("tokens_granted", 0)) + amount
	state.daily_rewarded_tokens = daily
	if not _persist_state(state):
		return {"granted": false, "reason": "save_failed", "amount": 0}
	balance_changed.emit(CURRENCY_TOKENS, int(state.get(CURRENCY_TOKENS, 0)), amount, "rewarded_token_ad")
	return {"granted": true, "reason": "", "amount": amount}


func purchase_cosmetic(cosmetic_id: String) -> Dictionary:
	var definition := CosmeticRegistryScript.get_definition(cosmetic_id)
	if definition.is_empty():
		return {"purchased": false, "reason": "invalid_cosmetic"}
	var save_service := _save_service()
	if not save_service:
		return {"purchased": false, "reason": "save_unavailable"}
	if bool(save_service.call("is_cosmetic_unlocked", cosmetic_id)):
		return {"purchased": false, "reason": "already_owned"}
	var acquisition := String(definition.get("acquisition_method", ""))
	if acquisition not in [
		CosmeticRegistryScript.ACQUISITION_COIN_PURCHASE,
		CosmeticRegistryScript.ACQUISITION_TOKEN_PURCHASE,
	]:
		return {"purchased": false, "reason": "not_purchasable"}
	var currency := CURRENCY_COINS if acquisition == CosmeticRegistryScript.ACQUISITION_COIN_PURCHASE else CURRENCY_TOKENS
	var price_key := "coin_price" if currency == CURRENCY_COINS else "token_price"
	var price := int(definition.get(price_key, 0))
	var state := _economy_state()
	if price <= 0 or int(state.get(currency, 0)) < price:
		return {"purchased": false, "reason": "insufficient_funds", "currency": currency, "price": price}
	var transaction_id := "cosmetic_purchase:%s" % cosmetic_id
	if _has_processed(state, transaction_id):
		return {"purchased": false, "reason": "already_processed"}
	var previous_balance := int(state.get(currency, 0))
	state[currency] = previous_balance - price
	_mark_processed(state, transaction_id)
	_append_history(state, transaction_id, currency, -price, "cosmetic_purchase")
	if not bool(save_service.call("commit_cosmetic_purchase", cosmetic_id, state)):
		return {"purchased": false, "reason": "save_failed"}
	var balance := previous_balance - price
	balance_changed.emit(currency, balance, -price, "cosmetic_purchase")
	cosmetic_purchased.emit(cosmetic_id, currency, price)
	return {"purchased": true, "reason": "", "currency": currency, "price": price, "balance": balance}


func fulfill_starter_pack_bonus() -> bool:
	var save_service := _save_service()
	if not save_service or not bool(save_service.call("has_entitlement", "entitlement_starter_pack")):
		return false
	var state := _economy_state()
	if _has_processed(state, STARTER_PACK_BONUS_TRANSACTION_ID):
		return false
	state[CURRENCY_COINS] = mini(int(state.get(CURRENCY_COINS, 0)) + STARTER_PACK_COINS, MAX_BALANCE)
	state[CURRENCY_TOKENS] = mini(int(state.get(CURRENCY_TOKENS, 0)) + STARTER_PACK_TOKENS, MAX_BALANCE)
	_mark_processed(state, STARTER_PACK_BONUS_TRANSACTION_ID)
	_append_history(state, STARTER_PACK_BONUS_TRANSACTION_ID, "bundle", STARTER_PACK_COINS + STARTER_PACK_TOKENS, "starter_pack_bonus")
	if not _persist_state(state):
		return false
	balance_changed.emit(CURRENCY_COINS, int(state.get(CURRENCY_COINS, 0)), STARTER_PACK_COINS, "starter_pack_bonus")
	balance_changed.emit(CURRENCY_TOKENS, int(state.get(CURRENCY_TOKENS, 0)), STARTER_PACK_TOKENS, "starter_pack_bonus")
	return true


func reset_wallet_for_development(save_to_disk: bool = true) -> bool:
	var state := _save_service().call("get_economy_state") as Dictionary
	state.arcade_coins = 0
	state.net_tokens = 0
	state.processed_transaction_ids = []
	state.transaction_history = []
	state.daily_rewarded_tokens = {"local_date": "", "completed_rewards": 0, "tokens_granted": 0}
	state.first_completion_rewards = []
	state.rewarded_star_milestones = {}
	state.rewarded_best_shots = {}
	state.next_transaction_sequence = 1
	return bool(_save_service().call("set_economy_state_from_wallet", state, save_to_disk))


func _grant_currency(currency: String, amount: int, reason: String, transaction_id: String, persist: bool) -> bool:
	var state := _economy_state()
	var granted := _apply_grant(state, currency, amount, reason, transaction_id)
	if granted <= 0:
		return false
	if persist and not _persist_state(state):
		return false
	balance_changed.emit(currency, int(state.get(currency, 0)), granted, reason)
	return true


func _spend_currency(currency: String, amount: int, reason: String, persist: bool) -> bool:
	if amount <= 0:
		return false
	var state := _economy_state()
	var current := int(state.get(currency, 0))
	if current < amount:
		return false
	var sequence := maxi(int(state.get("next_transaction_sequence", 1)), 1)
	state.next_transaction_sequence = sequence + 1
	var transaction_id := "spend:%s:%d" % [currency, sequence]
	state[currency] = current - amount
	_mark_processed(state, transaction_id)
	_append_history(state, transaction_id, currency, -amount, reason)
	if persist and not _persist_state(state):
		return false
	balance_changed.emit(currency, current - amount, -amount, reason)
	return true


func _apply_grant(state: Dictionary, currency: String, amount: int, reason: String, transaction_id: String) -> int:
	if amount <= 0 or transaction_id.strip_edges().is_empty() or _has_processed(state, transaction_id):
		return 0
	var current := clampi(int(state.get(currency, 0)), 0, MAX_BALANCE)
	var balance := mini(current + amount, MAX_BALANCE)
	var granted := balance - current
	if granted <= 0:
		return 0
	state[currency] = balance
	_mark_processed(state, transaction_id)
	_append_history(state, transaction_id, currency, granted, reason)
	return granted


func _mark_processed(state: Dictionary, transaction_id: String) -> void:
	var processed := state.get("processed_transaction_ids", []) as Array
	if not processed.has(transaction_id):
		processed.append(transaction_id)
	while processed.size() > MAX_PROCESSED_TRANSACTIONS:
		processed.pop_front()
	state.processed_transaction_ids = processed


func _has_processed(state: Dictionary, transaction_id: String) -> bool:
	return not transaction_id.is_empty() and (state.get("processed_transaction_ids", []) as Array).has(transaction_id)


func _append_history(state: Dictionary, transaction_id: String, currency: String, delta: int, reason: String) -> void:
	var history := state.get("transaction_history", []) as Array
	history.append({
		"transaction_id": transaction_id,
		"currency": currency,
		"delta": delta,
		"reason": reason,
		"unix_time": Time.get_unix_time_from_system(),
	})
	while history.size() > MAX_TRANSACTION_HISTORY:
		history.pop_front()
	state.transaction_history = history


func _persist_state(state: Dictionary) -> bool:
	var service := _save_service()
	return bool(service and service.call("set_economy_state_from_wallet", state, true))


func _economy_state() -> Dictionary:
	var service := _save_service()
	return service.call("get_economy_state") as Dictionary if service else {}


func _save_service() -> Node:
	if _save_service_override:
		return _save_service_override
	return get_node_or_null("/root/SaveService")


func _reconcile_owned_products() -> void:
	var service := _save_service()
	if service and service.has_method("configure_wallet_service"):
		service.call("configure_wallet_service", self)
	fulfill_starter_pack_bonus()
