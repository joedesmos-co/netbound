extends "res://scripts/prototype_controller.gd"

signal level_completed(level_result: LevelResult, progression_update: RefCounted)
signal level_failed(level_result: LevelResult)

enum LevelState { READY, SHOT_ACTIVE, AUTO_RESETTING, GOAL, FAILED }

const RESETTABLE_GROUP := "netbound_level_resettable"
const GOAL_TARGET_GROUP := "netbound_goal_target"
const CosmeticVisualsScript := preload("res://scripts/cosmetics/cosmetic_visuals.gd")
const LevelVisualPolishScript := preload("res://scripts/presentation/level_visual_polish.gd")

@export var level_definition: LevelDefinition
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

@onready var goal_detector: GoalDetector = get_node_or_null("Goal/GoalDetection") as GoalDetector
@onready var goal_root: Node3D = get_node_or_null("Goal") as Node3D
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
var level_reset_generation: int = 0
var goal_targets: Array[GoalTarget] = []
var last_level_result: LevelResult
var last_progression_update: RefCounted
var external_navigation_ui_enabled: bool = false
var selected_ball_skin_id: String = "ball_classic"
var selected_trail_id: String = "trail_none"
var selected_goal_effect_id: String = "goal_classic"
var near_miss_presented_shot_id: int = -1
var level_visual_polish
var rewarded_continue_used: bool = false


func _ready() -> void:
	_apply_level_definition_runtime_values()
	await super._ready()
	_refresh_selected_cosmetics()
	_apply_level_definition_ui_values()
	_setup_goal_targets()
	_setup_level_visual_polish()
	retry_button.pressed.connect(_on_retry_level_pressed)
	win_retry_button.pressed.connect(_on_retry_level_pressed)
	win_continue_button.pressed.connect(_on_continue_pressed)
	fail_retry_button.pressed.connect(_on_retry_level_pressed)
	reset_button.text = "Reset Ball"
	await _restart_level()
	if external_navigation_ui_enabled:
		set_external_navigation_ui_enabled(true)


func set_external_navigation_ui_enabled(enabled: bool) -> void:
	external_navigation_ui_enabled = enabled
	if not is_node_ready():
		return
	if retry_button:
		retry_button.visible = not enabled
	if enabled:
		win_panel.visible = false
		fail_panel.visible = false


func prepare_for_unload() -> void:
	_cancel_shot_callbacks()
	Engine.time_scale = 1.0
	_clear_active_curve()
	_clear_swipe()
	_clear_cosmetic_feedback()
	_clear_level_presentation_feedback()
	_reset_all_goal_tracking()
	auto_reset_pending = false
	pending_auto_reset_shot_id = -1


func is_gameplay_input_allowed() -> bool:
	return level_state == LevelState.READY


func can_use_rewarded_continue() -> bool:
	return (
		level_state == LevelState.FAILED
		and shots_remaining <= 0
		and not rewarded_continue_used
		and not reset_in_progress
	)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if level_state != LevelState.SHOT_ACTIVE:
		return

	_set_goal_state_name("SHOT_ACTIVE")
	shot_active_elapsed += delta
	shot_time_remaining -= delta

	if _process_goal_targets():
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
	_set_goal_state_name("SHOT_ACTIVE")
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
	_begin_goal_tracking(active_shot_id, ball.global_position)
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

	_reset_all_goal_tracking()
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
	_refresh_selected_cosmetics()
	shot_manually_reset = false
	if shots_remaining > 0:
		level_state = LevelState.READY
	else:
		level_state = LevelState.FAILED
		last_level_result = LevelResult.failed_result(
			level_definition,
			shots_used,
			shots_remaining,
			rewarded_continue_used
		)
		if not external_navigation_ui_enabled:
			fail_panel.visible = true
		level_failed.emit(last_level_result)
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
	rewarded_continue_used = false
	level_state = LevelState.AUTO_RESETTING
	last_level_result = null
	last_progression_update = null
	active_shot_id = 0
	near_miss_presented_shot_id = -1
	shots_remaining = max_shots
	shots_used = 0
	shot_time_remaining = 0.0
	shot_active_elapsed = 0.0
	_clear_active_curve()
	has_successful_shot = false
	_reset_all_goal_tracking()
	_hide_overlays()
	_clear_swipe()
	_clear_level_presentation_feedback()
	reset_in_progress = true
	_update_level_ui()
	await _apply_physics_safe_reset()
	_reset_level_elements()
	_ensure_ball_ready_for_play()
	_refresh_selected_cosmetics()
	level_state = LevelState.READY
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
	last_level_result = LevelResult.completed_result(
		level_definition,
		shots_used,
		shots_remaining,
		rewarded_continue_used
	)
	last_progression_update = _record_progression_result(last_level_result)
	_clear_active_curve()
	ball.freeze = true
	_show_goal_feedback()
	if not external_navigation_ui_enabled:
		win_title.text = "GOAL!"
		win_shots_used.text = "Shots used: %d / %d" % [shots_used, max_shots]
		win_panel.visible = true
	level_completed.emit(last_level_result, last_progression_update)
	_update_level_ui()


func _resolve_miss(shot_id: int, _reason: String) -> void:
	if shot_id != active_shot_id:
		return
	if level_state != LevelState.SHOT_ACTIVE:
		return

	_maybe_present_near_miss(shot_id)
	shot_time_remaining = 0.0
	shot_active_elapsed = 0.0
	_clear_active_curve()

	if shots_remaining > 0:
		level_state = LevelState.AUTO_RESETTING
		_schedule_auto_reset(shot_id)
	else:
		level_state = LevelState.FAILED
		last_level_result = LevelResult.failed_result(
			level_definition,
			shots_used,
			shots_remaining,
			rewarded_continue_used
		)
		if not external_navigation_ui_enabled:
			fail_panel.visible = true
		level_failed.emit(last_level_result)

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


func grant_rewarded_continue() -> bool:
	if not can_use_rewarded_continue():
		return false

	var reset_generation_token := _cancel_shot_callbacks()
	active_shot_id += 1
	rewarded_continue_used = true
	shots_remaining = 1
	shot_time_remaining = 0.0
	shot_active_elapsed = 0.0
	shot_manually_reset = false
	near_miss_presented_shot_id = -1
	last_level_result = null
	last_progression_update = null
	level_state = LevelState.AUTO_RESETTING
	_reset_all_goal_tracking()
	_hide_overlays()
	_clear_swipe()
	_clear_active_curve()
	_clear_level_presentation_feedback()
	reset_in_progress = true
	_update_level_ui()

	await _apply_physics_safe_reset()
	if reset_generation_token != state_generation:
		return false

	_reset_level_elements()
	_ensure_ball_ready_for_play()
	_refresh_selected_cosmetics()
	level_state = LevelState.READY
	_update_level_ui()
	_update_instruction_visibility()
	_update_debug_ui()
	return true


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
	_refresh_selected_cosmetics()
	level_state = LevelState.READY
	_update_level_ui()
	_update_instruction_visibility()
	_update_debug_ui()


func _cancel_shot_callbacks() -> int:
	state_generation += 1
	auto_reset_pending = false
	pending_auto_reset_shot_id = -1
	return state_generation


func _apply_level_definition_runtime_values() -> void:
	if not level_definition:
		camera_position = Vector3(0.0, 11.5, 14.0)
		camera_look_at = Vector3(0.0, 3.6, -8.5)
		return

	max_shots = level_definition.shot_limit
	bounds_min_x = level_definition.bounds_min.x
	bounds_min_y = level_definition.bounds_min.y
	bounds_min_z = level_definition.bounds_min.z
	bounds_max_x = level_definition.bounds_max.x
	bounds_max_z = level_definition.bounds_max.z
	camera_position = level_definition.camera_position
	camera_look_at = level_definition.camera_look_at


func _apply_level_definition_ui_values() -> void:
	if level_definition and not level_definition.tutorial_text.is_empty():
		instruction_label.text = level_definition.tutorial_text


func _setup_goal_targets() -> void:
	goal_targets.clear()
	for node in _find_nodes_in_group(GOAL_TARGET_GROUP):
		var target := node as GoalTarget
		if target:
			goal_targets.append(target)

	if goal_targets.is_empty() and goal_root is GoalTarget:
		goal_targets.append(goal_root as GoalTarget)

	if not goal_targets.is_empty():
		for target in goal_targets:
			target.ball_radius = ball_radius
			target.debug_goal_detection = developer_debug_enabled
			target.setup(ball)
			if not target.goal_scored.is_connected(_on_goal_target_scored):
				target.goal_scored.connect(_on_goal_target_scored)
		goal_detector = goal_targets[0].detector
		return

	if goal_detector and goal_root:
		goal_detector.debug_goal_detection = developer_debug_enabled
		goal_detector.setup(ball)
		goal_detector.sync_geometry(
			goal_root.global_position.z,
			goal_root.global_position.x,
			goal_clear_half_width,
			goal_crossbar_height,
			goal_interior_depth,
			ball_radius
		)
		if not goal_detector.goal_scored.is_connected(_on_goal_scored):
			goal_detector.goal_scored.connect(_on_goal_scored)


func _on_goal_target_scored(_target: GoalTarget) -> void:
	_on_goal_scored()


func _record_progression_result(level_result: LevelResult) -> RefCounted:
	var service := get_node_or_null("/root/SaveService")
	if service and service.has_method("record_level_result"):
		return service.call("record_level_result", level_result, level_definition) as RefCounted
	return null


func _set_goal_state_name(state_name: String) -> void:
	if goal_targets.is_empty():
		if goal_detector:
			goal_detector.set_level_state_name(state_name)
		return
	for target in goal_targets:
		target.set_level_state_name(state_name)


func _process_goal_targets() -> bool:
	if goal_targets.is_empty():
		return goal_detector.process_ball(ball.global_position, ball_radius, active_shot_id) if goal_detector else false
	for target in goal_targets:
		if target.process_ball(ball.global_position, ball_radius, active_shot_id):
			return true
	return false


func _begin_goal_tracking(shot_id: int, ball_position: Vector3) -> void:
	if goal_targets.is_empty():
		if goal_detector:
			goal_detector.begin_shot_tracking(shot_id, ball_position)
		return
	for target in goal_targets:
		target.begin_shot_tracking(shot_id, ball_position)


func _reset_all_goal_tracking() -> void:
	if goal_targets.is_empty():
		if goal_detector:
			goal_detector.reset_shot_tracking()
		return
	for target in goal_targets:
		target.reset_shot_tracking()


func _reset_level_elements() -> void:
	level_reset_generation += 1
	var token := level_reset_generation
	for node in _find_nodes_in_group(RESETTABLE_GROUP):
		if node.has_method("reset_level_element"):
			node.call("reset_level_element", token)


func _find_nodes_in_group(group_name: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for child in find_children("*", "", true, false):
		if child.is_in_group(group_name):
			found.append(child)
	return found


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
	_refresh_selected_cosmetics()
	if gameplay_feedback:
		gameplay_feedback.on_goal_scored()
	if level_visual_polish:
		level_visual_polish.on_goal_scored()
	CosmeticVisualsScript.trigger_goal_effect(
		self,
		goal_root,
		goal_flash,
		goal_particles,
		selected_goal_effect_id
	)
	goal_flash.visible = true
	goal_flash.modulate.a = 0.85
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
	_clear_cosmetic_feedback()
	_clear_level_presentation_feedback()


func _update_level_ui() -> void:
	shots_label.text = "Shots: %d" % shots_remaining
	retry_button.visible = not external_navigation_ui_enabled
	retry_button.disabled = reset_in_progress
	reset_button.disabled = (
		reset_in_progress
		or level_state == LevelState.GOAL
		or level_state == LevelState.FAILED
	)


func _refresh_selected_cosmetics() -> void:
	var service := get_node_or_null("/root/SaveService")
	if service:
		if service.has_method("get_selected_ball"):
			selected_ball_skin_id = String(service.call("get_selected_ball"))
		if service.has_method("get_selected_trail"):
			selected_trail_id = String(service.call("get_selected_trail"))
		if service.has_method("get_selected_goal_effect"):
			selected_goal_effect_id = String(service.call("get_selected_goal_effect"))
	CosmeticVisualsScript.apply_to_ball(ball, selected_ball_skin_id, selected_trail_id)


func _clear_cosmetic_feedback() -> void:
	CosmeticVisualsScript.reset_ball_trail(ball)
	CosmeticVisualsScript.clear_goal_effects(self)


func _setup_level_visual_polish() -> void:
	if level_visual_polish:
		return
	level_visual_polish = LevelVisualPolishScript.new()
	add_child(level_visual_polish)
	level_visual_polish.setup(self)


func _clear_level_presentation_feedback() -> void:
	if level_visual_polish and level_visual_polish.has_method("clear_feedback"):
		level_visual_polish.clear_feedback()


func _present_ball_impact(kind: String, strength: float, body: Node) -> void:
	super._present_ball_impact(kind, strength, body)
	if kind == "post":
		_maybe_present_near_miss(active_shot_id)


func _maybe_present_near_miss(shot_id: int) -> void:
	if shot_id != active_shot_id or shot_id == near_miss_presented_shot_id:
		return
	if level_state == LevelState.GOAL:
		return
	if not _is_near_goal_miss_position():
		return
	near_miss_presented_shot_id = shot_id
	if gameplay_feedback:
		gameplay_feedback.on_near_miss()


func _is_near_goal_miss_position() -> bool:
	var target_root := goal_root
	var half_width := goal_clear_half_width
	var crossbar := goal_crossbar_height
	var depth := goal_interior_depth
	if not goal_targets.is_empty():
		target_root = goal_targets[0]
		half_width = goal_targets[0].opening_half_width
		crossbar = goal_targets[0].crossbar_height
		depth = goal_targets[0].interior_depth
	if not target_root:
		return false
	var local := target_root.to_local(ball.global_position)
	var near_goal_plane := local.z <= 1.4 and local.z >= -depth - 1.4
	if not near_goal_plane:
		return false
	var side_gap := absf(absf(local.x) - half_width)
	var just_wide := side_gap <= 1.1 and local.y >= ball_radius and local.y <= crossbar + 0.8
	var just_high := absf(local.x) <= half_width + 0.8 and local.y > crossbar and local.y <= crossbar + 1.2
	return just_wide or just_high
