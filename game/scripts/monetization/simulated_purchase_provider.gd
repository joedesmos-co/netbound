class_name NetboundSimulatedPurchaseProvider
extends "res://scripts/monetization/purchase_provider.gd"

const MODE_SUCCESS := "success"
const MODE_CANCEL := "cancel"
const MODE_FAILURE := "failure"
const MODE_ALREADY_OWNED := "already_owned"
const MODE_UNAVAILABLE := "unavailable"

var available: bool = true
var purchase_mode: String = MODE_SUCCESS
var restore_mode: String = MODE_SUCCESS
var delayed_callback_frames: int = 1
var duplicate_callback_enabled: bool = false
var forced_transaction_id: String = ""
var restored_product_ids: Array[String] = []
var product_prices: Dictionary = {
	"netbound_remove_ads": "DEV $2.99",
	"netbound_starter_pack": "DEV $5.99",
	"netbound_tokens_100": "DEV $0.99",
	"netbound_tokens_275": "DEV $1.99",
	"netbound_tokens_600": "DEV $3.99",
	"netbound_tokens_1300": "DEV $6.99",
	"netbound_tokens_3000": "DEV $12.99",
}


func is_available() -> bool:
	return available


func configure(
	is_available: bool = true,
	new_purchase_mode: String = MODE_SUCCESS,
	new_restore_mode: String = MODE_SUCCESS,
	frames: int = 1,
	duplicate_callback: bool = false
) -> void:
	available = is_available
	purchase_mode = new_purchase_mode
	restore_mode = new_restore_mode
	delayed_callback_frames = maxi(frames, 0)
	duplicate_callback_enabled = duplicate_callback


func set_restored_products(product_ids: Array[String]) -> void:
	restored_product_ids = product_ids.duplicate()


func set_forced_transaction_id(transaction_id: String) -> void:
	forced_transaction_id = transaction_id


func get_product_info(product_id: String) -> Dictionary:
	return {
		"product_id": product_id,
		"price_text": String(product_prices.get(product_id, "DEV --")),
		"available": available,
		"provider": "simulated",
	}


func purchase(request_id: int, product_id: String, callback: Callable) -> void:
	_deliver_later({
		"request_id": request_id,
		"product_id": product_id,
		"result": _mode_to_result(purchase_mode, false),
		"transaction_id": forced_transaction_id if not forced_transaction_id.is_empty() else "sim_%s_%d" % [product_id, request_id],
		"provider": "simulated",
	}, callback)


func restore(request_id: int, callback: Callable) -> void:
	_deliver_later({
		"request_id": request_id,
		"result": _mode_to_result(restore_mode, true),
		"product_ids": restored_product_ids.duplicate(),
		"transaction_id": "sim_restore_%d" % request_id,
		"provider": "simulated",
	}, callback)


func _mode_to_result(mode: String, is_restore: bool) -> String:
	if not available or mode == MODE_UNAVAILABLE:
		return RESULT_UNAVAILABLE
	match mode:
		MODE_SUCCESS:
			return RESULT_RESTORED if is_restore else RESULT_COMPLETED
		MODE_ALREADY_OWNED:
			return RESULT_ALREADY_OWNED
		MODE_CANCEL:
			return RESULT_CANCELLED
		MODE_FAILURE:
			return RESULT_FAILED
		_:
			return RESULT_FAILED


func _deliver_later(payload: Dictionary, callback: Callable) -> void:
	if delayed_callback_frames <= 0:
		callback.call(payload)
		if duplicate_callback_enabled:
			callback.call(payload.duplicate(true))
		return
	var tree := Engine.get_main_loop() as SceneTree
	if not tree:
		callback.call(payload)
		return
	var frames := delayed_callback_frames
	while frames > 0:
		await tree.process_frame
		frames -= 1
	callback.call(payload)
	if duplicate_callback_enabled:
		await tree.process_frame
		callback.call(payload.duplicate(true))
