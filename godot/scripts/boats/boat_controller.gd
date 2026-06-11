extends RigidBody3D
class_name BoatController

@export var control_enabled: bool = false
@export var water_path: NodePath

@export_group("Mass")
@export_range(1.0, 100000.0) var hull_mass: float = 1800.0
@export var hull_center_of_mass_local: Vector3 = Vector3(0.0, -1.0, 0.0)
@export var weight_boxes: Array[BoatWeightBox] = []

@export_group("Drive")
@export_range(0.0, 100000.0) var engine_force: float = 14000.0
@export_range(0.1, 20.0) var acceleration: float = 3.0
@export_range(0.0, 20000.0) var steering_strength: float = 2400.0
@export_range(0.1, 20.0) var turn_smoothing: float = 4.0

@export_group("Water")
@export_range(0.0, 100.0) var drag: float = 4.0
@export_range(0.0, 100.0) var angular_drag: float = 18.0
@export_range(0.0, 50000.0) var buoyancy_strength: float = 14000.0
@export_range(0.01, 5.0) var max_submersion_depth: float = 1.3
@export_range(0.0, 100.0) var buoyancy_damping: float = 28.0
@export_range(0.0, 1.0) var buoyancy_normal_influence: float = 0.0
@export var buoyancy_points: Array[Vector3] = [
	Vector3(-1.65, -0.72, -2.45),
	Vector3(1.65, -0.72, -2.45),
	Vector3(-1.65, -0.72, 2.45),
	Vector3(1.65, -0.72, 2.45),
	Vector3(0.0, -0.85, 0.0),
]

@export_group("Stability")
@export_range(0.0, 10000.0) var upright_stiffness: float = 8000.0
@export_range(0.0, 1000.0) var upright_damping: float = 700.0

@export_group("Camera")
@export_range(1.0, 50.0) var camera_distance: float = 18.0
@export_range(1.0, 20.0) var camera_height: float = 6.5
@export_range(0.0, 20.0) var camera_look_height: float = 1.8
@export_range(0.0, 20.0) var camera_look_ahead: float = 0.5
@export_range(0.1, 20.0) var camera_position_smoothing: float = 4.5
@export_range(0.1, 20.0) var camera_rotation_smoothing: float = 5.0
@export_range(0.0001, 0.02) var camera_mouse_sensitivity: float = 0.005
@export_range(-85.0, 0.0) var camera_min_pitch_degrees: float = -35.0
@export_range(0.0, 85.0) var camera_max_pitch_degrees: float = 20.0

@export_group("Debug")
@export_range(1.0, 100.0) var reset_height_above_water: float = 2.5
@export_range(1.0, 100.0) var auto_reset_depth_margin: float = 18.0
@export_range(0.5, 10.0) var auto_reset_upside_down_time: float = 2.5

@onready var camera_3d: Camera3D = $Camera3D

var water_manager: WaterManager
var throttle_target: float = 0.0
var steering_target: float = 0.0
var throttle_input: float = 0.0
var steering_input: float = 0.0
var wake_emit_timer: float = 0.0
var spawn_position: Vector3
var spawn_yaw: float = 0.0
var upside_down_timer: float = 0.0
var camera_forward: Vector3 = Vector3.FORWARD
var camera_yaw: float = 0.0
var camera_pitch: float = deg_to_rad(-12.0)
var mouse_captured: bool = false


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
	if camera_3d:
		camera_3d.top_level = true
		camera_3d.near = 0.05
	_update_mass_properties()
	_align_camera_to_boat()
	set_control_enabled(control_enabled)


func _input(event: InputEvent) -> void:
	if control_enabled and event.is_action_pressed("ui_cancel"):
		toggle_mouse_capture()
		return

	if control_enabled and mouse_captured and event is InputEventMouseMotion:
		camera_yaw -= event.relative.x * camera_mouse_sensitivity
		camera_pitch -= event.relative.y * camera_mouse_sensitivity
		camera_pitch = clamp(camera_pitch, deg_to_rad(camera_min_pitch_degrees), deg_to_rad(camera_max_pitch_degrees))
		return

	if event.is_action_pressed("reset_boat"):
		reset_boat()


func _physics_process(delta: float) -> void:
	_resolve_water_manager()
	_update_input_targets(delta)
	_update_mass_properties()
	_update_camera(delta)
	_emit_wake_if_needed(delta)
	_check_auto_reset(delta)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not water_manager:
		return

	var water_state := _apply_buoyancy(state)
	_apply_engine_force(state, water_state)
	_apply_drag_forces(state, water_state)
	_apply_upright_stabilization(state, water_state)


func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if camera_3d:
		if enabled:
			_align_camera_to_boat()
			_snap_camera_to_chase_position()
			capture_mouse()
		else:
			release_mouse()
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
		var clamped_depth: float = min(depth, max_submersion_depth)
		var normal: Vector3 = point_state["normal"]
		var buoyancy_direction := Vector3.UP.lerp(normal, buoyancy_normal_influence).normalized()
		var point_velocity := state.linear_velocity + state.angular_velocity.cross(world_point - state.transform.origin)
		var buoyancy_force: Vector3 = buoyancy_direction * buoyancy_strength * clamped_depth
		var damping_force: Vector3 = -point_velocity * buoyancy_damping * clamped_depth
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
	var steering_scale: float = clamp(abs(forward_speed) / 10.0, 0.2, 1.5)
	state.apply_torque(Vector3.UP * steering_strength * steering_input * steering_scale)


func _apply_drag_forces(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	var submersion_scale: float = max(float(water_state["submerged_ratio"]), 0.15)
	var local_velocity := global_transform.basis.inverse() * state.linear_velocity
	var drag_local: Vector3 = Vector3(
		-local_velocity.x * abs(local_velocity.x) * drag * 1.4,
		-local_velocity.y * abs(local_velocity.y) * drag * 0.6,
		-local_velocity.z * abs(local_velocity.z) * drag
	) * submersion_scale
	state.apply_central_force(global_transform.basis * drag_local)
	state.apply_torque(-state.angular_velocity * angular_drag * submersion_scale)


func _apply_upright_stabilization(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	var submerged_ratio: float = water_state["submerged_ratio"]
	if submerged_ratio <= 0.0 or upright_stiffness <= 0.0:
		return

	var boat_up := global_transform.basis.y.normalized()
	var tilt_axis := boat_up.cross(Vector3.UP)
	var tilt_amount := tilt_axis.length()
	if tilt_amount <= 0.0001:
		return

	var corrective_axis := tilt_axis.normalized()
	var angular_velocity_along_axis := state.angular_velocity.dot(corrective_axis)
	var spring_torque := corrective_axis * (tilt_amount * upright_stiffness * submerged_ratio)
	var damping_torque := corrective_axis * (-angular_velocity_along_axis * upright_damping * submerged_ratio)
	state.apply_torque(spring_torque + damping_torque)


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
	if not camera_3d:
		return

	var orbit_basis := Basis.from_euler(Vector3(camera_pitch, camera_yaw, 0.0))
	var orbit_offset := orbit_basis * Vector3(0.0, camera_height, camera_distance)
	var target_position: Vector3 = global_position + orbit_offset
	var blend: float = clamp(camera_position_smoothing * delta, 0.0, 1.0)
	if camera_3d.global_position == Vector3.ZERO:
		camera_3d.global_position = target_position
	else:
		camera_3d.global_position = camera_3d.global_position.lerp(target_position, blend)

	var boat_forward := -global_transform.basis.z.normalized()
	var look_target: Vector3 = global_position + Vector3.UP * camera_look_height
	look_target += boat_forward * camera_look_ahead
	var target_basis: Basis = Basis.looking_at((look_target - camera_3d.global_position).normalized(), Vector3.UP, true)
	var rotation_blend: float = clamp(camera_rotation_smoothing * delta, 0.0, 1.0)
	camera_3d.global_basis = camera_3d.global_basis.slerp(target_basis, rotation_blend)


func _snap_camera_to_chase_position() -> void:
	if not camera_3d:
		return

	var orbit_basis := Basis.from_euler(Vector3(camera_pitch, camera_yaw, 0.0))
	var orbit_offset := orbit_basis * Vector3(0.0, camera_height, camera_distance)
	var target_position: Vector3 = global_position + orbit_offset
	var boat_forward := -global_transform.basis.z.normalized()
	var look_target: Vector3 = global_position + Vector3.UP * camera_look_height
	look_target += boat_forward * camera_look_ahead
	camera_3d.global_position = target_position
	camera_3d.look_at(look_target, Vector3.UP)


func _align_camera_to_boat() -> void:
	var boat_forward := -global_transform.basis.z
	boat_forward.y = 0.0
	if boat_forward.length_squared() <= 0.0001:
		return

	boat_forward = boat_forward.normalized()
	camera_forward = boat_forward
	camera_yaw = atan2(-boat_forward.x, -boat_forward.z)


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
	if not water_manager:
		return

	var water_height := water_manager.get_water_height_at_position(global_position)
	if global_position.y < water_height - auto_reset_depth_margin:
		reset_boat(true)
		return

	if global_transform.basis.y.dot(Vector3.UP) < -0.2:
		upside_down_timer += delta
		if upside_down_timer >= auto_reset_upside_down_time:
			reset_boat()
	else:
		upside_down_timer = 0.0


func reset_boat(use_spawn_position: bool = false) -> void:
	_resolve_water_manager()
	var reset_position: Vector3 = spawn_position
	if not use_spawn_position:
		reset_position = global_position
	if water_manager:
		reset_position.y = water_manager.get_water_height_at_position(reset_position) + reset_height_above_water
	else:
		reset_position.y = max(reset_position.y, reset_height_above_water)

	var current_forward := -global_transform.basis.z
	current_forward.y = 0.0
	var yaw := spawn_yaw
	if current_forward.length_squared() > 0.0001:
		yaw = atan2(-current_forward.x, -current_forward.z)

	global_position = reset_position
	rotation = Vector3(0.0, yaw, 0.0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	upside_down_timer = 0.0


func _resolve_water_manager() -> void:
	if water_manager:
		return

	if water_path != NodePath():
		water_manager = get_node_or_null(water_path) as WaterManager

	if not water_manager:
		water_manager = get_parent().get_node_or_null("Water") as WaterManager


func _update_mass_properties() -> void:
	var total_mass: float = max(hull_mass, 1.0)
	var weighted_position: Vector3 = hull_center_of_mass_local * total_mass

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
