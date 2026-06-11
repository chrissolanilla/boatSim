extends RigidBody3D
class_name BoatController

@export var control_enabled: bool = false
@export var water_path: NodePath

@export_group("Mass")
@export_range(1.0, 100000.0) var hull_mass: float = 1800.0
@export var hull_center_of_mass_local: Vector3 = Vector3(0.0, 0.35, 0.0)
@export var weight_boxes: Array[BoatWeightBox] = []

@export_group("Drive")
@export_range(0.0, 100000.0) var engine_force: float = 14000.0
@export_range(0.1, 20.0) var acceleration: float = 3.0
@export_range(0.0, 20000.0) var steering_strength: float = 2400.0
@export_range(0.1, 20.0) var turn_smoothing: float = 4.0

@export_group("Water")
@export_range(0.0, 100.0) var drag: float = 1.2
@export_range(0.0, 100.0) var angular_drag: float = 2.5
@export_range(0.0, 50000.0) var buoyancy_strength: float = 9000.0
@export_range(0.01, 5.0) var max_submersion_depth: float = 1.5
@export_range(0.0, 100.0) var buoyancy_damping: float = 8.0
@export var buoyancy_points: Array[Vector3] = [
	Vector3(-1.25, -0.55, -2.6),
	Vector3(1.25, -0.55, -2.6),
	Vector3(-1.25, -0.55, 2.2),
	Vector3(1.25, -0.55, 2.2),
	Vector3(0.0, -0.4, 0.0),
]

@onready var camera_3d: Camera3D = $Camera3D

var water_manager: WaterManager
var throttle_target: float = 0.0
var steering_target: float = 0.0
var throttle_input: float = 0.0
var steering_input: float = 0.0
var wake_emit_timer: float = 0.0


func _ready() -> void:
	_ensure_default_weight_boxes()
	_resolve_water_manager()
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	can_sleep = false
	continuous_cd = true
	linear_damp = 0.0
	angular_damp = 0.0
	_update_mass_properties()
	set_control_enabled(control_enabled)


func _physics_process(delta: float) -> void:
	_resolve_water_manager()
	_update_input_targets(delta)
	_update_mass_properties()
	_emit_wake_if_needed(delta)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not water_manager:
		return

	var water_state := _apply_buoyancy(state)
	_apply_engine_force(state, water_state)
	_apply_drag_forces(state, water_state)


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if camera_3d:
		camera_3d.current = enabled


func _update_input_targets(delta: float) -> void:
	if control_enabled:
		throttle_target = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
		steering_target = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	else:
		throttle_target = 0.0
		steering_target = 0.0

	throttle_input = move_toward(throttle_input, throttle_target, acceleration * delta)
	steering_input = move_toward(steering_input, steering_target, turn_smoothing * delta)


func _apply_buoyancy(state: PhysicsDirectBodyState3D) -> Dictionary:
	var sample_count := 0
	var submerged_points := 0
	var average_slip := 1.0
	var average_turbulence := 0.0
	var average_wake := 0.0

	for local_point in buoyancy_points:
		sample_count += 1
		var world_point := global_transform * local_point
		var point_state := water_manager.get_water_state_at_position(world_point)
		var surface_height: float = point_state["surface_height"]
		var depth := surface_height - world_point.y

		average_slip = min(average_slip, float(point_state["slip_multiplier"]))
		average_turbulence += float(point_state["turbulence"])
		average_wake += float(point_state["wake_strength"])

		if depth <= 0.0:
			continue

		submerged_points += 1
		var clamped_depth := min(depth, max_submersion_depth)
		var normal: Vector3 = point_state["normal"]
		var point_velocity := state.linear_velocity + state.angular_velocity.cross(world_point - state.transform.origin)
		var buoyancy_force := normal * buoyancy_strength * clamped_depth
		var damping_force := -point_velocity * buoyancy_damping * clamped_depth
		state.apply_force(buoyancy_force + damping_force, world_point - state.transform.origin)

	var submerged_ratio := 0.0
	if sample_count > 0:
		submerged_ratio = float(submerged_points) / float(sample_count)
		average_turbulence /= float(sample_count)
		average_wake /= float(sample_count)

	return {
		"submerged_ratio": submerged_ratio,
		"slip_multiplier": average_slip,
		"turbulence": average_turbulence,
		"wake_strength": average_wake,
	}


func _apply_engine_force(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	if abs(throttle_input) <= 0.001:
		return

	var submerged_ratio: float = water_state["submerged_ratio"]
	if submerged_ratio <= 0.0:
		return

	var forward := -global_transform.basis.z.normalized()
	var slip_multiplier: float = water_state["slip_multiplier"]
	var thrust_force := engine_force * throttle_input * submerged_ratio * slip_multiplier
	state.apply_central_force(forward * thrust_force)

	var forward_speed := state.linear_velocity.dot(forward)
	var steering_scale := clamp(abs(forward_speed) / 10.0, 0.2, 1.5)
	state.apply_torque(Vector3.UP * steering_strength * steering_input * steering_scale)


func _apply_drag_forces(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	var submersion_scale := max(float(water_state["submerged_ratio"]), 0.15)
	var local_velocity := global_transform.basis.inverse() * state.linear_velocity
	var drag_local := Vector3(
		-local_velocity.x * abs(local_velocity.x) * drag * 1.4,
		-local_velocity.y * abs(local_velocity.y) * drag * 0.6,
		-local_velocity.z * abs(local_velocity.z) * drag
	) * submersion_scale
	state.apply_central_force(global_transform.basis * drag_local)
	state.apply_torque(-state.angular_velocity * angular_drag * submersion_scale)


func _emit_wake_if_needed(delta: float) -> void:
	wake_emit_timer -= delta
	if wake_emit_timer > 0.0:
		return

	if not water_manager or not water_manager.interaction_grid:
		return

	var speed := linear_velocity.length()
	if speed < 2.0:
		return

	wake_emit_timer = 0.15
	var wake_position := global_position + global_transform.basis.z * 3.0
	var direction_velocity := linear_velocity.normalized() * min(speed * 0.08, 6.0)
	water_manager.interaction_grid.add_disturbance(
		wake_position,
		min(speed * 0.03, 4.0),
		8.0,
		direction_velocity,
		min(speed * 0.015, 1.0),
		min(speed * 0.02, 1.5),
		0.85
	)


func _resolve_water_manager() -> void:
	if water_manager:
		return

	if water_path != NodePath():
		water_manager = get_node_or_null(water_path) as WaterManager

	if not water_manager:
		water_manager = get_parent().get_node_or_null("Water") as WaterManager


func _update_mass_properties() -> void:
	var total_mass := max(hull_mass, 1.0)
	var weighted_position := hull_center_of_mass_local * total_mass

	for weight_box in weight_boxes:
		if not weight_box or not weight_box.enabled or weight_box.mass <= 0.0:
			continue

		total_mass += weight_box.mass
		weighted_position += weight_box.local_position * weight_box.mass

	mass = total_mass
	center_of_mass = weighted_position / total_mass


func _ensure_default_weight_boxes() -> void:
	if not weight_boxes.is_empty():
		return

	var port_box := BoatWeightBox.new()
	port_box.name = "Port Ballast"
	port_box.mass = 0.0
	port_box.local_position = Vector3(-0.75, 0.2, 0.4)

	var starboard_box := BoatWeightBox.new()
	starboard_box.name = "Starboard Ballast"
	starboard_box.mass = 0.0
	starboard_box.local_position = Vector3(0.75, 0.2, 0.4)

	var bow_box := BoatWeightBox.new()
	bow_box.name = "Bow Ballast"
	bow_box.mass = 0.0
	bow_box.local_position = Vector3(0.0, 0.15, -1.5)

	weight_boxes = [port_box, starboard_box, bow_box]
