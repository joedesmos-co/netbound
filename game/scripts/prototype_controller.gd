extends Node3D

const GameplayFeedbackScript := preload("res://scripts/presentation/gameplay_feedback_controller.gd")
const MOUSE_POINTER_ID: int = -2

@export var minimum_swipe_distance: float = 24.0
@export var maximum_swipe_distance: float = 320.0
@export var maximum_swipe_samples: int = 48
@export var max_swipe_screen_height_ratio: float = 0.32
@export var minimum_launch_speed: float = 5.0
@export var maximum_launch_speed: float = 25.0
@export var power_curve_exponent: float = 0.72
@export var minimum_elevation_degrees: float = 0.0
@export var driven_elevation_degrees: float = 6.5
@export var normal_air_elevation_degrees: float = 18.0
@export var maximum_elevation_degrees: float = 38.0
@export var upward_angle_deadzone: float = 0.08
@export var elevation_response_exponent: float = 1.15
@export var downward_ground_shot_threshold: float = 0.1
@export var ball_radius: float = 0.49
@export var ball_ground_clearance: float = 0.0
@export var launch_clearance_boost: float = 0.04
@export var ball_mass: float = 0.43
@export var linear_damping: float = 0.08
@export var angular_damping: float = 0.25
@export var ball_friction: float = 0.22
@export var ball_bounce: float = 0.28
@export var ground_friction: float = 0.28
@export var ground_bounce: float = 0.22
@export var ball_hit_radius: float = 90.0
@export var stopped_velocity_threshold: float = 0.08
@export var maximum_curve_amount: float = 1.0
@export var curve_duration: float = 1.35
@export var maximum_curve_heading_degrees: float = 78.0
@export var curve_heading_response_exponent: float = 1.0
@export var curve_minimum_horizontal_speed: float = 0.75
@export var curve_peak_threshold_px: float = 2.0
@export var curve_full_bend_ratio: float = 0.28
@export var curve_response_exponent: float = 0.7
@export var swipe_sample_smoothing: float = 0.45
@export var camera_position: Vector3 = Vector3(0.0, 6.5, 10.0)
@export var camera_look_at: Vector3 = Vector3(0.0, 0.65, -12.0)
@export var camera_setup_smoothing: float = 10.0
@export var camera_follow_smoothing: float = 5.5
@export var camera_follow_x_influence: float = 0.35
@export var camera_follow_z_influence: float = 0.18
@export var camera_follow_y_influence: float = 0.55
@export var camera_follow_max_x_offset: float = 5.0
@export var camera_follow_max_z_offset: float = 2.5
@export var camera_follow_max_y_offset: float = 7.0
@export var camera_follow_look_x_influence: float = 0.45
@export var camera_follow_look_z_influence: float = 0.25
@export var camera_follow_look_y_influence: float = 0.45
@export var camera_follow_max_look_y_offset: float = 6.0
@export var aim_arrow_min_length: float = 1.2
@export var aim_arrow_max_length: float = 5.0
@export var aim_guide_height_offset: float = 0.08
@export var developer_debug_enabled: bool = false

@onready var ball_spawn: Marker3D = $BallSpawn
@onready var ball: RigidBody3D = $Ball
@onready var ground: StaticBody3D = $Ground
@onready var camera: Camera3D = $Camera3D
@onready var aim_guide: Node3D = $AimGuide
@onready var aim_shaft: MeshInstance3D = $AimGuide/Shaft
@onready var aim_head: MeshInstance3D = $AimGuide/Head
@onready var reset_button: Button = $UI/TopLeftUI/ResetButton
@onready var top_left_ui: Control = $UI/TopLeftUI
@onready var top_bar: Control = get_node_or_null("UI/TopBar") as Control
@onready var reset_ok_label: Label = $UI/TopLeftUI/ResetOkLabel
@onready var instruction_label: Label = $UI/TopLeftUI/InstructionLabel
@onready var power_label: Label = $UI/TopLeftUI/PowerLabel
@onready var direction_label: Label = $UI/TopLeftUI/DirectionLabel
@onready var curve_label: Label = $UI/TopLeftUI/CurveLabel
@onready var shot_debug_label: Label = $UI/TopLeftUI/ShotDebugLabel
@onready var loft_category_label: Label = $UI/TopLeftUI/LoftCategoryLabel
@onready var power_bar: ProgressBar = $UI/PowerBarContainer/PowerBar
@onready var power_bar_container: Control = $UI/PowerBarContainer
@onready var swipe_overlay: SwipeOverlay = $UI/SwipeOverlay

var spawn_transform: Transform3D
var effective_max_swipe_distance: float = 320.0
var reset_count: int = 0
var reset_in_progress: bool = false
var reset_generation: int = 0
var is_swiping: bool = false
var is_swipe_valid: bool = false
var has_successful_shot: bool = false
var camera_follow_shot: bool = false
var active_pointer_id: int = -1
var swipe_screen_points: PackedVector2Array = PackedVector2Array()
var current_launch_speed: float = 0.0
var current_shot_direction: Vector3 = Vector3.ZERO
var current_shot_direction_screen: Vector2 = Vector2.ZERO
var current_power_ratio: float = 0.0
var current_loft_intent: float = 0.0
var current_ground_intent: float = 0.0
var current_elevation_intent: float = 0.0
var current_elevation_degrees: float = 0.0
var current_shot_category: String = "DRIVEN"
var current_overall_screen_dir: Vector2 = Vector2.ZERO
var current_curve_amount: float = 0.0
var curve_time_remaining: float = 0.0
var active_curve_sign: float = 0.0
var active_curve_amount: float = 0.0
var active_curve_total_heading_radians: float = 0.0
var active_curve_remaining_heading_radians: float = 0.0
var active_curve_original_horizontal_direction: Vector3 = Vector3.ZERO
var tracking_shot_peak: bool = false
var shot_peak_y: float = 0.0
var last_horizontal_launch_speed: float = 0.0
var last_vertical_launch_speed: float = 0.0
var last_loft_intent: float = 0.0
var last_ground_intent: float = 0.0
var last_elevation_intent: float = 0.0
var last_elevation_degrees: float = 0.0
var last_shot_category: String = "DRIVEN"
var last_launch_direction: Vector3 = Vector3.ZERO
var last_launch_velocity: Vector3 = Vector3.ZERO
var last_curve_heading_degrees: float = 0.0
var last_post_shot_y_velocity: float = 0.0
var gameplay_feedback
var last_camera_feedback_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	_apply_ui_art_direction()
	_setup_camera()
	_configure_ball_spawn_height()
	_configure_swipe_distance()
	get_viewport().size_changed.connect(_configure_swipe_distance)
	_apply_ball_tuning()
	_setup_gameplay_feedback()
	_update_instruction_visibility()
	_update_debug_ui()
	_clear_swipe_visuals()
	await _apply_physics_safe_reset()
	_debug_log("INIT ball=%s" % ball.global_position)


func _apply_ui_art_direction() -> void:
	var ui_theme := NetboundUITheme.get_theme()
	if top_bar:
		top_bar.theme = ui_theme
		top_bar.theme_type_variation = "HudBadge"
		var shots := top_bar.get_node_or_null("ShotsLabel") as Label
		if shots:
			shots.label_settings = null
			shots.theme_type_variation = "NumericLabel"
			shots.add_theme_font_size_override("font_size", 22)
			shots.add_theme_color_override("font_color", NetboundUITheme.SIGNAL)
	if top_left_ui:
		top_left_ui.theme = ui_theme
		var instruction_kicker := top_left_ui.get_node_or_null("InstructionKicker") as Label
		if instruction_kicker:
			instruction_kicker.theme_type_variation = "SectionLabel"
	if reset_button:
		reset_button.theme_type_variation = "HudButton"
		reset_button.custom_minimum_size = Vector2(156.0, 48.0)
	if instruction_label:
		instruction_label.label_settings = null
		instruction_label.theme_type_variation = "BodyLabel"
		instruction_label.add_theme_font_size_override("font_size", 17)
		instruction_label.add_theme_color_override("font_outline_color", Color(NetboundUITheme.INK, 0.94))
		instruction_label.add_theme_constant_override("outline_size", 3)
	if power_bar_container:
		power_bar_container.theme = ui_theme
	if power_bar:
		power_bar.theme = ui_theme


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and is_swiping and active_pointer_id == MOUSE_POINTER_ID:
		_cancel_swipe()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_active_gesture_for_lifecycle()


func _physics_process(delta: float) -> void:
	if tracking_shot_peak:
		shot_peak_y = maxf(shot_peak_y, ball.global_position.y)
		if _is_ball_stopped():
			tracking_shot_peak = false
			_debug_log("PEAK ball_y=%s" % shot_peak_y)
			_update_debug_ui()

	_apply_arcade_curve(delta)
	_update_camera(delta)


func _apply_arcade_curve(delta: float) -> void:
	if curve_time_remaining <= 0.0 or absf(active_curve_remaining_heading_radians) <= 0.0001:
		return

	curve_time_remaining = maxf(curve_time_remaining - delta, 0.0)
	var velocity := ball.linear_velocity
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	if horizontal_speed <= curve_minimum_horizontal_speed:
		return

	var step_limit := (
		absf(active_curve_total_heading_radians)
		/ maxf(curve_duration, 0.001)
		* delta
	)
	var signed_step := active_curve_sign * minf(
		absf(active_curve_remaining_heading_radians),
		step_limit
	)
	var rotated_horizontal := horizontal_velocity.rotated(Vector3.UP, signed_step)
	var total_heading_after_step := _signed_horizontal_angle(
		active_curve_original_horizontal_direction,
		rotated_horizontal.normalized()
	)
	var heading_cap := deg_to_rad(maximum_curve_heading_degrees)
	if absf(total_heading_after_step) > heading_cap:
		rotated_horizontal = (
			active_curve_original_horizontal_direction.rotated(
				Vector3.UP,
				signf(total_heading_after_step) * heading_cap
			)
			* horizontal_speed
		)
		active_curve_remaining_heading_radians = 0.0
	else:
		active_curve_remaining_heading_radians -= signed_step

	ball.linear_velocity = Vector3(rotated_horizontal.x, velocity.y, rotated_horizontal.z)


func _setup_camera() -> void:
	camera.global_position = camera_position
	camera.look_at(camera_look_at, Vector3.UP)
	camera.current = true


func _update_camera(delta: float) -> void:
	if last_camera_feedback_offset != Vector3.ZERO:
		camera.global_position -= last_camera_feedback_offset
		last_camera_feedback_offset = Vector3.ZERO

	var desired_position := camera_position
	var desired_look_at := camera_look_at
	var smoothing := camera_setup_smoothing

	if camera_follow_shot:
		var ball_position := ball.global_position
		var height_above_field := maxf(ball_position.y - ball_radius, 0.0)
		desired_position += Vector3(
			clampf(
				ball_position.x * camera_follow_x_influence,
				-camera_follow_max_x_offset,
				camera_follow_max_x_offset
			),
			clampf(
				height_above_field * camera_follow_y_influence,
				0.0,
				camera_follow_max_y_offset
			),
			clampf(
				ball_position.z * camera_follow_z_influence,
				-camera_follow_max_z_offset,
				camera_follow_max_z_offset
			)
		)
		desired_look_at += Vector3(
			clampf(
				ball_position.x * camera_follow_look_x_influence,
				-camera_follow_max_x_offset,
				camera_follow_max_x_offset
			),
			clampf(
				height_above_field * camera_follow_look_y_influence,
				0.0,
				camera_follow_max_look_y_offset
			),
			clampf(
				ball_position.z * camera_follow_look_z_influence,
				-camera_follow_max_z_offset,
				camera_follow_max_z_offset
			)
		)
		smoothing = camera_follow_smoothing

	var blend := 1.0 - exp(-maxf(smoothing, 0.001) * delta)
	camera.global_position = camera.global_position.lerp(desired_position, blend)
	if gameplay_feedback:
		last_camera_feedback_offset = gameplay_feedback.get_camera_offset(delta)
		camera.global_position += last_camera_feedback_offset
	camera.look_at(desired_look_at, Vector3.UP)


func _set_camera_following_shot(enabled: bool) -> void:
	camera_follow_shot = enabled


func _configure_ball_spawn_height() -> void:
	var spawn_y := ball_radius + ball_ground_clearance
	ball_spawn.position = Vector3(0.0, spawn_y, 0.0)
	spawn_transform = ball_spawn.global_transform


func _configure_swipe_distance() -> void:
	var viewport_height := get_viewport().get_visible_rect().size.y
	effective_max_swipe_distance = minf(
		maximum_swipe_distance,
		viewport_height * max_swipe_screen_height_ratio
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse_button.pressed:
			_begin_swipe(mouse_button.position, MOUSE_POINTER_ID)
		else:
			_end_swipe(mouse_button.position, MOUSE_POINTER_ID)

	elif event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if is_swiping and active_pointer_id == MOUSE_POINTER_ID:
			_update_swipe(mouse_motion.position)
			get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		var screen_touch := event as InputEventScreenTouch
		if screen_touch.canceled:
			if is_swiping and active_pointer_id == screen_touch.index:
				_cancel_swipe()
				get_viewport().set_input_as_handled()
		elif screen_touch.pressed:
			_begin_swipe(screen_touch.position, screen_touch.index)
		else:
			_end_swipe(screen_touch.position, screen_touch.index)

	elif event is InputEventScreenDrag:
		var screen_drag := event as InputEventScreenDrag
		if is_swiping and active_pointer_id == screen_drag.index:
			_update_swipe(screen_drag.position)
			get_viewport().set_input_as_handled()


func _on_reset_button_pressed() -> void:
	if reset_in_progress or not is_gameplay_input_allowed():
		return

	_debug_log("_on_reset_button_pressed called")
	var before := ball.global_position
	reset_count += 1
	reset_ok_label.text = "RESET OK #%d" % reset_count
	reset_ok_label.visible = developer_debug_enabled
	var token := reset_generation + 1
	get_tree().create_timer(1.0).timeout.connect(_hide_reset_ok_label.bind(token))
	await _run_reset(before)


func _hide_reset_ok_label(token: int = -1) -> void:
	if token != -1 and token != reset_generation:
		return
	reset_ok_label.visible = false


func _run_reset(before_position: Vector3) -> void:
	reset_in_progress = true
	_clear_swipe()
	tracking_shot_peak = false
	shot_peak_y = 0.0
	_clear_active_curve()
	has_successful_shot = false

	await _apply_physics_safe_reset()

	_debug_log("RESET before=%s after=%s" % [before_position, ball.global_position])
	await get_tree().physics_frame
	_debug_log("RESET frame+1 pos=%s vel=%s" % [ball.global_position, ball.linear_velocity])

	reset_in_progress = false
	_set_camera_following_shot(false)
	_update_instruction_visibility()
	_update_debug_ui()


func _apply_physics_safe_reset() -> void:
	reset_generation += 1
	var token := reset_generation
	spawn_transform = ball_spawn.global_transform

	_set_camera_following_shot(false)
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.constant_force = Vector3.ZERO
	ball.constant_torque = Vector3.ZERO
	ball.global_transform = spawn_transform

	await get_tree().physics_frame
	if token != reset_generation:
		# A newer reset owns the body. Do not leave this path half-finished if we are
		# still the latest owner of freeze_state via a lost race; the newer reset will
		# unfreeze when it completes.
		return

	ball.global_transform = spawn_transform
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.reset_physics_interpolation()
	ball.freeze = false
	ball.sleeping = true
	_apply_ball_tuning()
	if gameplay_feedback:
		gameplay_feedback.clear_all()
	last_camera_feedback_offset = Vector3.ZERO


func _ensure_ball_ready_for_play() -> void:
	reset_in_progress = false
	ball.freeze = false
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.sleeping = true


func is_gameplay_input_allowed() -> bool:
	return true


func _begin_swipe(screen_position: Vector2, pointer_id: int) -> void:
	if not is_gameplay_input_allowed():
		return
	if is_swiping or reset_in_progress or not _is_ball_stopped() or not _is_screen_position_in_viewport(screen_position):
		return

	if _is_screen_position_over_gameplay_ui(screen_position):
		return

	if not _is_screen_position_on_ball(screen_position):
		return

	active_pointer_id = pointer_id
	is_swiping = true
	swipe_screen_points = PackedVector2Array([screen_position])
	if gameplay_feedback:
		gameplay_feedback.on_aim_started()
	_update_swipe(screen_position)
	get_viewport().set_input_as_handled()


func _update_swipe(screen_position: Vector2) -> void:
	_add_swipe_sample(screen_position)
	_recalculate_swipe_state()
	_update_swipe_visuals()
	_update_aim_guide()
	_update_debug_ui()


func _end_swipe(screen_position: Vector2, pointer_id: int) -> void:
	if not is_swiping or active_pointer_id != pointer_id:
		return

	_debug_log("RELEASE_RECEIVED pointer=%d pos=%s" % [pointer_id, screen_position])

	if not _is_screen_position_in_viewport(screen_position):
		_debug_log("RELEASE rejected reason=outside_viewport")
		_cancel_swipe()
		return

	_commit_swipe_release_sample(screen_position)
	_recalculate_swipe_state()
	_update_swipe_visuals()
	_update_aim_guide()
	_update_debug_ui()

	var swipe_distance := 0.0
	if swipe_screen_points.size() >= 2:
		swipe_distance = swipe_screen_points[0].distance_to(swipe_screen_points[-1])

	var invalid_reason := "ok"
	if not is_swipe_valid:
		if swipe_screen_points.size() < 2:
			invalid_reason = "too_few_samples"
		elif swipe_distance < minimum_swipe_distance:
			invalid_reason = "too_short"
		elif current_shot_direction.length() <= 0.001:
			invalid_reason = "no_world_direction"
		else:
			invalid_reason = "unknown"

	_debug_log(
		"RELEASE_RECEIVED samples=%d distance=%.2f valid=%s reason=%s power_ratio=%.2f category=%s elev_deg=%.2f elev_intent=%.2f curve=%.2f reset_in_progress=%s freeze=%s sleeping=%s" % [
			swipe_screen_points.size(),
			swipe_distance,
			is_swipe_valid,
			invalid_reason,
			current_power_ratio,
			current_shot_category,
			current_elevation_degrees,
			current_elevation_intent,
			current_curve_amount,
			reset_in_progress,
			ball.freeze,
			ball.sleeping,
		]
	)

	if is_swipe_valid:
		_fire_shot()
	else:
		_debug_log("RELEASE rejected reason=%s" % invalid_reason)
		_clear_swipe()

	_update_debug_ui()
	get_viewport().set_input_as_handled()


func _commit_swipe_release_sample(screen_position: Vector2) -> void:
	if swipe_screen_points.is_empty():
		swipe_screen_points.append(screen_position)
		return
	if swipe_screen_points[-1].distance_to(screen_position) > 0.25:
		swipe_screen_points.append(screen_position)
		_trim_swipe_samples_to_limit()


func _fire_shot() -> bool:
	var launch_velocity := _compute_launch_velocity(
		current_power_ratio,
		current_shot_direction,
		swipe_screen_points
	)
	if launch_velocity.length() <= 0.001:
		return false

	# Abort any in-flight reset ownership of the body for this launch.
	if reset_in_progress:
		_debug_log("RELEASE_FIRE forcing reset_in_progress clear before launch")
		reset_in_progress = false

	var curve_sign := signf(current_curve_amount)
	var curve_amount := clampf(absf(current_curve_amount), 0.0, maximum_curve_amount)
	var shot_token := reset_generation

	_debug_log(
		"RELEASE_FIRE launch_velocity=%s speed=%.2f freeze_before=%s sleeping_before=%s reset_in_progress=%s generation=%d" % [
			launch_velocity,
			launch_velocity.length(),
			ball.freeze,
			ball.sleeping,
			reset_in_progress,
			shot_token,
		]
	)

	# Reliable arcade launch: unfreeze first, then assign the canonical velocity.
	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position.y = maxf(
		ball.global_position.y,
		ball_radius + ball_ground_clearance + launch_clearance_boost
	)
	ball.linear_velocity = launch_velocity
	last_post_shot_y_velocity = launch_velocity.y
	if gameplay_feedback:
		gameplay_feedback.on_shot_fired(current_power_ratio, launch_velocity, current_shot_category)
	_debug_log(
		"RELEASE_FIRE vel_set=%s pos_y=%.2f freeze_after=%s sleeping_after=%s" % [
			ball.linear_velocity,
			ball.global_position.y,
			ball.freeze,
			ball.sleeping,
		]
	)
	_validate_launch_next_frame(shot_token, launch_velocity)

	tracking_shot_peak = true
	shot_peak_y = ball.global_position.y
	_set_camera_following_shot(true)

	if curve_amount > 0.02:
		_begin_bounded_curve(curve_sign, curve_amount, launch_velocity)
	else:
		_clear_active_curve()

	has_successful_shot = true
	_clear_swipe()
	_update_instruction_visibility()
	_update_debug_ui()
	return true


func _validate_launch_next_frame(
	shot_token: int,
	expected_launch_velocity: Vector3
) -> void:
	await get_tree().physics_frame

	if shot_token != reset_generation:
		_debug_log(
			"LAUNCH_CHECK skipped reset_generation changed %d -> %d" % [
				shot_token,
				reset_generation,
			]
		)
		return

	var vel_before := ball.linear_velocity
	_debug_log(
		"LAUNCH_CHECK frame+1 vel=%s freeze=%s contacts=%d" % [
			vel_before,
			ball.freeze,
			ball.get_contact_count() if ball.has_method("get_contact_count") else -1,
		]
	)

	if ball.freeze:
		ball.freeze = false
		ball.sleeping = false
		ball.linear_velocity = expected_launch_velocity
		_debug_log("LAUNCH_CHECK unfroze_and_restored vel=%s" % ball.linear_velocity)


func _begin_bounded_curve(curve_sign: float, curve_amount: float, launch_velocity: Vector3) -> void:
	var horizontal_velocity := Vector3(launch_velocity.x, 0.0, launch_velocity.z)
	if horizontal_velocity.length() <= curve_minimum_horizontal_speed:
		_clear_active_curve()
		return

	var normalized_amount := clampf(
		curve_amount / maxf(maximum_curve_amount, 0.001),
		0.0,
		1.0
	)
	var heading_degrees := maximum_curve_heading_degrees * pow(
		normalized_amount,
		curve_heading_response_exponent
	)
	active_curve_sign = signf(curve_sign)
	active_curve_amount = normalized_amount
	active_curve_total_heading_radians = deg_to_rad(heading_degrees) * active_curve_sign
	active_curve_remaining_heading_radians = active_curve_total_heading_radians
	active_curve_original_horizontal_direction = horizontal_velocity.normalized()
	curve_time_remaining = curve_duration
	last_curve_heading_degrees = heading_degrees


func _clear_active_curve() -> void:
	curve_time_remaining = 0.0
	active_curve_sign = 0.0
	active_curve_amount = 0.0
	active_curve_total_heading_radians = 0.0
	active_curve_remaining_heading_radians = 0.0
	active_curve_original_horizontal_direction = Vector3.ZERO
	last_curve_heading_degrees = 0.0


func _signed_horizontal_angle(from_direction: Vector3, to_direction: Vector3) -> float:
	var from_flat := Vector3(from_direction.x, 0.0, from_direction.z)
	var to_flat := Vector3(to_direction.x, 0.0, to_direction.z)
	if from_flat.length() <= 0.001 or to_flat.length() <= 0.001:
		return 0.0
	from_flat = from_flat.normalized()
	to_flat = to_flat.normalized()
	var unsigned := acos(clampf(from_flat.dot(to_flat), -1.0, 1.0))
	var sign_value := signf(from_flat.cross(to_flat).y)
	return unsigned * sign_value


func _compute_launch_velocity(
	power_ratio: float,
	horizontal_direction: Vector3,
	swipe_samples: PackedVector2Array
) -> Vector3:
	var normalized_power := clampf(power_ratio, 0.0, 1.0)
	var launch_speed := lerpf(minimum_launch_speed, maximum_launch_speed, normalized_power)
	_analyze_elevation_from_samples(swipe_samples)

	last_loft_intent = current_loft_intent
	last_ground_intent = current_ground_intent
	last_elevation_intent = current_elevation_intent
	last_elevation_degrees = current_elevation_degrees
	last_shot_category = current_shot_category

	var horizontal_dir := horizontal_direction.normalized()
	if horizontal_dir.length() <= 0.001:
		horizontal_dir = Vector3(0.0, 0.0, -1.0)

	var elevation_rad := deg_to_rad(current_elevation_degrees)
	var launch_dir := (
		horizontal_dir * cos(elevation_rad) + Vector3.UP * sin(elevation_rad)
	).normalized()
	last_launch_direction = launch_dir
	last_horizontal_launch_speed = launch_speed * cos(elevation_rad)
	last_vertical_launch_speed = launch_speed * sin(elevation_rad)
	last_launch_velocity = launch_dir * launch_speed
	return last_launch_velocity


func _analyze_elevation_from_samples(samples: PackedVector2Array) -> void:
	current_loft_intent = 0.0
	current_ground_intent = 0.0
	current_elevation_intent = 0.0
	current_elevation_degrees = driven_elevation_degrees
	current_overall_screen_dir = Vector2.ZERO
	current_shot_category = "DRIVEN"

	if samples.size() < 2:
		return

	var overall_delta := samples[-1] - samples[0]
	if overall_delta.length() <= 0.001:
		return

	current_overall_screen_dir = overall_delta.normalized()
	# Screen Y increases downward; negative Y is upward toward the goal.
	var upward_component := -current_overall_screen_dir.y
	_apply_elevation_from_upward_component(upward_component)


func _analyze_elevation_from_screen_delta(screen_delta: Vector2) -> void:
	current_loft_intent = 0.0
	current_ground_intent = 0.0
	current_elevation_intent = 0.0
	current_elevation_degrees = driven_elevation_degrees
	current_overall_screen_dir = Vector2.ZERO
	current_shot_category = "DRIVEN"
	if screen_delta.length() <= 0.001:
		return
	current_overall_screen_dir = screen_delta.normalized()
	_apply_elevation_from_upward_component(-current_overall_screen_dir.y)


func _apply_elevation_from_upward_component(upward_component: float) -> void:
	if upward_component <= -downward_ground_shot_threshold:
		current_ground_intent = clampf(
			inverse_lerp(0.0, -1.0, upward_component),
			0.0,
			1.0
		)
		current_elevation_intent = 0.0
		current_loft_intent = 0.0
		current_elevation_degrees = minimum_elevation_degrees
		current_shot_category = "GROUND"
		return

	if upward_component < upward_angle_deadzone:
		var driven_blend := clampf(
			inverse_lerp(-downward_ground_shot_threshold, upward_angle_deadzone, upward_component),
			0.0,
			1.0
		)
		current_elevation_intent = driven_blend * 0.2
		current_loft_intent = current_elevation_intent
		current_ground_intent = 1.0 - driven_blend
		current_elevation_degrees = lerpf(
			minimum_elevation_degrees,
			driven_elevation_degrees,
			driven_blend
		)
		current_shot_category = "GROUND" if driven_blend < 0.45 else "DRIVEN"
		return

	current_elevation_intent = clampf(
		inverse_lerp(upward_angle_deadzone, 1.0, upward_component),
		0.0,
		1.0
	)
	current_elevation_intent = pow(current_elevation_intent, elevation_response_exponent)
	current_loft_intent = current_elevation_intent
	current_ground_intent = 0.0

	var normal_air_intent := 0.55
	if current_elevation_intent <= normal_air_intent:
		var air_blend := current_elevation_intent / normal_air_intent
		current_elevation_degrees = lerpf(
			driven_elevation_degrees,
			normal_air_elevation_degrees,
			air_blend
		)
	else:
		var lob_blend := inverse_lerp(normal_air_intent, 1.0, current_elevation_intent)
		current_elevation_degrees = lerpf(
			normal_air_elevation_degrees,
			maximum_elevation_degrees,
			lob_blend
		)

	if current_elevation_degrees >= lerpf(normal_air_elevation_degrees, maximum_elevation_degrees, 0.55):
		current_shot_category = "LOB"
	elif current_elevation_degrees >= lerpf(driven_elevation_degrees, normal_air_elevation_degrees, 0.35):
		current_shot_category = "AIR"
	else:
		current_shot_category = "DRIVEN"


func _cancel_swipe() -> void:
	_clear_swipe()
	_update_debug_ui()


func cancel_active_gesture_for_lifecycle() -> void:
	if is_swiping:
		_cancel_swipe()


func _clear_swipe() -> void:
	is_swiping = false
	is_swipe_valid = false
	active_pointer_id = -1
	swipe_screen_points = PackedVector2Array()
	current_launch_speed = 0.0
	current_shot_direction = Vector3.ZERO
	current_shot_direction_screen = Vector2.ZERO
	current_power_ratio = 0.0
	current_loft_intent = 0.0
	current_ground_intent = 0.0
	current_elevation_intent = 0.0
	current_elevation_degrees = driven_elevation_degrees
	current_shot_category = "DRIVEN"
	current_overall_screen_dir = Vector2.ZERO
	current_curve_amount = 0.0
	_clear_swipe_visuals()
	_hide_aim_guide()
	if gameplay_feedback:
		gameplay_feedback.clear_aim_preview()


func _add_swipe_sample(screen_position: Vector2) -> void:
	if swipe_screen_points.is_empty():
		swipe_screen_points.append(screen_position)
		return

	var last_point := swipe_screen_points[-1]
	var smoothed := last_point.lerp(screen_position, swipe_sample_smoothing)
	if smoothed.distance_to(last_point) >= 2.0:
		swipe_screen_points.append(smoothed)
		_trim_swipe_samples_to_limit()


func _trim_swipe_samples_to_limit() -> void:
	var sample_limit := maxi(maximum_swipe_samples, 2)
	while swipe_screen_points.size() > sample_limit:
		swipe_screen_points.remove_at(1)


func _recalculate_swipe_state() -> void:
	if swipe_screen_points.size() < 2:
		is_swipe_valid = false
		_reset_aim_state()
		return

	var swipe_start := swipe_screen_points[0]
	var swipe_end := swipe_screen_points[-1]
	var screen_delta := swipe_end - swipe_start
	var swipe_distance := screen_delta.length()
	is_swipe_valid = swipe_distance >= minimum_swipe_distance

	if not is_swipe_valid:
		_reset_aim_state()
		return

	var world_direction := _screen_swipe_to_world_direction(swipe_start, swipe_end)
	if world_direction.length() <= 0.001:
		is_swipe_valid = false
		_reset_aim_state()
		return

	current_power_ratio = pow(
		clampf(swipe_distance / maxf(effective_max_swipe_distance, 1.0), 0.0, 1.0),
		power_curve_exponent
	)
	current_launch_speed = lerpf(minimum_launch_speed, maximum_launch_speed, current_power_ratio)
	current_shot_direction = world_direction
	current_shot_direction_screen = screen_delta.normalized()
	_analyze_elevation_from_screen_delta(screen_delta)
	current_curve_amount = _calculate_curve_amount(swipe_start, swipe_end)


func _reset_aim_state() -> void:
	current_launch_speed = 0.0
	current_shot_direction = Vector3.ZERO
	current_shot_direction_screen = Vector2.ZERO
	current_power_ratio = 0.0
	current_loft_intent = 0.0
	current_ground_intent = 0.0
	current_elevation_intent = 0.0
	current_elevation_degrees = driven_elevation_degrees
	current_shot_category = "DRIVEN"
	current_overall_screen_dir = Vector2.ZERO
	current_curve_amount = 0.0


func _screen_swipe_to_world_direction(swipe_start: Vector2, swipe_end: Vector2) -> Vector3:
	var screen_delta := swipe_end - swipe_start
	if screen_delta.length() <= 0.001:
		return Vector3.ZERO

	var camera_basis := camera.global_transform.basis
	var world_right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z)
	var world_forward := Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z)

	if world_right.length() <= 0.001 or world_forward.length() <= 0.001:
		return Vector3.ZERO

	world_right = world_right.normalized()
	world_forward = world_forward.normalized()

	var world_direction := (world_right * screen_delta.x) + (world_forward * -screen_delta.y)
	world_direction.y = 0.0
	if world_direction.length() <= 0.001:
		return Vector3.ZERO

	return world_direction.normalized()


func _calculate_curve_amount(swipe_start: Vector2, swipe_end: Vector2) -> float:
	if swipe_screen_points.size() < 3:
		return 0.0

	var swipe_vector := swipe_end - swipe_start
	var swipe_length := swipe_vector.length()
	if swipe_length <= minimum_swipe_distance:
		return 0.0

	var swipe_direction := swipe_vector / swipe_length
	var swipe_perpendicular := Vector2(-swipe_direction.y, swipe_direction.x)
	var total_lateral := 0.0
	var peak_lateral := 0.0

	for point in swipe_screen_points:
		var relative := point - swipe_start
		var lateral := relative.dot(swipe_perpendicular)
		total_lateral += lateral
		peak_lateral = maxf(peak_lateral, absf(lateral))

	if peak_lateral <= curve_peak_threshold_px:
		return 0.0

	var signed_curve := signf(total_lateral) if absf(total_lateral) > 1.0 else 0.0
	var strength_ratio := clampf(
		peak_lateral / maxf(swipe_length * curve_full_bend_ratio, 1.0),
		0.0,
		1.0
	)
	strength_ratio = pow(strength_ratio, curve_response_exponent)
	return signed_curve * strength_ratio * maximum_curve_amount


func _update_swipe_visuals() -> void:
	if not is_swiping:
		swipe_overlay.clear_visuals()
		return

	var ball_screen := camera.unproject_position(ball.global_position)
	var arrow_pixels := current_shot_direction_screen * lerpf(80.0, 220.0, current_power_ratio)
	if not is_swipe_valid:
		arrow_pixels = Vector2.ZERO

	swipe_overlay.set_swipe_visuals(
			swipe_screen_points,
			ball_screen,
			arrow_pixels,
			signf(current_curve_amount),
			clampf(absf(current_curve_amount), 0.0, maximum_curve_amount),
			true
	)
	_update_presentation_aim_preview()


func _clear_swipe_visuals() -> void:
	swipe_overlay.clear_visuals()


func _update_aim_guide() -> void:
	if not developer_debug_enabled or not is_swiping or not is_swipe_valid:
		_hide_aim_guide()
		return

	var guide_origin := ball.global_position + (Vector3.UP * aim_guide_height_offset)
	var arrow_length := lerpf(aim_arrow_min_length, aim_arrow_max_length, current_power_ratio)
	var shaft_length := maxf(arrow_length - 0.45, 0.35)
	var thickness_scale := lerpf(0.85, 1.6, current_power_ratio)
	var elevation_rad := deg_to_rad(current_elevation_degrees)
	var horizontal_dir := current_shot_direction.normalized()
	if horizontal_dir.length() <= 0.001:
		_hide_aim_guide()
		return
	var launch_dir := (
		horizontal_dir * cos(elevation_rad) + Vector3.UP * sin(elevation_rad)
	).normalized()
	var guide_up := Vector3.UP
	if absf(launch_dir.dot(Vector3.UP)) > 0.98:
		guide_up = Vector3.FORWARD

	aim_guide.visible = true
	aim_guide.global_position = guide_origin
	aim_guide.global_basis = Basis.looking_at(launch_dir, guide_up)
	aim_shaft.scale = Vector3(thickness_scale, thickness_scale, shaft_length)
	aim_shaft.position = Vector3(0.0, 0.0, -shaft_length * 0.5)
	aim_head.position = Vector3(0.0, 0.0, -shaft_length - 0.22)


func _hide_aim_guide() -> void:
	aim_guide.visible = false


func _setup_gameplay_feedback() -> void:
	if gameplay_feedback:
		return
	gameplay_feedback = GameplayFeedbackScript.new()
	gameplay_feedback.name = "GameplayFeedback"
	add_child(gameplay_feedback)
	gameplay_feedback.setup(ball, get_node_or_null("UI"))
	_apply_presentation_settings()
	if not ball.body_entered.is_connected(_on_ball_body_entered):
		ball.body_entered.connect(_on_ball_body_entered)


func _apply_presentation_settings() -> void:
	if not gameplay_feedback:
		return
	var service := get_node_or_null("/root/SaveService")
	if service:
		gameplay_feedback.configure_from_save(service)


func _update_presentation_aim_preview() -> void:
	if not developer_debug_enabled:
		if gameplay_feedback:
			gameplay_feedback.clear_aim_preview()
		return
	if not gameplay_feedback or not is_swiping or not is_swipe_valid:
		return
	var launch_velocity := _current_preview_launch_velocity()
	gameplay_feedback.show_aim_preview(
		ball.global_position + Vector3.UP * aim_guide_height_offset,
		launch_velocity,
		current_curve_amount,
		maximum_curve_heading_degrees,
		curve_duration,
		current_shot_category,
		current_power_ratio
	)


func _current_preview_launch_velocity() -> Vector3:
	var horizontal_dir := current_shot_direction.normalized()
	if horizontal_dir.length() <= 0.001:
		return Vector3.ZERO
	var elevation_rad := deg_to_rad(current_elevation_degrees)
	var launch_dir := (
		horizontal_dir * cos(elevation_rad) + Vector3.UP * sin(elevation_rad)
	).normalized()
	return launch_dir * current_launch_speed


func _on_ball_body_entered(body: Node) -> void:
	if not gameplay_feedback or not body:
		return
	var speed := ball.linear_velocity.length()
	if speed < 1.2:
		return
	var kind := _impact_kind_for_body(body)
	var strength := clampf(speed / maxf(maximum_launch_speed, 0.001), 0.25, 1.0)
	_present_ball_impact(kind, strength, body)


func _present_ball_impact(kind: String, strength: float, _body: Node) -> void:
	if gameplay_feedback:
		gameplay_feedback.on_ball_impact(kind, strength)


func _impact_kind_for_body(body: Node) -> String:
	var body_name := body.name.to_lower()
	var parent_name := body.get_parent().name.to_lower() if body.get_parent() else ""
	if body == ground or body_name.contains("ground"):
		return "ground"
	if body_name.contains("post") or body_name.contains("crossbar") or parent_name.contains("post"):
		return "post"
	if body_name.contains("bounce") or parent_name.contains("bounce"):
		return "bounce"
	return "obstacle"


func _is_ball_stopped() -> bool:
	return (
		ball.linear_velocity.length() <= stopped_velocity_threshold
		and ball.angular_velocity.length() <= stopped_velocity_threshold
	)


func _is_screen_position_in_viewport(screen_position: Vector2) -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return viewport_rect.has_point(screen_position)


func _is_screen_position_over_gameplay_ui(screen_position: Vector2) -> bool:
	var ui_root := get_node_or_null("UI")
	if not ui_root:
		return false
	for node in ui_root.find_children("*", "Button", true, false):
		var button := node as Button
		if button and button.is_visible_in_tree() and button.get_global_rect().has_point(screen_position):
			return true
	return false


func _is_screen_position_on_ball(screen_position: Vector2) -> bool:
	var ball_screen_position := camera.unproject_position(ball.global_position)
	return screen_position.distance_to(ball_screen_position) <= ball_hit_radius


func apply_safe_area_margins(margins: Dictionary) -> void:
	var left := float(margins.get("left", 16.0))
	var top := float(margins.get("top", 16.0))
	var right := float(margins.get("right", 16.0))
	var bottom := float(margins.get("bottom", 16.0))
	if top_bar:
		top_bar.offset_top = top + 8.0
		top_bar.offset_bottom = top + 56.0
	if top_left_ui:
		top_left_ui.offset_left = left + 16.0
		top_left_ui.offset_top = top + 12.0
		top_left_ui.offset_right = left + 388.0
	if power_bar_container:
		var available_width := get_viewport().get_visible_rect().size.x - left - right
		var meter_width := minf(480.0, available_width * 0.52)
		power_bar_container.anchor_left = 0.5
		power_bar_container.anchor_right = 0.5
		power_bar_container.offset_left = -meter_width * 0.5
		power_bar_container.offset_right = meter_width * 0.5
		power_bar_container.offset_bottom = -(bottom + 18.0)
		power_bar_container.offset_top = power_bar_container.offset_bottom - 20.0


func _apply_ball_tuning() -> void:
	ball.mass = maxf(ball_mass, 0.001)
	ball.linear_damp = linear_damping
	ball.angular_damp = angular_damping
	ball.continuous_cd = true
	ball.can_sleep = true
	ball.contact_monitor = true
	ball.max_contacts_reported = 8
	var ball_material := PhysicsMaterial.new()
	ball_material.friction = ball_friction
	ball_material.bounce = ball_bounce
	ball.physics_material_override = ball_material
	var ground_material := PhysicsMaterial.new()
	ground_material.friction = ground_friction
	ground_material.bounce = ground_bounce
	ground.physics_material_override = ground_material


func _update_instruction_visibility() -> void:
	instruction_label.visible = not has_successful_shot


func _update_debug_ui() -> void:
	reset_ok_label.visible = reset_ok_label.visible and developer_debug_enabled
	power_label.visible = developer_debug_enabled
	direction_label.visible = developer_debug_enabled
	curve_label.visible = developer_debug_enabled
	loft_category_label.visible = developer_debug_enabled
	shot_debug_label.visible = developer_debug_enabled
	if power_bar_container:
		power_bar_container.visible = developer_debug_enabled and is_swiping

	power_label.text = "Launch Speed: %.2f (ratio %.2f)" % [current_launch_speed, current_power_ratio]
	direction_label.text = "Direction: (%.2f, %.2f, %.2f)" % [
		current_shot_direction.x,
		current_shot_direction.y,
		current_shot_direction.z,
	]
	curve_label.text = "Curve: %.2f  cap %.1f deg" % [
		current_curve_amount,
		last_curve_heading_degrees,
	]
	var category := current_shot_category if is_swiping else last_shot_category
	var elev_deg := current_elevation_degrees if is_swiping else last_elevation_degrees
	var elev_intent := current_elevation_intent if is_swiping else last_elevation_intent
	var loft_intent := current_loft_intent if is_swiping else last_loft_intent
	var overall_dir := current_overall_screen_dir if is_swiping else Vector2.ZERO
	if loft_category_label:
		loft_category_label.text = (
			"%s  elev %.1f deg  intent %.2f  lift %.2f" % [
				category,
				elev_deg,
				elev_intent,
				last_vertical_launch_speed,
			]
		)
	shot_debug_label.text = (
		"Swipe: (%.2f, %.2f)  loft %.2f  Vy: %.2f  PeakY: %.2f" % [
			overall_dir.x,
			overall_dir.y,
			loft_intent,
			last_post_shot_y_velocity,
			shot_peak_y if tracking_shot_peak or shot_peak_y > 0.0 else ball.global_position.y,
		]
	)
	power_bar.value = current_power_ratio if is_swiping else 0.0


func _debug_log(message: String) -> void:
	if developer_debug_enabled:
		print(message)
