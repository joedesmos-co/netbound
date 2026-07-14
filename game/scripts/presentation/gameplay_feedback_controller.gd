class_name NetboundGameplayFeedback
extends Node3D

const CameraFeedbackScript := preload("res://scripts/presentation/camera_feedback.gd")

const MAX_AIM_DOTS := 14
const GRAVITY_SCALE := 0.58
const FEEDBACK_GROUP := "netbound_presentation_feedback"

var reduced_motion_enabled: bool = false
var camera_effects_intensity: float = 1.0
var _ball: RigidBody3D
var _ui_root: Node
var _camera_feedback
var _aim_dots: Array[MeshInstance3D] = []
var _aim_materials: Array[StandardMaterial3D] = []
var _shot_label: Label
var _near_miss_label: Label
var _active_tweens: Array[Tween] = []


func setup(ball: RigidBody3D, ui_root: Node) -> void:
	_ball = ball
	_ui_root = ui_root
	add_to_group(FEEDBACK_GROUP)
	_camera_feedback = CameraFeedbackScript.new()
	_camera_feedback.name = "CameraFeedback"
	add_child(_camera_feedback)
	_build_aim_dots()
	_build_ui()
	_apply_settings()


func configure_from_save(save_service: Node) -> void:
	if not save_service:
		return
	reduced_motion_enabled = bool(save_service.get_setting_value("reduced_motion_enabled", false))
	camera_effects_intensity = clampf(
		float(save_service.get_setting_value("camera_effects_intensity", 1.0)),
		0.0,
		1.0
	)
	_apply_settings()


func show_aim_preview(
	origin: Vector3,
	launch_velocity: Vector3,
	curve_amount: float,
	max_curve_heading_degrees: float,
	curve_duration: float,
	shot_category: String,
	power_ratio: float
) -> void:
	if launch_velocity.length() <= 0.001:
		clear_aim_preview()
		return
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * GRAVITY_SCALE
	var horizontal := Vector3(launch_velocity.x, 0.0, launch_velocity.z)
	var horizontal_dir := horizontal.normalized() if horizontal.length() > 0.001 else Vector3.FORWARD
	var lateral_dir := Vector3(-horizontal_dir.z, 0.0, horizontal_dir.x) * signf(curve_amount)
	var curve_strength := absf(curve_amount)
	var max_heading := deg_to_rad(max_curve_heading_degrees) * curve_strength
	var color := _category_color(shot_category)

	for i in _aim_dots.size():
		var dot := _aim_dots[i]
		var t := 0.11 + float(i) * 0.115
		var position := origin + launch_velocity * t
		position.y -= 0.5 * gravity * t * t
		var curve_progress := clampf(t / maxf(curve_duration, 0.001), 0.0, 1.0)
		var lateral_distance := sin(max_heading) * horizontal.length() * t * 0.38 * curve_progress
		position += lateral_dir * lateral_distance
		if position.y < 0.08:
			dot.visible = false
			continue
		dot.visible = true
		dot.global_position = position
		dot.scale = Vector3.ONE * lerpf(0.18, 0.07, float(i) / float(MAX_AIM_DOTS))
		var material := _aim_materials[i]
		color.a = lerpf(0.86, 0.1, float(i) / float(MAX_AIM_DOTS))
		material.albedo_color = color
		material.emission = Color(color.r, color.g, color.b, 1.0) * 0.8

	if _shot_label:
		_shot_label.visible = true
		var curve_text := "Straight"
		if absf(curve_amount) >= 0.68:
			curve_text = "Extreme Curve"
		elif absf(curve_amount) >= 0.34:
			curve_text = "Strong Curve"
		elif absf(curve_amount) >= 0.08:
			curve_text = "Bend"
		_shot_label.text = "%s  %d%%  %s" % [
			shot_category.capitalize(),
			roundi(clampf(power_ratio, 0.0, 1.0) * 100.0),
			curve_text,
		]

	_apply_ball_anticipation(power_ratio)


func clear_aim_preview() -> void:
	for dot in _aim_dots:
		dot.visible = false
	if _shot_label:
		_shot_label.visible = false
	_reset_ball_visual_scale()


func on_aim_started() -> void:
	if _is_headless_run():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service:
		audio_service.call("play_sfx", "aim_start", 0.45)


func on_shot_fired(power_ratio: float, launch_velocity: Vector3, shot_category: String) -> void:
	clear_aim_preview()
	if _is_headless_run():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service:
		audio_service.call("play_shot", power_ratio)
	var haptics_service := get_node_or_null("/root/HapticsService")
	if haptics_service:
		haptics_service.call("emit_event", "strong_shot" if power_ratio >= 0.76 else "shot_release", lerpf(0.55, 1.0, power_ratio))
	if _camera_feedback:
		_camera_feedback.add_impulse("shot", lerpf(0.45, 1.0, power_ratio))
	_spawn_launch_ring(launch_velocity, shot_category)
	_play_release_scale()


func on_ball_impact(kind: String, strength: float) -> void:
	if _is_headless_run():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service:
		audio_service.call("play_impact", kind, strength)
	var haptics_service := get_node_or_null("/root/HapticsService")
	if haptics_service:
		haptics_service.call(
			"emit_event",
			"post_hit" if kind == "post" else "obstacle_impact",
			strength
		)
	if _camera_feedback:
		_camera_feedback.add_impulse("post" if kind == "post" else "impact", strength)


func on_near_miss() -> void:
	if _is_headless_run():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service:
		audio_service.call("play_sfx", "near_miss", 0.85)
	if _camera_feedback:
		_camera_feedback.add_impulse("post", 0.75)
	_show_near_miss_label()


func on_goal_scored() -> void:
	if _is_headless_run():
		return
	var audio_service := get_node_or_null("/root/AudioService")
	if audio_service:
		audio_service.call("play_sfx", "goal_scored", 1.0)
	var haptics_service := get_node_or_null("/root/HapticsService")
	if haptics_service:
		haptics_service.call("emit_event", "goal", 1.0)
	if _camera_feedback:
		_camera_feedback.add_impulse("goal", 1.0)


func get_camera_offset(delta: float) -> Vector3:
	return _camera_feedback.get_offset(delta) if _camera_feedback else Vector3.ZERO


func clear_all() -> void:
	clear_aim_preview()
	if _camera_feedback:
		_camera_feedback.clear()
	if _near_miss_label:
		_near_miss_label.visible = false
	for tween in _active_tweens:
		if tween:
			tween.kill()
	_active_tweens.clear()
	for child in get_children():
		if child.is_in_group(FEEDBACK_GROUP) and child != _camera_feedback:
			child.queue_free()


func _apply_settings() -> void:
	if _camera_feedback:
		_camera_feedback.configure(reduced_motion_enabled, camera_effects_intensity)


func _build_aim_dots() -> void:
	if not _aim_dots.is_empty():
		return
	for i in MAX_AIM_DOTS:
		var dot := MeshInstance3D.new()
		dot.name = "AimPreviewDot%02d" % i
		dot.top_level = true
		dot.visible = false
		var mesh := SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		dot.mesh = mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		dot.material_override = material
		add_child(dot)
		_aim_dots.append(dot)
		_aim_materials.append(material)


func _build_ui() -> void:
	if not _ui_root:
		return
	var layer := Control.new()
	layer.name = "PresentationOverlay"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(layer)

	_shot_label = Label.new()
	_shot_label.name = "ShotReadout"
	_shot_label.visible = false
	_shot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shot_label.add_theme_font_size_override("font_size", 22)
	_shot_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.48, 1.0))
	_shot_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_shot_label.offset_left = 0.0
	_shot_label.offset_top = -92.0
	_shot_label.offset_right = 0.0
	_shot_label.offset_bottom = -52.0
	layer.add_child(_shot_label)

	_near_miss_label = Label.new()
	_near_miss_label.name = "NearMissLabel"
	_near_miss_label.visible = false
	_near_miss_label.text = "SO CLOSE"
	_near_miss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_near_miss_label.add_theme_font_size_override("font_size", 34)
	_near_miss_label.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0, 1.0))
	_near_miss_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_near_miss_label.offset_left = -180.0
	_near_miss_label.offset_top = 104.0
	_near_miss_label.offset_right = 180.0
	_near_miss_label.offset_bottom = 154.0
	layer.add_child(_near_miss_label)


func _apply_ball_anticipation(power_ratio: float) -> void:
	if not _ball:
		return
	var scale_xz := 1.0 + (0.06 * clampf(power_ratio, 0.0, 1.0))
	var scale_y := 1.0 - (0.035 * clampf(power_ratio, 0.0, 1.0))
	_set_ball_visual_scale(Vector3(scale_xz, scale_y, scale_xz))


func _play_release_scale() -> void:
	if not _ball or reduced_motion_enabled:
		_reset_ball_visual_scale()
		return
	_set_ball_visual_scale(Vector3(0.92, 1.12, 0.92))
	var tween := create_tween()
	_active_tweens.append(tween)
	for mesh in _ball_visual_meshes():
		tween.parallel().tween_property(mesh, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _active_tweens.erase(tween))


func _reset_ball_visual_scale() -> void:
	_set_ball_visual_scale(Vector3.ONE)


func _set_ball_visual_scale(scale_value: Vector3) -> void:
	for mesh in _ball_visual_meshes():
		mesh.scale = scale_value


func _ball_visual_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if not _ball:
		return meshes
	for node_name in ["MeshInstance3D", "Band", "PatchFront", "PatchBack"]:
		var mesh := _ball.get_node_or_null(node_name) as MeshInstance3D
		if mesh:
			meshes.append(mesh)
	return meshes


func _spawn_launch_ring(launch_velocity: Vector3, shot_category: String) -> void:
	if not _ball:
		return
	var ring := MeshInstance3D.new()
	ring.name = "LaunchRing"
	ring.add_to_group(FEEDBACK_GROUP)
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.42
	mesh.outer_radius = 0.48
	mesh.ring_segments = 40
	mesh.rings = 6
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var color := _category_color(shot_category)
	color.a = 0.68
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	ring.material_override = material
	add_child(ring)
	ring.global_position = _ball.global_position
	var horizontal := Vector3(launch_velocity.x, 0.0, launch_velocity.z)
	if horizontal.length() > 0.001:
		ring.look_at(ring.global_position + horizontal.normalized(), Vector3.UP)
	ring.rotation_degrees.x += 90.0
	if reduced_motion_enabled:
		ring.queue_free()
		return
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 2.4, 0.22)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.chain().tween_callback(func() -> void:
		_active_tweens.erase(tween)
		ring.queue_free()
	)


func _show_near_miss_label() -> void:
	if not _near_miss_label:
		return
	_near_miss_label.visible = true
	_near_miss_label.modulate.a = 1.0
	if reduced_motion_enabled:
		return
	var tween := create_tween()
	_active_tweens.append(tween)
	tween.tween_property(_near_miss_label, "position:y", _near_miss_label.position.y - 8.0, 0.1)
	tween.tween_interval(0.35)
	tween.tween_property(_near_miss_label, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		_near_miss_label.visible = false
		_near_miss_label.position.y += 8.0
		_active_tweens.erase(tween)
	)


func _category_color(shot_category: String) -> Color:
	match shot_category:
		"GROUND":
			return Color(0.45, 1.0, 0.5, 1.0)
		"DRIVEN":
			return Color(1.0, 0.9, 0.2, 1.0)
		"AIR":
			return Color(0.25, 0.85, 1.0, 1.0)
		"LOB":
			return Color(0.96, 0.45, 1.0, 1.0)
		_:
			return Color(1.0, 0.9, 0.2, 1.0)


func _is_headless_run() -> bool:
	return DisplayServer.get_name() == "headless"
