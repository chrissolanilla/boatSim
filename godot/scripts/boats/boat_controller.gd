extends RigidBody3D
class_name BoatController

@export var control_enabled: bool = false
@export var water_path: NodePath

@export_group("Mass")
@export_range(1.0, 100000.0) var hull_mass: float = 1800.0
@export var hull_center_of_mass_local: Vector3 = Vector3(0.0, -0.9, 0.0)
@export var weight_boxes: Array[BoatWeightBox] = []

@export_group("Drive")
@export_range(0.0, 100000.0) var engine_force: float = 16000.0
@export_range(0.1, 20.0) var acceleration: float = 3.0
@export_range(0.0, 20000.0) var steering_strength: float = 2200.0
@export_range(0.1, 20.0) var turn_smoothing: float = 4.0
@export_range(0.0, 1.0) var reverse_power_scale: float = 0.35
@export_range(0.0, 50.0) var min_steering_speed: float = 1.0
@export_range(1.0, 100.0) var full_steering_speed: float = 18.0

@export_group("Water / Buoyancy")
@export_range(0.1, 5.0) var flotation_multiplier: float = 1.35
@export_range(0.01, 5.0) var max_submersion_depth: float = 1.25
@export_range(0.0, 100.0) var buoyancy_damping: float = 10.0
@export_range(0.0, 1.0) var buoyancy_normal_influence: float = 0.0
@export_range(0.0, 100.0) var drag: float = 2.5
@export_range(0.0, 100.0) var side_drag_multiplier: float = 2.8
@export_range(0.0, 100.0) var angular_drag: float = 12.0

@export var buoyancy_points: Array[Vector3] = [
	Vector3(-1.65, -0.65, -2.45),
	Vector3(1.65, -0.65, -2.45),
	Vector3(-1.65, -0.65, 2.45),
	Vector3(1.65, -0.65, 2.45),
	Vector3(0.0, -0.75, 0.0)
]

@export_group("Stability")
@export_range(0.0, 10000.0) var upright_stiffness: float = 2800.0
@export_range(0.0, 1000.0) var upright_damping: float = 320.0
@export_range(0.0, 50.0) var max_angular_velocity: float = 6.0
@export_range(0.0, 1.0) var upright_only_when_submerged_ratio: float = 0.10

@export_group("Camera")
@export_range(1.0, 60.0) var camera_distance: float = 18.0
@export_range(1.0, 30.0) var camera_height: float = 7.0
@export_range(0.0, 20.0) var camera_look_height: float = 1.6
@export_range(0.0, 30.0) var camera_look_ahead: float = 4.0
@export_range(0.1, 30.0) var camera_position_smoothing: float = 7.0
@export_range(0.1, 30.0) var camera_rotation_smoothing: float = 9.0
@export_range(0.0001, 0.02) var camera_mouse_sensitivity: float = 0.004
@export_range(-85.0, 0.0) var camera_min_pitch_degrees: float = -35.0
@export_range(0.0, 85.0) var camera_max_pitch_degrees: float = 18.0
@export var camera_follow_boat_yaw_when_no_mouse: bool = true

@export_group("Debug")
@export_range(1.0, 100.0) var reset_height_above_water: float = 2.5
@export_range(1.0, 100.0) var auto_reset_depth_margin: float = 18.0
@export_range(0.5, 10.0) var auto_reset_upside_down_time: float = 2.5
@export var print_control_mode: bool = true

@onready var camera_3d: Camera3D = get_node_or_null("Camera3D") as Camera3D

var water_manager: WaterManager = null

var throttle_target: float = 0.0
var steering_target: float = 0.0
var throttle_input: float = 0.0
var steering_input: float = 0.0

var wake_emit_timer: float = 0.0
var spawn_position: Vector3 = Vector3.ZERO
var spawn_yaw: float = 0.0
var upside_down_timer: float = 0.0

var camera_yaw: float = 0.0
var camera_pitch: float = deg_to_rad(-14.0)
var mouse_captured: bool = false
var camera_has_snapped: bool = false


func _ready() -> void:
	_ensure_default_weight_boxes()
	_resolve_water_manager()

	spawn_position = global_position
	spawn_yaw = rotation.y

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	can_sleep = false
	continuous_cd = true

	linear_damp = 0.0
	angular_damp = 0.0

	if camera_3d != null:
		camera_3d.top_level = true
		camera_3d.near = 0.05
		camera_3d.current = false

	_update_mass_properties()
	_align_camera_yaw_to_boat()
	_snap_camera_to_chase_position()
	set_control_enabled(control_enabled)


func _input(event: InputEvent) -> void:
	if control_enabled and event.is_action_pressed("ui_cancel"):
		toggle_mouse_capture()
		return

	if control_enabled and mouse_captured and event is InputEventMouseMotion:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		camera_yaw -= mouse_event.relative.x * camera_mouse_sensitivity
		camera_pitch += mouse_event.relative.y * camera_mouse_sensitivity
		camera_pitch = clamp(
			camera_pitch,
			deg_to_rad(camera_min_pitch_degrees),
			deg_to_rad(camera_max_pitch_degrees)
		)
		return

	if _event_is_action_pressed_safe(event, "reset_boat"):
		reset_boat(false)


func _process(delta: float) -> void:
	if control_enabled:
		_update_camera(delta)


func _physics_process(delta: float) -> void:
	_resolve_water_manager()
	_update_input_targets(delta)
	_update_mass_properties()
	_emit_wake_if_needed(delta)
	_check_auto_reset(delta)
	_clamp_extreme_angular_velocity()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if water_manager == null:
		return

	var water_state: Dictionary = _apply_buoyancy(state)
	_apply_engine_force(state, water_state)
	_apply_drag_forces(state, water_state)
	_apply_upright_stabilization(state, water_state)
	_apply_angular_velocity_clamp_to_state(state)


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled

	if camera_3d != null:
		if enabled:
			_align_camera_yaw_to_boat()
			_snap_camera_to_chase_position()
			capture_mouse()
			camera_3d.current = true
			camera_has_snapped = true
			if print_control_mode:
				print("Control mode: Boat")
		else:
			release_mouse()
			camera_3d.current = false
			if print_control_mode:
				print("Control mode: Player")


func _update_input_targets(delta: float) -> void:
	if control_enabled:
		throttle_target = _get_action_strength_safe("move_forward") - _get_action_strength_safe("move_backward")
		steering_target = _get_action_strength_safe("move_left") - _get_action_strength_safe("move_right")
	else:
		throttle_target = 0.0
		steering_target = 0.0

	throttle_input = move_toward(throttle_input, throttle_target, acceleration * delta)
	steering_input = move_toward(steering_input, steering_target, turn_smoothing * delta)


func _apply_buoyancy(state: PhysicsDirectBodyState3D) -> Dictionary:
	var sample_count: int = buoyancy_points.size()
	var submerged_points: int = 0
	var average_slip: float = 1.0
	var average_turbulence: float = 0.0
	var average_wake: float = 0.0

	if sample_count <= 0:
		return {
			"submerged_ratio": 0.0,
			"slip_multiplier": 1.0,
			"turbulence": 0.0,
			"wake_strength": 0.0
		}

	var gravity_strength: float = abs(ProjectSettings.get_setting("physics/3d/default_gravity", 9.81))
	var total_required_lift: float = mass * gravity_strength * flotation_multiplier
	var lift_per_point: float = total_required_lift / float(sample_count)

	for local_point in buoyancy_points:
		var world_point: Vector3 = state.transform * local_point
		var point_state: Dictionary = water_manager.get_water_state_at_position(world_point)

		var surface_height: float = float(point_state.get("surface_height", 0.0))
		var depth: float = surface_height - world_point.y

		average_slip = min(average_slip, float(point_state.get("slip_multiplier", 1.0)))
		average_turbulence += float(point_state.get("turbulence", 0.0))
		average_wake += float(point_state.get("wake_strength", 0.0))

		if depth <= 0.0:
			continue

		submerged_points += 1

		var clamped_depth: float = min(depth, max_submersion_depth)
		var submersion_ratio: float = clamp(clamped_depth / max_submersion_depth, 0.0, 1.0)

		var normal: Vector3 = point_state.get("normal", Vector3.UP)
		var buoyancy_direction: Vector3 = Vector3.UP.lerp(normal, buoyancy_normal_influence).normalized()

		var lever_arm: Vector3 = world_point - state.transform.origin
		var point_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(lever_arm)

		var upward_force: Vector3 = buoyancy_direction * lift_per_point * submersion_ratio

		var vertical_velocity: float = point_velocity.dot(Vector3.UP)
		var damping_force: Vector3 = Vector3.UP * (-vertical_velocity * buoyancy_damping * mass / float(sample_count) * submersion_ratio)

		state.apply_force(upward_force + damping_force, lever_arm)

	var submerged_ratio: float = float(submerged_points) / float(sample_count)
	average_turbulence /= float(sample_count)
	average_wake /= float(sample_count)

	return {
		"submerged_ratio": submerged_ratio,
		"slip_multiplier": average_slip,
		"turbulence": average_turbulence,
		"wake_strength": average_wake
	}


func _apply_engine_force(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	if abs(throttle_input) <= 0.001:
		return

	var submerged_ratio: float = float(water_state.get("submerged_ratio", 0.0))
	if submerged_ratio <= 0.0:
		return

	var forward: Vector3 = _get_flat_forward_from_basis(state.transform.basis)
	if forward.length_squared() <= 0.0001:
		return

	var slip_multiplier: float = float(water_state.get("slip_multiplier", 1.0))

	var throttle_scale: float = 1.0
	if throttle_input < 0.0:
		throttle_scale = reverse_power_scale

	var thrust_force: float = engine_force * throttle_input * throttle_scale * submerged_ratio * slip_multiplier
	state.apply_central_force(forward * thrust_force)

	var forward_speed: float = state.linear_velocity.dot(forward)
	var speed_abs: float = abs(forward_speed)

	var steering_speed_scale: float = inverse_lerp(min_steering_speed, full_steering_speed, speed_abs)
	steering_speed_scale = clamp(steering_speed_scale, 0.15, 1.0)

	var steering_sign: float = 1.0
	if forward_speed < -0.5:
		steering_sign = -1.0

	var yaw_torque: float = steering_strength * steering_input * steering_speed_scale * steering_sign
	state.apply_torque(Vector3.UP * yaw_torque)


func _apply_drag_forces(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	var submerged_ratio: float = float(water_state.get("submerged_ratio", 0.0))
	var submersion_scale: float = max(submerged_ratio, 0.08)

	var basis: Basis = state.transform.basis
	var local_velocity: Vector3 = basis.inverse() * state.linear_velocity

	var drag_local: Vector3 = Vector3(
		-local_velocity.x * abs(local_velocity.x) * drag * side_drag_multiplier,
		-local_velocity.y * abs(local_velocity.y) * drag * 0.35,
		-local_velocity.z * abs(local_velocity.z) * drag
	) * submersion_scale

	state.apply_central_force(basis * drag_local)

	var local_angular: Vector3 = basis.inverse() * state.angular_velocity
	var local_angular_drag: Vector3 = Vector3(
		-local_angular.x * angular_drag * 1.4,
		-local_angular.y * angular_drag * 0.45,
		-local_angular.z * angular_drag * 1.4
	) * submersion_scale

	state.apply_torque(basis * local_angular_drag)


func _apply_upright_stabilization(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	var submerged_ratio: float = float(water_state.get("submerged_ratio", 0.0))
	if submerged_ratio < upright_only_when_submerged_ratio:
		return

	if upright_stiffness <= 0.0:
		return

	var boat_up: Vector3 = state.transform.basis.y.normalized()
	var tilt_axis: Vector3 = boat_up.cross(Vector3.UP)
	var tilt_amount: float = tilt_axis.length()

	if tilt_amount <= 0.0001:
		return

	var corrective_axis: Vector3 = tilt_axis.normalized()
	var angular_velocity_along_axis: float = state.angular_velocity.dot(corrective_axis)

	var spring_torque: Vector3 = corrective_axis * (tilt_amount * upright_stiffness * submerged_ratio)
	var damping_torque: Vector3 = corrective_axis * (-angular_velocity_along_axis * upright_damping * submerged_ratio)

	state.apply_torque(spring_torque + damping_torque)


func _emit_wake_if_needed(delta: float) -> void:
	wake_emit_timer -= delta
	if wake_emit_timer > 0.0:
		return

	if water_manager == null:
		return

	if water_manager.interaction_grid == null:
		return

	var speed: float = linear_velocity.length()
	if speed < 2.0:
		return

	wake_emit_timer = 0.15

	var flat_forward: Vector3 = _get_flat_forward_from_basis(global_transform.basis)
	var wake_position: Vector3 = global_position - flat_forward * 3.0
	var direction_velocity: Vector3 = linear_velocity.normalized() * min(speed * 0.08, 6.0)

	water_manager.interaction_grid.add_disturbance(
		wake_position,
		min(speed * 0.03, 4.0),
		8.0,
		direction_velocity,
		min(speed * 0.015, 1.0),
		min(speed * 0.02, 1.5),
		0.85
	)


func _update_camera(delta: float) -> void:
	if camera_3d == null:
		return

	if camera_follow_boat_yaw_when_no_mouse and not mouse_captured:
		_align_camera_yaw_to_boat()

	var orbit_basis: Basis = Basis.from_euler(Vector3(camera_pitch, camera_yaw, 0.0))
	var orbit_offset: Vector3 = orbit_basis * Vector3(0.0, camera_height, camera_distance)

	var target_position: Vector3 = global_position + orbit_offset
	var position_blend: float = clamp(camera_position_smoothing * delta, 0.0, 1.0)

	if not camera_has_snapped:
		camera_3d.global_position = target_position
		camera_has_snapped = true
	else:
		camera_3d.global_position = camera_3d.global_position.lerp(target_position, position_blend)

	var flat_forward: Vector3 = _get_flat_forward_from_basis(global_transform.basis)
	if flat_forward.length_squared() <= 0.0001:
		flat_forward = Vector3.FORWARD

	var look_target: Vector3 = global_position + Vector3.UP * camera_look_height + flat_forward * camera_look_ahead
	var look_dir: Vector3 = look_target - camera_3d.global_position
	if look_dir.length_squared() <= 0.0001:
		return

	var target_basis: Basis = Basis.looking_at(look_dir.normalized(), Vector3.UP, true)
	var rotation_blend: float = clamp(camera_rotation_smoothing * delta, 0.0, 1.0)

	camera_3d.global_basis = camera_3d.global_basis.slerp(target_basis, rotation_blend)


func _snap_camera_to_chase_position() -> void:
	if camera_3d == null:
		return

	var orbit_basis: Basis = Basis.from_euler(Vector3(camera_pitch, camera_yaw, 0.0))
	var orbit_offset: Vector3 = orbit_basis * Vector3(0.0, camera_height, camera_distance)
	var target_position: Vector3 = global_position + orbit_offset

	var flat_forward: Vector3 = _get_flat_forward_from_basis(global_transform.basis)
	if flat_forward.length_squared() <= 0.0001:
		flat_forward = Vector3.FORWARD

	var look_target: Vector3 = global_position + Vector3.UP * camera_look_height + flat_forward * camera_look_ahead

	camera_3d.global_position = target_position
	camera_3d.look_at(look_target, Vector3.UP)
	camera_has_snapped = true


func _align_camera_yaw_to_boat() -> void:
	var flat_forward: Vector3 = _get_flat_forward_from_basis(global_transform.basis)
	if flat_forward.length_squared() <= 0.0001:
		return

	camera_yaw = atan2(flat_forward.x, flat_forward.z) + PI


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


func toggle_mouse_capture() -> void:
	if mouse_captured:
		release_mouse()
	else:
		capture_mouse()


func _check_auto_reset(delta: float) -> void:
	if water_manager == null:
		return

	var water_height: float = water_manager.get_water_height_at_position(global_position)

	if global_position.y < water_height - auto_reset_depth_margin:
		reset_boat(true)
		return

	if global_transform.basis.y.dot(Vector3.UP) < -0.2:
		upside_down_timer += delta
		if upside_down_timer >= auto_reset_upside_down_time:
			reset_boat(false)
	else:
		upside_down_timer = 0.0


func reset_boat(use_spawn_position: bool = false) -> void:
	_resolve_water_manager()

	var reset_position: Vector3 = global_position
	if use_spawn_position:
		reset_position = spawn_position

	if water_manager != null:
		reset_position.y = water_manager.get_water_height_at_position(reset_position) + reset_height_above_water
	else:
		reset_position.y = max(reset_position.y, reset_height_above_water)

	var yaw: float = rotation.y
	var current_forward: Vector3 = _get_flat_forward_from_basis(global_transform.basis)
	if current_forward.length_squared() > 0.0001:
		yaw = atan2(-current_forward.x, -current_forward.z)

	global_position = reset_position
	rotation = Vector3(0.0, yaw, 0.0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	upside_down_timer = 0.0

	_align_camera_yaw_to_boat()
	_snap_camera_to_chase_position()


func _resolve_water_manager() -> void:
	if water_manager != null:
		return

	if water_path != NodePath():
		water_manager = get_node_or_null(water_path) as WaterManager

	if water_manager == null:
		water_manager = get_parent().get_node_or_null("Water") as WaterManager


func _update_mass_properties() -> void:
	var total_mass: float = max(hull_mass, 1.0)
	var weighted_position: Vector3 = hull_center_of_mass_local * total_mass

	for weight_box in weight_boxes:
		if weight_box == null:
			continue

		if not weight_box.enabled:
			continue

		if weight_box.mass <= 0.0:
			continue

		total_mass += weight_box.mass
		weighted_position += weight_box.local_position * weight_box.mass

	mass = total_mass
	center_of_mass = weighted_position / total_mass


func _ensure_default_weight_boxes() -> void:
	if not weight_boxes.is_empty():
		return

	var port_box: BoatWeightBox = BoatWeightBox.new()
	port_box.name = "Port Ballast"
	port_box.mass = 0.0
	port_box.local_position = Vector3(-0.75, 0.2, 0.4)

	var starboard_box: BoatWeightBox = BoatWeightBox.new()
	starboard_box.name = "Starboard Ballast"
	starboard_box.mass = 0.0
	starboard_box.local_position = Vector3(0.75, 0.2, 0.4)

	var bow_box: BoatWeightBox = BoatWeightBox.new()
	bow_box.name = "Bow Ballast"
	bow_box.mass = 0.0
	bow_box.local_position = Vector3(0.0, 0.15, -1.5)

	weight_boxes = [port_box, starboard_box, bow_box]


func _get_flat_forward_from_basis(basis: Basis) -> Vector3:
	var forward: Vector3 = -basis.z
	forward.y = 0.0

	if forward.length_squared() <= 0.0001:
		return Vector3.ZERO

	return forward.normalized()


func _get_action_strength_safe(action_name: StringName) -> float:
	if not InputMap.has_action(action_name):
		return 0.0

	return Input.get_action_strength(action_name)


func _event_is_action_pressed_safe(event: InputEvent, action_name: StringName) -> bool:
	if not InputMap.has_action(action_name):
		return false

	return event.is_action_pressed(action_name)


func _clamp_extreme_angular_velocity() -> void:
	if max_angular_velocity <= 0.0:
		return

	if angular_velocity.length() > max_angular_velocity:
		angular_velocity = angular_velocity.normalized() * max_angular_velocity


func _apply_angular_velocity_clamp_to_state(state: PhysicsDirectBodyState3D) -> void:
	if max_angular_velocity <= 0.0:
		return

	if state.angular_velocity.length() > max_angular_velocity:
		state.angular_velocity = state.angular_velocity.normalized() * max_angular_velocity
