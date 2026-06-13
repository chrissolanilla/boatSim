extends RigidBody3D

@export_group("Boat Dimensions")
@export var boat_length := 4.0
@export var boat_width := 1.5
@export var boat_height := 1.0
@export var boat_mass := 500.0

@export_group("Performance")
@export var engine_power := 1000.0  # Newtons
@export var max_speed := 12.0  # m/s
@export var turn_rate := 2.0
@export var reverse_power_ratio := 0.5

@export_group("Hydrodynamics")
@export var hull_efficiency := 0.7
@export var lateral_drag := 3.0
@export var keel_strength := 5.0

@export_group("Wind Interaction")
@export var wind_exposed_area := 3.0  # m² - frontal area exposed to wind
@export var wind_side_area := 6.0  # m² - side area exposed to wind
@export var wind_force_multiplier := 1.5  # Increase for stronger wind effect
@export var wind_torque_multiplier := 2.0  # How much wind can rotate the boat

var water_manager: Node3D
var wind_system: Node3D
var input_throttle := 0.0
var input_steering := 0.0
var current_speed := 0.0

func _ready():
	mass = boat_mass
	var volume = boat_length * boat_width * boat_height * 0.4
	set_meta("volume", volume)
	
	water_manager = get_tree().get_first_node_in_group("water_manager")
	if water_manager and water_manager.has_method("register_buoyant_object"):
		water_manager.register_buoyant_object(self)
	
	# Connect to wind system
	wind_system = get_tree().get_first_node_in_group("wind_system")
	if wind_system:
		print("Boat connected to wind system")
	else:
		print("No wind system found - boat will not be affected by wind")

func _exit_tree():
	if water_manager and water_manager.has_method("unregister_buoyant_object"):
		water_manager.unregister_buoyant_object(self)

func _physics_process(delta):
	if not water_manager:
		return
	
	_get_input(delta)
	_apply_engine_force(delta)
	_apply_steering(delta)
	_apply_hydrodynamic_forces(delta)
	
	# Apply wind forces EVERY frame
	_apply_wind_forces(delta)

func _apply_wind_forces(delta):
	if not wind_system or not wind_system.has_method("get_wind_at_position"):
		return
	
	# Get wind at boat's position
	var wind = wind_system.get_wind_at_position(global_position)
	var wind_strength = wind.length()
	
	# Skip if wind is too weak
	if wind_strength < 0.5:
		return
	
	# Calculate relative wind (apparent wind)
	var relative_wind = wind - linear_velocity
	
	# Get boat's orientation vectors
	var boat_forward = -global_transform.basis.z
	var boat_right = global_transform.basis.x
	var boat_up = global_transform.basis.y
	
	# Calculate how much wind hits the front vs side of the boat
	var wind_forward = relative_wind.dot(boat_forward)  # Headwind/tailwind component
	var wind_side = relative_wind.dot(boat_right)  # Crosswind component
	var wind_up = relative_wind.dot(boat_up)  # Vertical component (usually small)
	
	# AIR DRAG FORCE
	# Front/back drag (aerodynamic drag along boat's length)
	var frontal_area = wind_exposed_area
	var frontal_drag = -boat_forward * wind_forward * abs(wind_forward) * frontal_area * 0.5 * 1.225 * wind_force_multiplier
	
	# Side drag (much stronger - boats catch wind from the side)
	var side_area = wind_side_area
	var side_drag = -boat_right * wind_side * abs(wind_side) * side_area * 0.5 * 1.225 * wind_force_multiplier
	
	# Apply drag forces
	apply_central_force(frontal_drag)
	apply_central_force(side_drag)
	
	# WIND TORQUE - Makes boat turn into the wind (weathervaning)
	var wind_dir_2d = Vector3(relative_wind.x, 0, relative_wind.z).normalized()
	var boat_forward_2d = Vector3(boat_forward.x, 0, boat_forward.z).normalized()
	var boat_right_2d = Vector3(boat_right.x, 0, boat_right.z).normalized()
	
	if wind_dir_2d.length() > 0.1 and boat_forward_2d.length() > 0.1:
		# Calculate weathervane torque - boat wants to align with wind
		var cross = boat_forward_2d.cross(wind_dir_2d)
		var alignment = boat_forward_2d.dot(wind_dir_2d)
		
		# Stronger torque when wind is from the side
		var weathervane_torque = Vector3.UP * cross.y * wind_strength * wind_strength * wind_torque_multiplier * 0.05
		apply_torque(weathervane_torque)
		
		# Additional torque from wind hitting the superstructure
		var superstructure_torque = Vector3.UP * wind_side * wind_strength * wind_torque_multiplier * 0.03
		apply_torque(superstructure_torque)
	
	# HEELING FORCE - Wind tries to tip the boat
	if abs(wind_side) > 0.5:
		var heeling_torque = boat_forward * wind_side * wind_strength * wind_torque_multiplier * 0.02
		apply_torque(heeling_torque)
	
	# WIND DRIFT - Surface current from wind pushing the boat
	var wind_drift_force = Vector3(wind.x, 0, wind.z) * wind_strength * 2.0 * wind_force_multiplier
	apply_central_force(wind_drift_force)
	
	# Debug - print wind info occasionally
	if Engine.get_physics_frames() % 120 == 0 and wind_strength > 2.0:
		print("Wind affecting boat: Strength=%.1f, Forward=%.1f, Side=%.1f" % [wind_strength, wind_forward, wind_side])

func _get_input(delta):
	var target_throttle = Input.get_axis("move_backward", "move_forward")
	var target_steering = Input.get_axis("turn_right", "turn_left")
	
	var response = 3.0 * delta
	input_throttle = move_toward(input_throttle, target_throttle, response)
	input_steering = move_toward(input_steering, target_steering, response * 2.0)

func _apply_engine_force(delta):
	if abs(input_throttle) < 0.01:
		return
	
	var forward = -global_transform.basis.z
	var forward_speed = linear_velocity.dot(forward)
	var speed_ratio = abs(forward_speed) / max_speed
	var efficiency = 1.0 - speed_ratio * speed_ratio * 0.5
	
	var power = engine_power * efficiency
	if input_throttle < 0:
		power *= reverse_power_ratio
	
	var thrust = forward * input_throttle * power
	var thrust_position = Vector3(0, -boat_height * 0.3, boat_length * 0.4)
	apply_force(thrust, thrust_position)

func _apply_steering(delta):
	if abs(input_steering) < 0.01:
		return
	
	var forward_speed = linear_velocity.dot(-global_transform.basis.z)
	
	if abs(forward_speed) < 0.5:
		return
	
	var turn_force_magnitude = input_steering * forward_speed * turn_rate * mass * 0.1
	var turn_force = global_transform.basis.x * turn_force_magnitude
	var rudder_position = Vector3(0, -boat_height * 0.3, boat_length * 0.4)
	apply_force(turn_force, rudder_position)
	
	var torque = Vector3.UP * input_steering * forward_speed * turn_rate * 0.5
	apply_torque(torque)

func _apply_hydrodynamic_forces(delta):
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	var up = global_transform.basis.y
	
	var forward_speed = linear_velocity.dot(forward)
	var lateral_speed = linear_velocity.dot(right)
	
	# Lateral resistance
	var lateral_force = -right * lateral_speed * abs(lateral_speed) * lateral_drag * mass * delta
	apply_central_force(lateral_force)
	
	# Keel effect
	var tilt = up.dot(Vector3.UP)
	if tilt < 0.99:
		var righting_axis = up.cross(Vector3.UP).normalized()
		var righting_torque = righting_axis * (1.0 - tilt) * keel_strength * mass
		apply_torque(righting_torque)
	
	# Wave resistance
	if abs(forward_speed) > 1.0:
		var wave_drag = -forward * forward_speed * abs(forward_speed) * 0.1 * mass * delta
		apply_central_force(wave_drag)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
