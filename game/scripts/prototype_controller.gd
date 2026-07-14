extends Node3D

const MOUSE_POINTER_ID: int = -2

@export var minimum_swipe_distance: float = 24.0
@export var maximum_swipe_distance: float = 320.0
@export var max_swipe_screen_height_ratio: float = 0.32
@export var minimum_impulse: float = 3.5
@export var maximum_impulse: float = 20.0
@export var power_curve_exponent: float = 0.68
@export var minimum_elevation_degrees: float = 0.0
@export var driven_elevation_degrees: float = 8.0
@export var maximum_elevation_degrees: float = 55.0
@export var upward_angle_deadzone: float = 0.1
@export var elevation_response_exponent: float = 1.0
@export var downward_ground_shot_threshold: float = 0.1
@export var ball_radius: float = 0.49
@export var ball_ground_clearance: float = 0.03
@export var launch_clearance_boost: float = 0.04
@export var ball_mass: float = 0.43
@export var linear_damping: float = 0.08
@export var angular_damping: float = 0.25
@export var ball_friction: float = 0.22
@export var ball_bounce: float = 0.28
@export var ground_friction: float = 0.28
@export var ground_bounce: float = 0.22
@export var ball_hit_radius: float = 90.0
@export var launch_y_restore_threshold: float = 0.35
@export var stopped_velocity_threshold: float = 0.08
@export var maximum_curve_strength: float = 1.75
@export var curve_force_duration: float = 1.7
@export var curve_force_multiplier: float = 22.0
@export var curve_spin_impulse: float = 7.5
@export var curve_peak_threshold_px: float = 2.0
@export var curve_full_bend_ratio: float = 0.28
@export var curve_response_exponent: float = 0.7
@export var swipe_sample_smoothing: float = 0.45
@export var camera_position: Vector3 = Vector3(0.0, 6.5, 10.0)
@export var camera_look_at: Vector3 = Vector3(0.0, 0.65, -12.0)
@export var aim_arrow_min_length: float = 1.2
@export var aim_arrow_max_length: float = 5.0
@export var aim_guide_height_offset: float = 0.08

@onready var ball_spawn: Marker3D = $BallSpawn
@onready var ball: RigidBody3D = $Ball
@onready var ground: StaticBody3D = $Ground
@onready var camera: Camera3D = $Camera3D
@onready var aim_guide: Node3D = $AimGuide
@onready var aim_shaft: MeshInstance3D = $AimGuide/Shaft
@onready var aim_head: MeshInstance3D = $AimGuide/Head
@onready var reset_button: Button = $UI/TopLeftUI/ResetButton
@onready var reset_ok_label: Label = $UI/TopLeftUI/ResetOkLabel
@onready var instruction_label: Label = $UI/TopLeftUI/InstructionLabel
@onready var power_label: Label = $UI/TopLeftUI/PowerLabel
@onready var direction_label: Label = $UI/TopLeftUI/DirectionLabel
@onready var curve_label: Label = $UI/TopLeftUI/CurveLabel
@onready var shot_debug_label: Label = $UI/TopLeftUI/ShotDebugLabel
@onready var loft_category_label: Label = $UI/TopLeftUI/LoftCategoryLabel
@onready var power_bar: ProgressBar = $UI/PowerBarContainer/PowerBar
@onready var swipe_overlay: SwipeOverlay = $UI/SwipeOverlay

var spawn_transform: Transform3D
var effective_max_swipe_distance: float = 320.0
var reset_count: int = 0
var reset_in_progress: bool = false
var reset_generation: int = 0
var is_swiping: bool = false
var is_swipe_valid: bool = false
var has_successful_shot: bool = false
var active_pointer_id: int = -1
var swipe_screen_points: PackedVector2Array = PackedVector2Array()
var current_shot_power: float = 0.0
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
var curve_force_time_remaining: float = 0.0
var active_curve_sign: float = 0.0
var active_curve_strength: float = 0.0
var tracking_shot_peak: bool = false
var shot_peak_y: float = 0.0
var last_horizontal_impulse: float = 0.0
var last_lift_impulse: float = 0.0
var last_loft_intent: float = 0.0
var last_ground_intent: float = 0.0
var last_elevation_intent: float = 0.0
var last_elevation_degrees: float = 0.0
var last_shot_category: String = "DRIVEN"
var last_launch_direction: Vector3 = Vector3.ZERO
var last_post_shot_y_velocity: float = 0.0
var last_final_impulse: Vector3 = Vector3.ZERO
var launch_safeguard_pending: bool = false


func _ready() -> void:
	_setup_camera()
	_configure_ball_spawn_height()
	_configure_swipe_distance()
	get_viewport().size_changed.connect(_configure_swipe_distance)
	_apply_ball_tuning()
	_update_instruction_visibility()
	_update_debug_ui()
	_clear_swipe_visuals()
	await _apply_physics_safe_reset()
	print("INIT ball=", ball.global_position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and is_swiping and active_pointer_id == MOUSE_POINTER_ID:
		_cancel_swipe()


func _physics_process(delta: float) -> void:
	if tracking_shot_peak:
		shot_peak_y = maxf(shot_peak_y, ball.global_position.y)
		if _is_ball_stopped():
			tracking_shot_peak = false
			print("PEAK ball_y=", shot_peak_y)
			_update_debug_ui()

	if curve_force_time_remaining <= 0.0:
		return

	curve_force_time_remaining -= delta
	var velocity := ball.linear_velocity
	if velocity.length() <= 0.15:
		return

	var travel_direction := velocity.normalized()
	var lateral := travel_direction.cross(Vector3.UP).normalized()
	ball.apply_central_force(
		lateral * active_curve_sign * active_curve_strength * curve_force_multiplier * ball.mass
	)


func _setup_camera() -> void:
	camera.global_position = camera_position
	camera.look_at(camera_look_at, Vector3.UP)
	camera.current = true


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
		if screen_touch.pressed:
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

	print("_on_reset_button_pressed called")
	var before := ball.global_position
	reset_count += 1
	reset_ok_label.text = "RESET OK #%d" % reset_count
	reset_ok_label.visible = true
	get_tree().create_timer(1.0).timeout.connect(_hide_reset_ok_label)
	_run_reset(before)


func _hide_reset_ok_label() -> void:
	reset_ok_label.visible = false


func _run_reset(before_position: Vector3) -> void:
	reset_in_progress = true
	_clear_swipe()
	tracking_shot_peak = false
	shot_peak_y = 0.0
	curve_force_time_remaining = 0.0
	active_curve_sign = 0.0
	active_curve_strength = 0.0
	has_successful_shot = false

	await _apply_physics_safe_reset()

	print("RESET before=", before_position, " after=", ball.global_position)
	await get_tree().physics_frame
	print("RESET frame+1 pos=", ball.global_position, " vel=", ball.linear_velocity)

	reset_in_progress = false
	_update_instruction_visibility()
	_update_debug_ui()


func _apply_physics_safe_reset() -> void:
	reset_generation += 1
	var token := reset_generation
	spawn_transform = ball_spawn.global_transform

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
	ball.sleeping = false
	_apply_ball_tuning()


func _ensure_ball_ready_for_play() -> void:
	reset_in_progress = false
	ball.freeze = false
	ball.sleeping = false
	if ball.linear_velocity.length() < stopped_velocity_threshold:
		ball.linear_velocity = Vector3.ZERO
	if ball.angular_velocity.length() < stopped_velocity_threshold:
		ball.angular_velocity = Vector3.ZERO


func is_gameplay_input_allowed() -> bool:
	return true


func _begin_swipe(screen_position: Vector2, pointer_id: int) -> void:
	if not is_gameplay_input_allowed():
		return
	if is_swiping or reset_in_progress or not _is_ball_stopped() or not _is_screen_position_in_viewport(screen_position):
		return

	if not _is_screen_position_on_ball(screen_position):
		return

	active_pointer_id = pointer_id
	is_swiping = true
	swipe_screen_points = PackedVector2Array([screen_position])
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

	print("RELEASE_RECEIVED pointer=", pointer_id, " pos=", screen_position)

	if not _is_screen_position_in_viewport(screen_position):
		print("RELEASE rejected reason=outside_viewport")
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

	print(
		"RELEASE_RECEIVED samples=",
		swipe_screen_points.size(),
		" distance=",
		swipe_distance,
		" valid=",
		is_swipe_valid,
		" reason=",
		invalid_reason,
		" power_ratio=",
		current_power_ratio,
		" category=",
		current_shot_category,
		" elev_deg=",
		current_elevation_degrees,
		" elev_intent=",
		current_elevation_intent,
		" curve=",
		current_curve_amount,
		" reset_in_progress=",
		reset_in_progress,
		" freeze=",
		ball.freeze,
		" sleeping=",
		ball.sleeping
	)

	if is_swipe_valid:
		_fire_shot()
	else:
		print("RELEASE rejected reason=", invalid_reason)
		_clear_swipe()

	_update_debug_ui()
	get_viewport().set_input_as_handled()


func _commit_swipe_release_sample(screen_position: Vector2) -> void:
	if swipe_screen_points.is_empty():
		swipe_screen_points.append(screen_position)
		return
	if swipe_screen_points[-1].distance_to(screen_position) > 0.25:
		swipe_screen_points.append(screen_position)


func _fire_shot() -> void:
	var impulse := _compute_shot_impulse(
		current_power_ratio,
		current_shot_direction,
		swipe_screen_points
	)
	last_final_impulse = impulse

	# Abort any in-flight reset ownership of the body for this launch.
	if reset_in_progress:
		print("RELEASE_FIRE forcing reset_in_progress clear before launch")
		reset_in_progress = false

	var curve_sign := signf(current_curve_amount)
	var curve_strength := clampf(absf(current_curve_amount), 0.0, maximum_curve_strength)
	var shot_token := reset_generation
	var launch_mass := maxf(ball.mass, 0.001)
	var launch_velocity := impulse / launch_mass

	print(
		"RELEASE_FIRE impulse=",
		impulse,
		" mass=",
		launch_mass,
		" launch_vel=",
		launch_velocity,
		" freeze_before=",
		ball.freeze,
		" sleeping_before=",
		ball.sleeping,
		" reset_in_progress=",
		reset_in_progress,
		" generation=",
		shot_token
	)

	# Reliable launch: unfreeze first, then assign velocity directly.
	# apply_central_impulse can be ignored on the same frame freeze flips false (Jolt).
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
	print(
		"RELEASE_FIRE vel_set=",
		ball.linear_velocity,
		" pos_y=",
		ball.global_position.y,
		" freeze_after=",
		ball.freeze,
		" sleeping_after=",
		ball.sleeping
	)
	_run_launch_y_safeguard(shot_token, impulse.y, launch_velocity)

	tracking_shot_peak = true
	shot_peak_y = ball.global_position.y

	if curve_strength > 0.02:
		ball.apply_torque_impulse(Vector3.UP * curve_sign * curve_strength * curve_spin_impulse)
		active_curve_sign = curve_sign
		active_curve_strength = curve_strength
		curve_force_time_remaining = curve_force_duration

	has_successful_shot = true
	_clear_swipe()
	_update_instruction_visibility()
	_update_debug_ui()


func _run_launch_y_safeguard(
	shot_token: int,
	intended_lift: float,
	expected_launch_velocity: Vector3
) -> void:
	launch_safeguard_pending = true
	await get_tree().physics_frame

	if shot_token != reset_generation:
		print(
			"LAUNCH_SAFEGUARD skipped reset_generation changed ",
			shot_token,
			" -> ",
			reset_generation
		)
		launch_safeguard_pending = false
		return

	var vel_before := ball.linear_velocity
	print(
		"LAUNCH_SAFEGUARD frame+1 vel=",
		vel_before,
		" freeze=",
		ball.freeze,
		" contacts=",
		ball.get_contact_count() if ball.has_method("get_contact_count") else -1
	)

	# Only restore missing Y once. Preserve XZ exactly.
	if intended_lift >= launch_y_restore_threshold and vel_before.y < expected_launch_velocity.y * 0.45:
		ball.linear_velocity = Vector3(
			vel_before.x,
			expected_launch_velocity.y,
			vel_before.z
		)
		last_post_shot_y_velocity = expected_launch_velocity.y
		print(
			"LAUNCH_Y_RESTORE ran before=",
			vel_before,
			" after=",
			ball.linear_velocity
		)
	else:
		print("LAUNCH_SAFEGUARD ran no_y_restore")

	# If a freeze race somehow returned, force the ball awake with expected XZ.
	if ball.freeze:
		ball.freeze = false
		ball.sleeping = false
		ball.linear_velocity = Vector3(
			expected_launch_velocity.x,
			maxf(ball.linear_velocity.y, expected_launch_velocity.y * 0.5),
			expected_launch_velocity.z
		)
		print("LAUNCH_SAFEGUARD unfroze_and_restored vel=", ball.linear_velocity)

	launch_safeguard_pending = false


func _log_shot_velocity_next_frame(shot_token: int) -> void:
	await get_tree().physics_frame
	if shot_token != reset_generation:
		return
	print("RELEASE_FIRE vel_frame+1=", ball.linear_velocity)


func _compute_shot_impulse(
	power_ratio: float,
	horizontal_direction: Vector3,
	swipe_samples: PackedVector2Array
) -> Vector3:
	var curved_power := pow(clampf(power_ratio, 0.0, 1.0), power_curve_exponent)
	var shot_speed := lerpf(minimum_impulse, maximum_impulse, curved_power)
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
	last_horizontal_impulse = shot_speed * cos(elevation_rad)
	last_lift_impulse = shot_speed * sin(elevation_rad)
	return launch_dir * shot_speed


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
	current_elevation_degrees = lerpf(
		driven_elevation_degrees,
		maximum_elevation_degrees,
		current_elevation_intent
	)
	if current_elevation_degrees >= lerpf(driven_elevation_degrees, maximum_elevation_degrees, 0.35):
		current_shot_category = "LOFTED"
	else:
		current_shot_category = "DRIVEN"


func _cancel_swipe() -> void:
	_clear_swipe()
	_update_debug_ui()


func _clear_swipe() -> void:
	is_swiping = false
	is_swipe_valid = false
	active_pointer_id = -1
	swipe_screen_points = PackedVector2Array()
	current_shot_power = 0.0
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


func _add_swipe_sample(screen_position: Vector2) -> void:
	if swipe_screen_points.is_empty():
		swipe_screen_points.append(screen_position)
		return

	var last_point := swipe_screen_points[-1]
	var smoothed := last_point.lerp(screen_position, swipe_sample_smoothing)
	if smoothed.distance_to(last_point) >= 2.0:
		swipe_screen_points.append(smoothed)


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
	current_shot_power = lerpf(minimum_impulse, maximum_impulse, current_power_ratio)
	current_shot_direction = world_direction
	current_shot_direction_screen = screen_delta.normalized()
	_analyze_elevation_from_screen_delta(screen_delta)
	current_curve_amount = _calculate_curve_amount(swipe_start, swipe_end)


func _reset_aim_state() -> void:
	current_shot_power = 0.0
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
	return signed_curve * strength_ratio * maximum_curve_strength


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
		clampf(absf(current_curve_amount), 0.0, maximum_curve_strength),
		true
	)


func _clear_swipe_visuals() -> void:
	swipe_overlay.clear_visuals()


func _update_aim_guide() -> void:
	if not is_swiping or not is_swipe_valid:
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


func _is_ball_stopped() -> bool:
	return (
		ball.linear_velocity.length() <= stopped_velocity_threshold
		and ball.angular_velocity.length() <= stopped_velocity_threshold
	)


func _is_screen_position_in_viewport(screen_position: Vector2) -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	return viewport_rect.has_point(screen_position)


func _is_screen_position_on_ball(screen_position: Vector2) -> bool:
	var ball_screen_position := camera.unproject_position(ball.global_position)
	return screen_position.distance_to(ball_screen_position) <= ball_hit_radius


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
	power_label.text = "Shot Power: %.2f (ratio %.2f)" % [current_shot_power, current_power_ratio]
	direction_label.text = "Direction: (%.2f, %.2f, %.2f)" % [
		current_shot_direction.x,
		current_shot_direction.y,
		current_shot_direction.z,
	]
	curve_label.text = "Curve: %.2f" % current_curve_amount
	var category := current_shot_category if is_swiping else last_shot_category
	var elev_deg := current_elevation_degrees if is_swiping else last_elevation_degrees
	var elev_intent := current_elevation_intent if is_swiping else last_elevation_intent
	var loft_intent := current_loft_intent if is_swiping else last_loft_intent
	var overall_dir := current_overall_screen_dir if is_swiping else Vector2.ZERO
	if loft_category_label:
		loft_category_label.text = (
			"%s  elev %.1f°  intent %.2f  lift %.2f" % [
				category,
				elev_deg,
				elev_intent,
				last_lift_impulse,
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
