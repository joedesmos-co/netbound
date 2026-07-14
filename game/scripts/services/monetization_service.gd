class_name NetboundMonetizationService
extends Node

signal rewarded_ad_started(context: String, request_id: int)
signal rewarded_ad_completed(context: String, request_id: int)
signal rewarded_ad_failed(context: String, request_id: int, reason: String)
signal reward_granted(context: String, request_id: int, metadata: Dictionary)
signal interstitial_shown(context: String, request_id: int)
signal purchase_started(product_id: String, request_id: int)
signal purchase_completed(product_id: String, request_id: int)
signal purchase_failed(product_id: String, request_id: int, reason: String)
signal purchases_restored(product_ids: Array[String], request_id: int)
signal entitlement_changed(entitlement_id: String)

const AdProviderScript := preload("res://scripts/monetization/ad_provider.gd")
const PurchaseProviderScript := preload("res://scripts/monetization/purchase_provider.gd")
const SimulatedAdProviderScript := preload("res://scripts/monetization/simulated_ad_provider.gd")
const SimulatedPurchaseProviderScript := preload("res://scripts/monetization/simulated_purchase_provider.gd")

const ENTITLEMENT_REMOVE_ADS := "entitlement_remove_ads"
const ENTITLEMENT_STARTER_PACK := "entitlement_starter_pack"
const PRODUCT_REMOVE_ADS := "netbound_remove_ads"
const PRODUCT_STARTER_PACK := "netbound_starter_pack"

const CONTEXT_REWARDED_CONTINUE := "rewarded_continue"
const CONTEXT_NEXT_LEVEL := "next_level"
const CONTEXT_LEVEL_SELECT_AFTER_SUCCESS := "level_select_after_success"

const MIN_COMPLETED_LEVELS_BEFORE_INTERSTITIAL := 3
const COMPLETIONS_PER_INTERSTITIAL := 3

@export var ads_enabled: bool = true
@export var purchases_enabled: bool = true
@export var minimum_interstitial_interval_seconds: float = 180.0

var ad_provider
var purchase_provider
var session_completed_levels_for_ads: int = 0
var interstitial_shown_this_session: bool = false
var last_interstitial_msec: int = -999999999
var last_status_message: String = ""

var _next_request_id: int = 1
var _active_rewarded_request: Dictionary = {}
var _active_interstitial_request: Dictionary = {}
var _active_purchase_request: Dictionary = {}
var _completed_reward_tokens: Dictionary = {}
var _completed_purchase_tokens: Dictionary = {}


func _ready() -> void:
	ad_provider = SimulatedAdProviderScript.new()
	purchase_provider = SimulatedPurchaseProviderScript.new()
	var service := _save_service()
	if service:
		apply_config_from_save(service)


func get_ad_provider():
	return ad_provider


func get_purchase_provider():
	return purchase_provider


func configure_simulated_ads(
	available: bool = true,
	rewarded_mode: String = "success",
	interstitial_mode: String = "success",
	delay_frames: int = 1,
	duplicate_callback: bool = false
) -> void:
	if ad_provider and ad_provider.has_method("configure"):
		ad_provider.call("configure", available, rewarded_mode, interstitial_mode, delay_frames, duplicate_callback)


func configure_simulated_purchases(
	available: bool = true,
	purchase_mode: String = "success",
	restore_mode: String = "success",
	delay_frames: int = 1,
	duplicate_callback: bool = false
) -> void:
	if purchase_provider and purchase_provider.has_method("configure"):
		purchase_provider.call("configure", available, purchase_mode, restore_mode, delay_frames, duplicate_callback)


func set_simulated_restore_products(product_ids: Array[String]) -> void:
	if purchase_provider and purchase_provider.has_method("set_restored_products"):
		purchase_provider.call("set_restored_products", product_ids)


func apply_config_from_save(save_service: Node) -> void:
	if not save_service or not save_service.has_method("get_monetization_config"):
		return
	var config: Dictionary = save_service.call("get_monetization_config")
	ads_enabled = bool(config.get("ads_enabled", true))
	purchases_enabled = bool(config.get("purchases_enabled", true))


func has_entitlement(entitlement_id: String) -> bool:
	var service := _save_service()
	return bool(service and service.has_method("has_entitlement") and service.call("has_entitlement", entitlement_id))


func is_rewarded_ad_available() -> bool:
	return ads_enabled and ad_provider != null and ad_provider.is_rewarded_available()


func is_purchase_available() -> bool:
	return purchases_enabled and purchase_provider != null and purchase_provider.is_available()


func is_interstitial_allowed(context: String) -> bool:
	return should_show_interstitial(context)


func request_rewarded_ad(context: String, metadata: Dictionary = {}) -> Dictionary:
	if not is_rewarded_ad_available():
		return _blocked_result("rewarded ad unavailable")
	if not _active_rewarded_request.is_empty():
		return _blocked_result("rewarded ad already running")
	var request_id := _new_request_id()
	_active_rewarded_request = {
		"request_id": request_id,
		"context": context,
		"metadata": metadata.duplicate(true),
	}
	last_status_message = "Simulated rewarded ad requested"
	rewarded_ad_started.emit(context, request_id)
	ad_provider.request_rewarded(request_id, context, Callable(self, "_on_rewarded_ad_result"))
	return {"accepted": true, "request_id": request_id, "reason": ""}


func request_interstitial(context: String) -> Dictionary:
	if not should_show_interstitial(context):
		return _blocked_result("interstitial skipped by policy")
	if not _active_interstitial_request.is_empty():
		return _blocked_result("interstitial already running")
	var request_id := _new_request_id()
	_active_interstitial_request = {
		"request_id": request_id,
		"context": context,
	}
	last_status_message = "Simulated interstitial requested"
	ad_provider.request_interstitial(request_id, context, Callable(self, "_on_interstitial_result"))
	return {"accepted": true, "request_id": request_id, "reason": ""}


func purchase_remove_ads() -> Dictionary:
	return _purchase_product(PRODUCT_REMOVE_ADS)


func purchase_starter_pack() -> Dictionary:
	return _purchase_product(PRODUCT_STARTER_PACK)


func restore_purchases() -> Dictionary:
	if not is_purchase_available():
		return _blocked_result("purchases unavailable")
	if not _active_purchase_request.is_empty():
		return _blocked_result("purchase already running")
	var request_id := _new_request_id()
	_active_purchase_request = {
		"request_id": request_id,
		"product_id": "restore",
		"restore": true,
	}
	purchase_started.emit("restore", request_id)
	purchase_provider.restore(request_id, Callable(self, "_on_restore_result"))
	return {"accepted": true, "request_id": request_id, "reason": ""}


func get_product_info(product_id: String) -> Dictionary:
	if not is_purchase_available():
		return {"product_id": product_id, "price_text": "Unavailable", "available": false}
	return purchase_provider.get_product_info(product_id)


func should_show_interstitial(context: String) -> bool:
	if not ads_enabled or not ad_provider or not ad_provider.is_interstitial_available():
		return false
	if has_entitlement(ENTITLEMENT_REMOVE_ADS) or has_entitlement(ENTITLEMENT_STARTER_PACK):
		return false
	if context.is_empty() or context == CONTEXT_REWARDED_CONTINUE:
		return false
	if _active_interstitial_request.size() > 0 or interstitial_shown_this_session:
		return false
	if session_completed_levels_for_ads < COMPLETIONS_PER_INTERSTITIAL:
		return false
	var service := _save_service()
	if service and service.has_method("get_completed_level_count"):
		if int(service.call("get_completed_level_count")) < MIN_COMPLETED_LEVELS_BEFORE_INTERSTITIAL:
			return false
	var now := Time.get_ticks_msec()
	var elapsed := float(now - last_interstitial_msec) / 1000.0
	return elapsed >= minimum_interstitial_interval_seconds


func record_level_completion_for_ads() -> void:
	session_completed_levels_for_ads += 1


func record_interstitial_shown() -> void:
	interstitial_shown_this_session = true
	session_completed_levels_for_ads = 0
	last_interstitial_msec = Time.get_ticks_msec()


func reset_session_frequency_for_tests() -> void:
	session_completed_levels_for_ads = 0
	interstitial_shown_this_session = false
	last_interstitial_msec = -999999999
	_active_rewarded_request.clear()
	_active_interstitial_request.clear()
	_active_purchase_request.clear()
	_completed_reward_tokens.clear()
	_completed_purchase_tokens.clear()


func _purchase_product(product_id: String) -> Dictionary:
	if not is_purchase_available():
		return _blocked_result("purchases unavailable")
	if _is_product_owned(product_id):
		return _blocked_result("already owned")
	if not _active_purchase_request.is_empty():
		return _blocked_result("purchase already running")
	var request_id := _new_request_id()
	_active_purchase_request = {
		"request_id": request_id,
		"product_id": product_id,
		"restore": false,
	}
	purchase_started.emit(product_id, request_id)
	purchase_provider.purchase(request_id, product_id, Callable(self, "_on_purchase_result"))
	return {"accepted": true, "request_id": request_id, "reason": ""}


func _on_rewarded_ad_result(payload: Dictionary) -> void:
	var request_id := int(payload.get("request_id", -1))
	if _active_rewarded_request.is_empty() or request_id != int(_active_rewarded_request.get("request_id", -2)):
		return
	var context := String(_active_rewarded_request.get("context", ""))
	var result := String(payload.get("result", AdProviderScript.RESULT_FAILED))
	if result == AdProviderScript.RESULT_COMPLETED:
		if _completed_reward_tokens.has(request_id):
			return
		_completed_reward_tokens[request_id] = true
		var metadata := (_active_rewarded_request.get("metadata", {}) as Dictionary).duplicate(true)
		_active_rewarded_request.clear()
		rewarded_ad_completed.emit(context, request_id)
		reward_granted.emit(context, request_id, metadata)
		return
	_active_rewarded_request.clear()
	rewarded_ad_failed.emit(context, request_id, result)


func _on_interstitial_result(payload: Dictionary) -> void:
	var request_id := int(payload.get("request_id", -1))
	if _active_interstitial_request.is_empty() or request_id != int(_active_interstitial_request.get("request_id", -2)):
		return
	var context := String(_active_interstitial_request.get("context", ""))
	_active_interstitial_request.clear()
	if String(payload.get("result", AdProviderScript.RESULT_FAILED)) == AdProviderScript.RESULT_COMPLETED:
		record_interstitial_shown()
		interstitial_shown.emit(context, request_id)


func _on_purchase_result(payload: Dictionary) -> void:
	var request_id := int(payload.get("request_id", -1))
	if _active_purchase_request.is_empty() or request_id != int(_active_purchase_request.get("request_id", -2)):
		return
	var product_id := String(_active_purchase_request.get("product_id", ""))
	var result := String(payload.get("result", PurchaseProviderScript.RESULT_FAILED))
	if result == PurchaseProviderScript.RESULT_COMPLETED or result == PurchaseProviderScript.RESULT_ALREADY_OWNED:
		_complete_product_grant(product_id, request_id, payload)
		return
	_active_purchase_request.clear()
	purchase_failed.emit(product_id, request_id, result)


func _on_restore_result(payload: Dictionary) -> void:
	var request_id := int(payload.get("request_id", -1))
	if _active_purchase_request.is_empty() or request_id != int(_active_purchase_request.get("request_id", -2)):
		return
	var result := String(payload.get("result", PurchaseProviderScript.RESULT_FAILED))
	if result != PurchaseProviderScript.RESULT_RESTORED and result != PurchaseProviderScript.RESULT_COMPLETED:
		_active_purchase_request.clear()
		purchase_failed.emit("restore", request_id, result)
		return
	var restored: Array[String] = []
	var raw_products: Variant = payload.get("product_ids", [])
	if typeof(raw_products) == TYPE_ARRAY:
		for item in raw_products as Array:
			var product_id := String(item)
			if _grant_product(product_id, String(payload.get("transaction_id", "")), "simulated_restore"):
				restored.append(product_id)
	_active_purchase_request.clear()
	purchases_restored.emit(restored, request_id)


func _complete_product_grant(product_id: String, request_id: int, payload: Dictionary) -> void:
	if _completed_purchase_tokens.has(request_id):
		return
	_completed_purchase_tokens[request_id] = true
	_grant_product(product_id, String(payload.get("transaction_id", "")), String(payload.get("provider", "simulated")))
	_active_purchase_request.clear()
	purchase_completed.emit(product_id, request_id)


func _grant_product(product_id: String, transaction_id: String, provider_name: String) -> bool:
	var service := _save_service()
	if not service or not service.has_method("record_purchase"):
		return false
	var changed := bool(service.call("record_purchase", product_id, transaction_id, provider_name))
	for entitlement_id in _entitlements_for_product(product_id):
		entitlement_changed.emit(entitlement_id)
	return changed


func _entitlements_for_product(product_id: String) -> Array[String]:
	match product_id:
		PRODUCT_REMOVE_ADS:
			return [ENTITLEMENT_REMOVE_ADS]
		PRODUCT_STARTER_PACK:
			return [ENTITLEMENT_REMOVE_ADS, ENTITLEMENT_STARTER_PACK]
		_:
			return []


func _is_product_owned(product_id: String) -> bool:
	var service := _save_service()
	if service and service.has_method("is_product_owned"):
		return bool(service.call("is_product_owned", product_id))
	return false


func _save_service() -> Node:
	return get_node_or_null("/root/SaveService")


func _blocked_result(reason: String) -> Dictionary:
	last_status_message = reason
	return {"accepted": false, "request_id": -1, "reason": reason}


func _new_request_id() -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	return request_id
