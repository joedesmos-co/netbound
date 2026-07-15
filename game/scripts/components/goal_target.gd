class_name GoalTarget
extends Node3D

signal goal_scored(target: GoalTarget)

const RESET_GROUP := "netbound_level_resettable"
const GOAL_GROUP := "netbound_goal_target"

@export var opening_half_width: float = 11.0
@export var crossbar_height: float = 8.4
@export var interior_depth: float = 5.0
@export var ball_radius: float = 0.49
@export var post_radius: float = 0.28
@export var mouth_depth: float = 0.45
@export var debug_goal_detection: bool = false
@export var show_debug_volumes: bool = false
@export var detector_path: NodePath = NodePath("GoalDetection")
@export var particles_path: NodePath = NodePath("GoalParticles")

@onready var detector: GoalDetector = get_node_or_null(detector_path) as GoalDetector
@onready var goal_particles: CPUParticles3D = get_node_or_null(particles_path) as CPUParticles3D


func _enter_tree() -> void:
	add_to_group(RESET_GROUP)
	add_to_group(GOAL_GROUP)


func _ready() -> void:
	_sync_geometry()
	if detector and not detector.goal_scored.is_connected(_on_detector_goal_scored):
		detector.goal_scored.connect(_on_detector_goal_scored)


func setup(ball: RigidBody3D) -> void:
	_sync_geometry()
	if detector:
		detector.debug_goal_detection = debug_goal_detection
		detector.show_debug_volumes = show_debug_volumes
		detector.setup(ball)
		_sync_detector_geometry()


func reset_level_element(_generation: int) -> void:
	reset_shot_tracking()
	if goal_particles:
		goal_particles.emitting = false


func reset_shot_tracking() -> void:
	if detector:
		detector.reset_shot_tracking()


func begin_shot_tracking(shot_id: int, ball_position: Vector3) -> void:
	if detector:
		detector.begin_shot_tracking(shot_id, ball_position)


func process_ball(ball_position: Vector3, radius: float, shot_id: int) -> bool:
	_sync_detector_geometry()
	return detector.process_ball(ball_position, radius, shot_id) if detector else false


func set_level_state_name(state_name: String) -> void:
	if detector:
		detector.set_level_state_name(state_name)


func is_ball_fully_in_goal(ball_position: Vector3, radius: float) -> bool:
	_sync_detector_geometry()
	return detector.is_ball_fully_in_goal(ball_position, radius) if detector else false


func geometry_matches_detector() -> bool:
	if not detector:
		return false
	return (
		is_equal_approx(detector.goal_line_z, global_position.z)
		and is_equal_approx(detector.goal_center_x, global_position.x)
		and is_equal_approx(detector.post_half_width, opening_half_width)
		and is_equal_approx(detector.crossbar_height, crossbar_height)
		and is_equal_approx(detector.interior_depth, interior_depth)
		and is_equal_approx(detector.ball_radius, ball_radius)
	)


func _on_detector_goal_scored() -> void:
	goal_scored.emit(self)


func _sync_geometry() -> void:
	_sync_frame_visuals()
	_sync_net_visuals()
	_sync_detector_helpers()
	if detector:
		detector.debug_goal_detection = debug_goal_detection
		detector.show_debug_volumes = show_debug_volumes
		_sync_detector_geometry()


func _sync_detector_geometry() -> void:
	if not detector:
		return
	detector.sync_geometry(
		global_position.z,
		global_position.x,
		opening_half_width,
		crossbar_height,
		interior_depth,
		ball_radius
	)


func _sync_frame_visuals() -> void:
	var post_center_y := crossbar_height * 0.5
	var post_center_x := opening_half_width + post_radius
	_set_child_position("LeftPost", Vector3(-post_center_x, post_center_y, 0.0))
	_set_child_position("RightPost", Vector3(post_center_x, post_center_y, 0.0))
	_set_child_position("Crossbar", Vector3(0.0, crossbar_height + post_radius * 0.5, 0.0))
	_set_cylinder_mesh_height("LeftPost/MeshInstance3D", crossbar_height)
	_set_cylinder_mesh_height("RightPost/MeshInstance3D", crossbar_height)
	_set_cylinder_shape_height("LeftPost/CollisionShape3D", crossbar_height)
	_set_cylinder_shape_height("RightPost/CollisionShape3D", crossbar_height)
	_set_box_mesh_size(
		"Crossbar/MeshInstance3D",
		Vector3(opening_half_width * 2.0 + post_radius * 2.0, post_radius, post_radius)
	)
	_set_box_shape_size(
		"Crossbar/CollisionShape3D",
		Vector3(opening_half_width * 2.0 + post_radius * 2.0, post_radius, post_radius)
	)


func _sync_net_visuals() -> void:
	var full_width := opening_half_width * 2.0
	var center_y := crossbar_height * 0.5
	_set_child_position("NetLeftSide", Vector3(-opening_half_width - 0.5, center_y, -interior_depth * 0.5))
	_set_child_position("NetRightSide", Vector3(opening_half_width + 0.5, center_y, -interior_depth * 0.5))
	_set_child_position("NetRear", Vector3(0.0, center_y, -interior_depth + 0.04))
	_set_child_position("NetFloor", Vector3(0.0, 0.03, -interior_depth * 0.5))
	_set_child_position("LeftRearSupport", Vector3(-opening_half_width - post_radius, center_y * 0.5, -interior_depth))
	_set_child_position("RightRearSupport", Vector3(opening_half_width + post_radius, center_y * 0.5, -interior_depth))
	_set_child_position("RearTopBar", Vector3(0.0, crossbar_height * 0.69, -interior_depth))
	_set_box_mesh_size("NetLeftSide", Vector3(0.08, crossbar_height, interior_depth))
	_set_box_mesh_size("NetRightSide", Vector3(0.08, crossbar_height, interior_depth))
	_set_box_mesh_size("NetTop", Vector3(full_width, 0.08, interior_depth + 0.4))
	_set_box_mesh_size("NetRear", Vector3(full_width, crossbar_height, 0.08))
	_set_box_mesh_size("NetFloor", Vector3(full_width, 0.06, interior_depth))
	_set_box_mesh_size("RearTopBar", Vector3(full_width + post_radius * 2.0, 0.14, 0.14))


func _sync_detector_helpers() -> void:
	var full_width := opening_half_width * 2.0
	var center_y := crossbar_height * 0.5
	_set_child_position("GoalDetection/GoalMouthTrigger", Vector3(0.0, center_y, 0.0))
	_set_child_position(
		"GoalDetection/GoalInteriorTrigger",
		Vector3(0.0, center_y, -interior_depth * 0.5)
	)
	_set_child_position("GoalDetection/DebugMouthVisual", Vector3(0.0, center_y, 0.0))
	_set_child_position(
		"GoalDetection/DebugInteriorVisual",
		Vector3(0.0, center_y, -interior_depth * 0.5)
	)
	_set_box_shape_size(
		"GoalDetection/GoalMouthTrigger/CollisionShape3D",
		Vector3(full_width, crossbar_height, mouth_depth)
	)
	_set_box_shape_size(
		"GoalDetection/GoalInteriorTrigger/CollisionShape3D",
		Vector3(full_width, crossbar_height, interior_depth)
	)
	_set_box_mesh_size(
		"GoalDetection/DebugMouthVisual",
		Vector3(full_width, crossbar_height, mouth_depth)
	)
	_set_box_mesh_size(
		"GoalDetection/DebugInteriorVisual",
		Vector3(full_width, crossbar_height, interior_depth)
	)


func _set_child_position(path: NodePath, local_position: Vector3) -> void:
	var child := get_node_or_null(path) as Node3D
	if child:
		child.position = local_position


func _set_box_mesh_size(path: NodePath, size: Vector3) -> void:
	var mesh_instance := get_node_or_null(path) as MeshInstance3D
	if not mesh_instance:
		return
	var box_mesh := mesh_instance.mesh as BoxMesh
	if not box_mesh:
		return
	if not box_mesh.resource_local_to_scene:
		box_mesh = box_mesh.duplicate() as BoxMesh
		box_mesh.resource_local_to_scene = true
		mesh_instance.mesh = box_mesh
	box_mesh.size = size


func _set_box_shape_size(path: NodePath, size: Vector3) -> void:
	var collision_shape := get_node_or_null(path) as CollisionShape3D
	if not collision_shape:
		return
	var box_shape := collision_shape.shape as BoxShape3D
	if not box_shape:
		return
	if not box_shape.resource_local_to_scene:
		box_shape = box_shape.duplicate() as BoxShape3D
		box_shape.resource_local_to_scene = true
		collision_shape.shape = box_shape
	box_shape.size = size


func _set_cylinder_mesh_height(path: NodePath, height: float) -> void:
	var mesh_instance := get_node_or_null(path) as MeshInstance3D
	if not mesh_instance:
		return
	var cylinder_mesh := mesh_instance.mesh as CylinderMesh
	if not cylinder_mesh:
		return
	if not cylinder_mesh.resource_local_to_scene:
		cylinder_mesh = cylinder_mesh.duplicate() as CylinderMesh
		cylinder_mesh.resource_local_to_scene = true
		mesh_instance.mesh = cylinder_mesh
	cylinder_mesh.height = height


func _set_cylinder_shape_height(path: NodePath, height: float) -> void:
	var collision_shape := get_node_or_null(path) as CollisionShape3D
	if not collision_shape:
		return
	var cylinder_shape := collision_shape.shape as CylinderShape3D
	if not cylinder_shape:
		return
	if not cylinder_shape.resource_local_to_scene:
		cylinder_shape = cylinder_shape.duplicate() as CylinderShape3D
		cylinder_shape.resource_local_to_scene = true
		collision_shape.shape = cylinder_shape
	cylinder_shape.height = height
