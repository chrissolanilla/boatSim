extends RigidBody3D
class_name BoatController

@export_group("Boat Dimensions")
@export var boat_length := 4.0
@export var boat_width := 1.5
@export var boat_height := 1.0
@export var boat_mass := 500.0

@export_group("Performance")
@export var engine_force := 16000.0
@export var acceleration := 3.0
@export var steering_strength := 2200.0
@export var turn_smoothing := 4.0
@export var reverse_power_scale := 0.35
@export var min_steering_speed := 1.0
@export var full_steering_speed := 18.0

@export_group("Wind Interaction")
@export var wind_exposed_area := 3.0
@export var wind_side_area := 6.0
@export var wind_force_multiplier := 1.5
@export var wind_torque_multiplier := 2.0

@export var control_enabled: bool = false
var buoyancy_component: BuoyancyComponent = null

var wind_system: Node3D
var throttle_input: float = 0.0
var steering_input: float = 0.0
var throttle_target: float = 0.0
var steering_target: float = 0.0

func _ready():
	mass = boat_mass
	_ensure_collision_shape()
	
	var volume = boat_length * boat_width * boat_height * 0.4
	set_meta("volume", volume)
	gravity_scale = 1.0
	
	if not buoyancy_component:
		buoyancy_component = BuoyancyComponent.new()
		buoyancy_component.name = "BuoyancyComponent"
		buoyancy_component.object_width = boat_width
		buoyancy_component.object_height = boat_height
		buoyancy_component.object_length = boat_length
		add_child(buoyancy_component)
	
	wind_system = get_tree().get_first_node_in_group("wind_system")
	set_control_enabled(control_enabled)

func _ensure_collision_shape():
	for child in get_children():
		if child is CollisionShape3D:
			return
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(boat_width, boat_height, boat_length)
	collision.shape = box_shape
	add_child(collision)

func _exit_tree():
	pass

func set_control_enabled(enabled: bool):
	control_enabled = enabled

func is_control_enabled() -> bool:
	return control_enabled

func _physics_process(delta):
	_update_input_targets(delta)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	if not buoyancy_component:
		return
	
	var water_state = buoyancy_component.apply_buoyancy(state)
	buoyancy_component.apply_drag_forces(state, water_state)
	buoyancy_component.apply_upright_stabilization(state, water_state)
	
	_apply_engine_force(state, water_state)
	_apply_wind_forces(state)
	
	buoyancy_component.clamp_angular_velocity(state)

func _update_input_targets(delta):
	if control_enabled:
		throttle_target = Input.get_axis("move_backward", "move_forward")
		steering_target = Input.get_axis("turn_right", "turn_left")
	else:
		throttle_target = 0.0
		steering_target = 0.0
	
	throttle_input = move_toward(throttle_input, throttle_target, acceleration * delta)
	steering_input = move_toward(steering_input, steering_target, turn_smoothing * delta)

func _apply_engine_force(state: PhysicsDirectBodyState3D, water_state: Dictionary):
	if abs(throttle_input) <= 0.001:
		return
	
	var submerged_ratio = float(water_state.get("submerged_ratio", 0.0))
	if submerged_ratio <= 0.0:
		return
	
	var forward = -state.transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return
	forward = forward.normalized()
	
	var slip_multiplier = float(water_state.get("slip_multiplier", 1.0))
	
	var throttle_scale = 1.0
	if throttle_input < 0.0:
		throttle_scale = reverse_power_scale
	
	var thrust = engine_force * throttle_input * throttle_scale * submerged_ratio * slip_multiplier
	state.apply_central_force(forward * thrust)
	
	var forward_speed = state.linear_velocity.dot(forward)
	var speed_abs = abs(forward_speed)
	
	var steering_speed_scale = inverse_lerp(min_steering_speed, full_steering_speed, speed_abs)
	steering_speed_scale = clamp(steering_speed_scale, 0.15, 1.0)
	
	var steering_sign = 1.0
	if forward_speed < -0.5:
		steering_sign = -1.0
	
	var yaw_torque = steering_strength * steering_input * steering_speed_scale * steering_sign
	state.apply_torque(Vector3.UP * yaw_torque)

func _apply_wind_forces(state: PhysicsDirectBodyState3D):
	if not wind_system or not wind_system.has_method("get_wind_at_position"):
		return
	
	var wind = wind_system.get_wind_at_position(global_position)
	var wind_strength = wind.length()
	
	if wind_strength < 0.5:
		return
	
	var relative_wind = wind - state.linear_velocity
	var boat_forward = -state.transform.basis.z
	var boat_right = state.transform.basis.x
	
	var wind_forward = relative_wind.dot(boat_forward)
	var wind_side = relative_wind.dot(boat_right)
	
	var frontal_drag = -boat_forward * wind_forward * abs(wind_forward) * wind_exposed_area * 0.5 * 1.225 * wind_force_multiplier
	var side_drag = -boat_right * wind_side * abs(wind_side) * wind_side_area * 0.5 * 1.225 * wind_force_multiplier
	
	state.apply_central_force(frontal_drag + side_drag)
	
	if abs(wind_side) > 0.5:
		var heeling_torque = boat_forward * wind_side * wind_strength * wind_torque_multiplier * 0.02
		state.apply_torque(heeling_torque)
	
	var wind_drift = Vector3(wind.x, 0, wind.z) * wind_strength * 2.0 * wind_force_multiplier
	state.apply_central_force(wind_drift)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
