class_name NetboundMobileRuntimeService
extends Node

signal app_backgrounded(reason: String)
signal app_foregrounded(reason: String)
signal app_quit_requested(reason: String)
signal safe_area_changed(margins: Dictionary)
signal quality_changed(selected_tier: String, effective_tier: String, config: Dictionary)

const QUALITY_AUTO := "auto"
const QUALITY_LOW := "low"
const QUALITY_MEDIUM := "medium"
const QUALITY_HIGH := "high"
const VALID_QUALITY_TIERS := [QUALITY_AUTO, QUALITY_LOW, QUALITY_MEDIUM, QUALITY_HIGH]

const SAFE_MARGIN_DEFAULT := 28.0
const RELEASE_FEATURE := "netbound_release"
const DEVELOPMENT_FEATURE := "netbound_development"

var _is_backgrounded: bool = false
var _safe_area_override_enabled: bool = false
var _safe_area_override: Dictionary = {}
var _last_safe_area_margins: Dictionary = {}
var _release_mode_override: int = -1
var _selected_quality_tier: String = QUALITY_AUTO
var _effective_quality_tier: String = QUALITY_HIGH
var _quality_config: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_effective_quality_tier = get_effective_quality_tier(_selected_quality_tier)
	_quality_config = get_quality_config(_selected_quality_tier)
	_last_safe_area_margins = get_safe_area_margins()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_enter_background_state("focus_out")
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_enter_background_state("paused")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_enter_foreground_state("focus_in")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_enter_foreground_state("resumed")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_runtime_state()
		app_quit_requested.emit("window_close")


func normalize_quality_tier(value: Variant) -> String:
	var tier := String(value).to_lower()
	return tier if VALID_QUALITY_TIERS.has(tier) else QUALITY_AUTO


func get_quality_tier_labels() -> Array[String]:
	return [QUALITY_AUTO, QUALITY_LOW, QUALITY_MEDIUM, QUALITY_HIGH]


func get_selected_quality_tier() -> String:
	return _selected_quality_tier


func get_effective_quality_tier(selected_tier: String = "") -> String:
	var normalized := normalize_quality_tier(selected_tier if not selected_tier.is_empty() else _selected_quality_tier)
	if normalized != QUALITY_AUTO:
		return normalized
	return QUALITY_MEDIUM if OS.has_feature("mobile") else QUALITY_HIGH


func get_quality_config(selected_tier: String = "") -> Dictionary:
	var selected := normalize_quality_tier(selected_tier if not selected_tier.is_empty() else _selected_quality_tier)
	var effective := get_effective_quality_tier(selected)
	var config := {
		"selected_tier": selected,
		"effective_tier": effective,
		"decorative_geometry_enabled": true,
		"contact_shadow_enabled": true,
		"dynamic_shadows_enabled": true,
		"trail_point_limit": 16,
		"particle_multiplier": 1.0,
		"camera_effects_multiplier": 1.0,
	}
	match effective:
		QUALITY_LOW:
			config.decorative_geometry_enabled = false
			config.contact_shadow_enabled = false
			config.dynamic_shadows_enabled = false
			config.trail_point_limit = 8
			config.particle_multiplier = 0.45
			config.camera_effects_multiplier = 0.75
		QUALITY_MEDIUM:
			config.decorative_geometry_enabled = true
			config.contact_shadow_enabled = true
			config.dynamic_shadows_enabled = false
			config.trail_point_limit = 12
			config.particle_multiplier = 0.7
			config.camera_effects_multiplier = 0.9
		_:
			pass
	return config


func apply_quality_from_save(save_service: Node) -> Dictionary:
	if save_service and save_service.has_method("get_setting_value"):
		_selected_quality_tier = normalize_quality_tier(save_service.call("get_setting_value", "quality_tier", QUALITY_AUTO))
	else:
		_selected_quality_tier = QUALITY_AUTO
	_effective_quality_tier = get_effective_quality_tier(_selected_quality_tier)
	_quality_config = get_quality_config(_selected_quality_tier)
	quality_changed.emit(_selected_quality_tier, _effective_quality_tier, _quality_config.duplicate(true))
	return _quality_config.duplicate(true)


func apply_quality_to_node(node: Node) -> void:
	if node and node.has_method("apply_quality_settings"):
		node.call("apply_quality_settings", _quality_config.duplicate(true))


func get_safe_area_margins(base_margin: float = SAFE_MARGIN_DEFAULT) -> Dictionary:
	var margins := _platform_safe_area_margins(base_margin)
	if _safe_area_override_enabled:
		margins.left = maxf(float(margins.left), float(_safe_area_override.get("left", base_margin)))
		margins.top = maxf(float(margins.top), float(_safe_area_override.get("top", base_margin)))
		margins.right = maxf(float(margins.right), float(_safe_area_override.get("right", base_margin)))
		margins.bottom = maxf(float(margins.bottom), float(_safe_area_override.get("bottom", base_margin)))
	return margins


func set_safe_area_override_for_tests(
	left: float,
	top: float,
	right: float,
	bottom: float
) -> void:
	_safe_area_override_enabled = true
	_safe_area_override = {
		"left": left,
		"top": top,
		"right": right,
		"bottom": bottom,
	}
	_emit_safe_area_if_changed(true)


func clear_safe_area_override_for_tests() -> void:
	_safe_area_override_enabled = false
	_safe_area_override.clear()
	_emit_safe_area_if_changed(true)


func is_release_mode() -> bool:
	if _release_mode_override >= 0:
		return _release_mode_override == 1
	return OS.has_feature(RELEASE_FEATURE) and not OS.has_feature(DEVELOPMENT_FEATURE)


func allow_development_controls() -> bool:
	return OS.is_debug_build() and not is_release_mode()


func set_release_mode_override_for_tests(enabled: int) -> void:
	_release_mode_override = enabled


func apply_release_configuration(monetization_service: Node) -> void:
	if monetization_service and monetization_service.has_method("set_release_mode_enabled"):
		monetization_service.call("set_release_mode_enabled", is_release_mode())


func simulate_background_for_tests(reason: String = "test_background") -> void:
	_enter_background_state(reason)


func simulate_foreground_for_tests(reason: String = "test_foreground") -> void:
	_enter_foreground_state(reason)


func flush_runtime_state_for_tests() -> bool:
	return _flush_runtime_state()


func get_runtime_snapshot() -> Dictionary:
	return {
		"backgrounded": _is_backgrounded,
		"selected_quality": _selected_quality_tier,
		"effective_quality": _effective_quality_tier,
		"release_mode": is_release_mode(),
		"safe_area": get_safe_area_margins(),
	}


func _platform_safe_area_margins(base_margin: float) -> Dictionary:
	var margins := {
		"left": base_margin,
		"top": base_margin,
		"right": base_margin,
		"bottom": base_margin,
	}
	if not OS.has_feature("mobile"):
		return margins

	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() else Vector2.ZERO
	var window_size := Vector2(DisplayServer.window_get_size())
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or window_size.x <= 0.0 or window_size.y <= 0.0:
		return margins

	var safe_rect := DisplayServer.get_display_safe_area()
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return margins

	var scale_x := viewport_size.x / window_size.x
	var scale_y := viewport_size.y / window_size.y
	margins.left = maxf(base_margin, float(safe_rect.position.x) * scale_x)
	margins.top = maxf(base_margin, float(safe_rect.position.y) * scale_y)
	margins.right = maxf(base_margin, float(window_size.x - safe_rect.end.x) * scale_x)
	margins.bottom = maxf(base_margin, float(window_size.y - safe_rect.end.y) * scale_y)
	return margins


func _on_viewport_size_changed() -> void:
	_emit_safe_area_if_changed()


func _emit_safe_area_if_changed(force: bool = false) -> void:
	var margins := get_safe_area_margins()
	if force or margins != _last_safe_area_margins:
		_last_safe_area_margins = margins.duplicate(true)
		safe_area_changed.emit(margins.duplicate(true))


func _enter_background_state(reason: String) -> void:
	if _is_backgrounded:
		return
	_is_backgrounded = true
	_flush_runtime_state()
	_pause_audio_for_lifecycle()
	app_backgrounded.emit(reason)


func _enter_foreground_state(reason: String) -> void:
	if not _is_backgrounded:
		return
	_is_backgrounded = false
	_resume_audio_for_lifecycle()
	app_foregrounded.emit(reason)
	_emit_safe_area_if_changed(true)


func _flush_runtime_state() -> bool:
	if not is_inside_tree():
		return true
	var save_service := get_node_or_null("/root/SaveService")
	if save_service and save_service.has_method("flush_if_dirty"):
		return bool(save_service.call("flush_if_dirty"))
	return true


func _pause_audio_for_lifecycle() -> void:
	if not is_inside_tree():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service and audio_service.has_method("handle_app_backgrounded"):
		audio_service.call("handle_app_backgrounded")


func _resume_audio_for_lifecycle() -> void:
	if not is_inside_tree():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service and audio_service.has_method("handle_app_foregrounded"):
		audio_service.call("handle_app_foregrounded")
