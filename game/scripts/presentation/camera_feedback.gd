class_name NetboundCameraFeedback
extends Node

const SHOT_DURATION := 0.22
const IMPACT_DURATION := 0.18
const GOAL_DURATION := 0.42

var reduced_motion_enabled: bool = false
var intensity: float = 1.0
var _time_remaining: float = 0.0
var _duration: float = 0.0
var _strength: float = 0.0
var _phase: float = 0.0


func configure(reduced_motion: bool, camera_effects_intensity: float) -> void:
	reduced_motion_enabled = reduced_motion
	intensity = clampf(camera_effects_intensity, 0.0, 1.0)
	if reduced_motion_enabled:
		intensity *= 0.18


func add_impulse(kind: String, strength: float = 1.0) -> void:
	if intensity <= 0.001:
		return
	match kind:
		"goal":
			_duration = GOAL_DURATION
			_strength = 0.18
			_phase = 1.7
		"post", "impact":
			_duration = IMPACT_DURATION
			_strength = 0.08
			_phase = 2.4
		_:
			_duration = SHOT_DURATION
			_strength = 0.055
			_phase = 0.6
	_strength *= clampf(strength, 0.2, 1.35) * intensity
	_time_remaining = maxf(_time_remaining, _duration)


func get_offset(delta: float) -> Vector3:
	if _time_remaining <= 0.0 or _duration <= 0.0:
		return Vector3.ZERO
	_time_remaining = maxf(_time_remaining - delta, 0.0)
	var age := 1.0 - (_time_remaining / _duration)
	var falloff := pow(1.0 - age, 1.6)
	var x := sin((age * 36.0) + _phase) * _strength * falloff
	var y := sin((age * 53.0) + _phase * 0.7) * _strength * 0.45 * falloff
	return Vector3(x, y, 0.0)


func clear() -> void:
	_time_remaining = 0.0
	_duration = 0.0
	_strength = 0.0
