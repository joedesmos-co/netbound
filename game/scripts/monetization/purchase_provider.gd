class_name NetboundPurchaseProvider
extends RefCounted

const RESULT_COMPLETED := "completed"
const RESULT_CANCELLED := "cancelled"
const RESULT_FAILED := "failed"
const RESULT_ALREADY_OWNED := "already_owned"
const RESULT_RESTORED := "restored"
const RESULT_UNAVAILABLE := "unavailable"


func is_available() -> bool:
	return false


func get_product_info(product_id: String) -> Dictionary:
	return {
		"product_id": product_id,
		"price_text": "Unavailable",
		"available": false,
	}


func purchase(_request_id: int, product_id: String, callback: Callable) -> void:
	callback.call({
		"request_id": _request_id,
		"product_id": product_id,
		"result": RESULT_UNAVAILABLE,
		"provider": "base",
	})


func restore(_request_id: int, callback: Callable) -> void:
	callback.call({
		"request_id": _request_id,
		"result": RESULT_UNAVAILABLE,
		"product_ids": [],
		"provider": "base",
	})
