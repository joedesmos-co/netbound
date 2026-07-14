class_name NetboundHapticsService
extends Node

const DEFAULT_COOLDOWN := 0.06
const EVENT_DURATIONS_MS := {
	"ui_tap": 18,
	"shot_release": 34,
	"strong_shot": 48,
	"obstacle_impact": 28,
	"post_hit": 42,
	"goal": 75,
	"cosmetic_unlock": 60,
}
const EVENT_COOLDOWNS := {
	"obstacle_impact": 0.12,
	"post_hit": 0.18,
	"goal": 0.5,
	"cosmetic_unlock": 0.4,
}

var enabled: bool = true
var _last_emit_time: Dictionary = {}
var _emitted_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var service := get_node_or_null("/root/SaveService")
	if service:
		apply_settings_from_save(service)


func apply_settings_from_save(save_service: Node) -> void:
	if not save_service:
		return
	enabled = bool(save_service.get_setting_value("haptics_enabled", true))


func emit_event(event_name: String, strength: float = 1.0) -> bool:
	if not enabled:
		return false
	if not _cooldown_ready(event_name):
		return false
	var duration := int(EVENT_DURATIONS_MS.get(event_name, 22))
	duration = maxi(1, roundi(float(duration) * clampf(strength, 0.25, 1.25)))
	_last_emit_time[event_name] = Time.get_ticks_msec()
	_emitted_count += 1
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration)
	return true


func reset_for_tests() -> void:
	_last_emit_time.clear()
	_emitted_count = 0


func get_emitted_count() -> int:
	return _emitted_count


func _cooldown_ready(event_name: String) -> bool:
	var cooldown := float(EVENT_COOLDOWNS.get(event_name, DEFAULT_COOLDOWN))
	var now := Time.get_ticks_msec()
	var last := int(_last_emit_time.get(event_name, -1000000))
	return float(now - last) / 1000.0 >= cooldown
