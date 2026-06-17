extends RigidBody3D
class_name BoatControllerPrototype

# ============================================================
# Boat Controller - Handles ONLY movement:
# - Engine/propulsion
# - Steering
# - Wind forces
# - Input handling
# Buoyancy is handled by BuoyancyComponent child
# ============================================================

@export_group("Boat Dimensions")
@export var boat_length: float = 4.0
@export var boat_width: float = 1.5
@export var boat_height: float = 1.0
@export var boat_mass: float = 500.0

@export_group("Engine")
@export var engine_force: float = 16000.0
@export var acceleration: float = 3.0
@export var reverse_power_scale: float = 0.35

@export_group("Steering")
@export var steering_strength: float = 2200.0
@export var turn_smoothing: float = 4.0
@export var min_steering_speed: float = 1.0
@export var full_steering_speed: float = 18.0

@export_group("Wind")
@export var wind_exposed_area: float = 3.0
@export var wind_side_area: float = 6.0
@export var wind_force_multiplier: float = 1.5
@export var wind_torque_multiplier: float = 2.0

@export var control_enabled: bool = false

@onready var buoyancy_component: BuoyancyComponent = $BuoyancyComponent

var wind_system: Node3D
var throttle_input: float = 0.0
var steering_input: float = 0.0
var throttle_target: float = 0.0
var steering_target: float = 0.0

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	mass = boat_mass
	
	if not buoyancy_component:
		buoyancy_component = BuoyancyComponent.new()
		buoyancy_component.name = "BuoyancyComponent"
		buoyancy_component.object_width = boat_width
		buoyancy_component.object_height = boat_height
		buoyancy_component.object_length = boat_length
		add_child(buoyancy_component)
	
	wind_system = get_tree().get_first_node_in_group("wind_system")
	set_control_enabled(control_enabled)

# ============================================================
# PUBLIC API
# ============================================================

func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		throttle_target = 0.0
		steering_target = 0.0

func is_control_enabled() -> bool:
	return control_enabled

# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	_update_input(delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not buoyancy_component:
		return
	
	# 1. Buoyancy component handles: buoyancy, drag, stability
	var water_state: Dictionary = buoyancy_component.apply_buoyancy(state)
	buoyancy_component.apply_drag_forces(state, water_state)
	buoyancy_component.apply_upright_stabilization(state, water_state)
	
	# 2. Boat controller handles: engine, steering, wind
	_apply_engine(state, water_state)
	_apply_wind(state)
	
	# 3. Clamp
	buoyancy_component.clamp_angular_velocity(state)

# ============================================================
# INPUT
# ============================================================

func _update_input(delta: float) -> void:
	if control_enabled:
		throttle_target = Input.get_axis("move_backward", "move_forward")
		steering_target = Input.get_axis("turn_right", "turn_left")
	
	throttle_input = move_toward(throttle_input, throttle_target, acceleration * delta)
	steering_input = move_toward(steering_input, steering_target, turn_smoothing * delta)

# ============================================================
# ENGINE & STEERING
# ============================================================

func _apply_engine(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	if abs(throttle_input) <= 0.001:
		return
	
	var submerged_ratio: float = float(water_state.get("submerged_ratio", 0.0))
	if submerged_ratio <= 0.0:
		return
	
	var forward: Vector3 = -state.transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return
	forward = forward.normalized()
	
	var slip: float = float(water_state.get("slip_multiplier", 1.0))
	var scale: float = 1.0 if throttle_input >= 0.0 else reverse_power_scale
	
	var thrust: float = engine_force * throttle_input * scale * submerged_ratio * slip
	state.apply_central_force(forward * thrust)
	
	# Steering torque
	var forward_speed: float = state.linear_velocity.dot(forward)
	var speed_factor: float = clamp(inverse_lerp(min_steering_speed, full_steering_speed, abs(forward_speed)), 0.15, 1.0)
	var sign: float = -1.0 if forward_speed < -0.5 else 1.0
	
	state.apply_torque(Vector3.UP * steering_strength * steering_input * speed_factor * sign)

# ============================================================
# WIND
# ============================================================

func _apply_wind(state: PhysicsDirectBodyState3D) -> void:
	if not wind_system or not wind_system.has_method("get_wind_at_position"):
		return
	
	var wind: Vector3 = wind_system.get_wind_at_position(state.transform.origin)
	var strength: float = wind.length()
	if strength < 0.5:
		return
	
	var relative: Vector3 = wind - state.linear_velocity
	var forward: Vector3 = -state.transform.basis.z
	var right: Vector3 = state.transform.basis.x
	
	var front_drag: Vector3 = -forward * relative.dot(forward) * abs(relative.dot(forward)) * wind_exposed_area * 0.6125 * wind_force_multiplier
	var side_drag: Vector3 = -right * relative.dot(right) * abs(relative.dot(right)) * wind_side_area * 0.6125 * wind_force_multiplier
	
	state.apply_central_force(front_drag + side_drag)
	
	if abs(relative.dot(right)) > 0.5:
		state.apply_torque(forward * relative.dot(right) * strength * wind_torque_multiplier * 0.02)
	
	state.apply_central_force(Vector3(wind.x, 0.0, wind.z) * strength * 2.0 * wind_force_multiplier)

# ============================================================
# DEBUG
# ============================================================

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
