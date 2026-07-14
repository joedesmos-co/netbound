extends "res://scripts/prototype_controller.gd"

enum LevelState { READY, SHOT_ACTIVE, AUTO_RESETTING, GOAL, FAILED }

@export var max_shots: int = 3
@export var shot_timeout: float = 8.0
@export var shot_settling_grace: float = 0.2
@export var miss_reset_delay: float = 1.2
@export var goal_slow_motion_scale: float = 0.35
@export var goal_slow_motion_duration: float = 0.45
@export var bounds_min_x: float = -24.0
@export var bounds_max_x: float = 24.0
@export var bounds_min_z: float = -18.0
@export var bounds_max_z: float = 12.0
@export var bounds_min_y: float = -2.0
@export var goal_clear_half_width: float = 11.0
@export var goal_crossbar_height: float = 8.4
@export var goal_interior_depth: float = 5.0

@onready var goal_detector: GoalDetector = $Goal/GoalDetection
@onready var goal_root: Node3D = $Goal
@onready var goal_flash: ColorRect = $UI/GoalFlash
@onready var goal_particles: CPUParticles3D = $Goal/GoalParticles
@onready var shots_label: Label = $UI/TopBar/ShotsLabel
@onready var retry_button: Button = $UI/TopLeftUI/RetryLevelButton
@onready var win_panel: PanelContainer = $UI/WinPanel
@onready var fail_panel: PanelContainer = $UI/FailPanel
@onready var win_title: Label = $UI/WinPanel/MarginContainer/VBox/TitleLabel
@onready var win_shots_used: Label = $UI/WinPanel/MarginContainer/VBox/ShotsUsedLabel
@onready var win_retry_button: Button = $UI/WinPanel/MarginContainer/VBox/RetryButton
@onready var win_continue_button: Button = $UI/WinPanel/MarginContainer/VBox/ContinueButton
@onready var fail_retry_button: Button = $UI/FailPanel/MarginContainer/VBox/RetryButton

var level_state: LevelState = LevelState.READY
var shots_remaining: int = 3
var shots_used: int = 0
var active_shot_id: int = 0
var shot_time_remaining: float = 0.0
var shot_active_elapsed: float = 0.0
var auto_reset_pending: bool = false
var pending_auto_reset_shot_id: int = -1
var shot_manually_reset: bool = false
var state_generation: int = 0


func _ready() -> void:
	camera_position = Vector3(0.0, 11.5, 14.0)
	camera_look_at = Vector3(0.0, 3.6, -8.5)
	await super._ready()
	goal_detector.debug_goal_detection = developer_debug_enabled
	goal_detector.setup(ball)
	goal_detector.sync_geometry(
		goal_root.global_position.z,
		goal_clear_half_width,
		goal_crossbar_height,
		goal_interior_depth,
		ball_radius
	)
	goal_detector.goal_scored.connect(_on_goal_scored)
	retry_button.pressed.connect(_on_retry_level_pressed)
	win_retry_button.pressed.connect(_on_retry_level_pressed)
	win_continue_button.pressed.connect(_on_continue_pressed)
	fail_retry_button.pressed.connect(_on_retry_level_pressed)
	reset_button.text = "Reset Ball"
	await _restart_level()


func is_gameplay_input_allowed() -> bool:
	return level_state == LevelState.READY


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if level_state != LevelState.SHOT_ACTIVE:
		return

	goal_detector.set_level_state_name("SHOT_ACTIVE")
	shot_active_elapsed += delta
	shot_time_remaining -= delta

	if goal_detector.process_ball(ball.global_position, ball_radius, active_shot_id):
		return
	if _is_ball_out_of_bounds():
		_resolve_miss(active_shot_id, "out_of_bounds")
		return
	if shot_time_remaining <= 0.0:
		_resolve_miss(active_shot_id, "timeout")
		return
	if _is_ball_stopped():
		if shot_manually_reset:
			shot_manually_reset = false
			return
		if shot_active_elapsed < shot_settling_grace:
			return
		_resolve_miss(active_shot_id, "stopped")


func _begin_swipe(screen_position: Vector2, pointer_id: int) -> void:
	if not is_gameplay_input_allowed() or auto_reset_pending:
		return
	super._begin_swipe(screen_position, pointer_id)


func _fire_shot() -> bool:
	if level_state != LevelState.READY:
		_debug_log(
			"RELEASE_BLOCKED reason=bad_level_state state=%d reset_in_progress=%s" % [
				level_state,
				reset_in_progress,
			]
		)
		return false
	if shots_remaining <= 0:
		_debug_log("RELEASE_BLOCKED reason=no_shots_remaining state=%d" % level_state)
		return false

	_cancel_shot_callbacks()
	active_shot_id += 1
	_ensure_ball_ready_for_play()
	_debug_log(
		"RELEASE_LEVEL state_before=%d reset_in_progress=%s freeze=%s" % [
			level_state,
			reset_in_progress,
			ball.freeze,
		]
	)

	# Mark active before physics so settling logic and detector share the same shot id.
	level_state = LevelState.SHOT_ACTIVE
	goal_detector.set_level_state_name("SHOT_ACTIVE")
	shot_time_remaining = shot_timeout
	shot_active_elapsed = 0.0
	shot_manually_reset = false

	var launched := super._fire_shot()
	if not launched:
		level_state = LevelState.READY
		_update_level_ui()
		return false

	shots_remaining -= 1
	shots_used += 1
	_debug_log(
		"RELEASE_LEVEL state_after=%d freeze=%s vel=%s" % [
			level_state,
			ball.freeze,
			ball.linear_velocity,
		]
	)
	goal_detector.begin_shot_tracking(active_shot_id, ball.global_position)
	_update_level_ui()
	return true


func _on_reset_button_pressed() -> void:
	if reset_in_progress:
		return
	if level_state == LevelState.GOAL or level_state == LevelState.FAILED:
		return

	var reset_generation_token := _cancel_shot_callbacks()
	var was_active_shot := level_state == LevelState.SHOT_ACTIVE or level_state == LevelState.AUTO_RESETTING
	if was_active_shot:
		active_shot_id += 1

	goal_detector.reset_shot_tracking()
	shot_manually_reset = was_active_shot
	shot_time_remaining = 0.0
	shot_active_elapsed = 0.0
	_clear_active_curve()
	tracking_shot_peak = false
	shot_peak_y = 0.0
	level_state = LevelState.AUTO_RESETTING
	reset_in_progress = true
	_clear_swipe()
	_update_level_ui()

	await _apply_physics_safe_reset()
	if reset_generation_token != state_generation:
		return

	_ensure_ball_ready_for_play()
	shot_manually_reset = false
	if shots_remaining > 0:
		level_state = LevelState.READY
	else:
		level_state = LevelState.FAILED
		fail_panel.visible = true
	_update_level_ui()
	_update_instruction_visibility()
	_update_debug_ui()


func _on_retry_level_pressed() -> void:
	await _restart_level()


func _on_continue_pressed() -> void:
	win_shots_used.text = "More levels coming next milestone"
	var callback_generation := state_generation
	get_tree().create_timer(1.5).timeout.connect(_restart_level_if_current.bind(callback_generation))


func _restart_level_if_current(callback_generation: int) -> void:
	if callback_generation == state_generation:
		await _restart_level()


func _restart_level() -> void:
	_cancel_shot_callbacks()
	Engine.time_scale = 1.0
	shot_manually_reset = false
	level_state = LevelState.READY
	active_shot_id = 0
	shots_remaining = max_shots
	shots_used = 0
	shot_time_remaining = 0.0
	shot_active_elapsed = 0.0
	_clear_active_curve()
	has_successful_shot = false
	goal_detector.reset_shot_tracking()
	_hide_overlays()
	_clear_swipe()
	reset_in_progress = true
	await _apply_physics_safe_reset()
	_ensure_ball_ready_for_play()
	_update_level_ui()
	_update_instruction_visibility()
	_update_debug_ui()
	_debug_log(
		"RESTART_DONE freeze=%s sleeping=%s reset_in_progress=%s state=%d" % [
			ball.freeze,
			ball.sleeping,
			reset_in_progress,
			level_state,
		]
	)


func _on_goal_scored() -> void:
	if level_state != LevelState.SHOT_ACTIVE:
		return

	_cancel_shot_callbacks()
	level_state = LevelState.GOAL
	_clear_active_curve()
	ball.freeze = true
	_show_goal_feedback()
	win_title.text = "GOAL!"
	win_shots_used.text = "Shots used: %d / %d" % [shots_used, max_shots]
	win_panel.visible = true
	_update_level_ui()


func _resolve_miss(shot_id: int, _reason: String) -> void:
	if shot_id != active_shot_id:
		return
	if level_state != LevelState.SHOT_ACTIVE:
		return

	shot_time_remaining = 0.0
	shot_active_elapsed = 0.0
	_clear_active_curve()

	if shots_remaining > 0:
		level_state = LevelState.AUTO_RESETTING
		_schedule_auto_reset(shot_id)
	else:
		level_state = LevelState.FAILED
		fail_panel.visible = true

	_update_level_ui()


func _schedule_auto_reset(shot_id: int) -> void:
	if auto_reset_pending:
		return
	auto_reset_pending = true
	pending_auto_reset_shot_id = shot_id
	var callback_generation := state_generation
	get_tree().create_timer(miss_reset_delay).timeout.connect(
		_auto_reset_after_miss.bind(shot_id, callback_generation)
	)


func _auto_reset_after_miss(shot_id: int, callback_generation: int) -> void:
	if callback_generation != state_generation:
		return
	auto_reset_pending = false
	pending_auto_reset_shot_id = -1
	if shot_id != active_shot_id:
		return
	if level_state != LevelState.AUTO_RESETTING:
		return

	reset_in_progress = true
	await _apply_physics_safe_reset()
	if (
		callback_generation != state_generation
		or shot_id != active_shot_id
		or level_state != LevelState.AUTO_RESETTING
	):
		return

	_ensure_ball_ready_for_play()
	level_state = LevelState.READY
	_update_level_ui()
	_update_instruction_visibility()
	_update_debug_ui()


func _cancel_shot_callbacks() -> int:
	state_generation += 1
	auto_reset_pending = false
	pending_auto_reset_shot_id = -1
	return state_generation


func _is_ball_out_of_bounds() -> bool:
	var pos := ball.global_position
	return (
		pos.x < bounds_min_x
		or pos.x > bounds_max_x
		or pos.z < bounds_min_z
		or pos.z > bounds_max_z
		or pos.y < bounds_min_y
	)


func _show_goal_feedback() -> void:
	goal_flash.visible = true
	goal_flash.modulate.a = 0.85
	goal_particles.emitting = true
	Engine.time_scale = goal_slow_motion_scale
	var callback_generation := state_generation
	get_tree().create_timer(goal_slow_motion_duration).timeout.connect(
		_restore_time_scale.bind(callback_generation)
	)
	get_tree().create_timer(0.35).timeout.connect(_hide_goal_flash.bind(callback_generation))


func _restore_time_scale(callback_generation: int = -1) -> void:
	if callback_generation != -1 and callback_generation != state_generation:
		return
	Engine.time_scale = 1.0


func _hide_goal_flash(callback_generation: int = -1) -> void:
	if callback_generation != -1 and callback_generation != state_generation:
		return
	goal_flash.visible = false


func _hide_overlays() -> void:
	win_panel.visible = false
	fail_panel.visible = false
	goal_flash.visible = false
	goal_particles.emitting = false


func _update_level_ui() -> void:
	shots_label.text = "Shots: %d" % shots_remaining
	retry_button.disabled = reset_in_progress
	reset_button.disabled = (
		reset_in_progress
		or level_state == LevelState.GOAL
		or level_state == LevelState.FAILED
	)
