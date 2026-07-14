class_name NetboundSimulatedAdProvider
extends "res://scripts/monetization/ad_provider.gd"

const MODE_SUCCESS := "success"
const MODE_CANCEL := "cancel"
const MODE_FAILURE := "failure"
const MODE_UNAVAILABLE := "unavailable"

var available: bool = true
var rewarded_mode: String = MODE_SUCCESS
var interstitial_mode: String = MODE_SUCCESS
var delayed_callback_frames: int = 1
var duplicate_callback_enabled: bool = false


func is_rewarded_available() -> bool:
	return available and rewarded_mode != MODE_UNAVAILABLE


func is_interstitial_available() -> bool:
	return available and interstitial_mode != MODE_UNAVAILABLE


func configure(
	is_available: bool = true,
	new_rewarded_mode: String = MODE_SUCCESS,
	new_interstitial_mode: String = MODE_SUCCESS,
	frames: int = 1,
	duplicate_callback: bool = false
) -> void:
	available = is_available
	rewarded_mode = new_rewarded_mode
	interstitial_mode = new_interstitial_mode
	delayed_callback_frames = maxi(frames, 0)
	duplicate_callback_enabled = duplicate_callback


func request_rewarded(request_id: int, context: String, callback: Callable) -> void:
	_deliver_later(_result_payload(request_id, context, _mode_to_result(rewarded_mode), "rewarded"), callback)


func request_interstitial(request_id: int, context: String, callback: Callable) -> void:
	_deliver_later(_result_payload(request_id, context, _mode_to_result(interstitial_mode), "interstitial"), callback)


func _mode_to_result(mode: String) -> String:
	if not available or mode == MODE_UNAVAILABLE:
		return RESULT_UNAVAILABLE
	match mode:
		MODE_SUCCESS:
			return RESULT_COMPLETED
		MODE_CANCEL:
			return RESULT_CANCELLED
		MODE_FAILURE:
			return RESULT_FAILED
		_:
			return RESULT_FAILED


func _result_payload(request_id: int, context: String, result: String, ad_type: String) -> Dictionary:
	return {
		"request_id": request_id,
		"context": context,
		"result": result,
		"ad_type": ad_type,
		"provider": "simulated",
	}


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
