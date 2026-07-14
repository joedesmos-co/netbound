class_name NetboundAdProvider
extends RefCounted

const RESULT_COMPLETED := "completed"
const RESULT_CANCELLED := "cancelled"
const RESULT_FAILED := "failed"
const RESULT_UNAVAILABLE := "unavailable"


func is_rewarded_available() -> bool:
	return false


func is_interstitial_available() -> bool:
	return false


func request_rewarded(_request_id: int, _context: String, callback: Callable) -> void:
	callback.call({
		"request_id": _request_id,
		"context": _context,
		"result": RESULT_UNAVAILABLE,
		"provider": "base",
	})


func request_interstitial(_request_id: int, _context: String, callback: Callable) -> void:
	callback.call({
		"request_id": _request_id,
		"context": _context,
		"result": RESULT_UNAVAILABLE,
		"provider": "base",
	})
