extends RigidBody3D

@export var buoyancy_multiplier := 1.0
@export var water_drag := 0.8
@export var angular_water_drag := 0.5
@export var wind_exposed_area := 1.0  # m²

var water_manager: Node3D
var wind_system: Node3D
var original_y: float
var float_velocity := 0.0

func _ready():
	set_meta("volume", 1.0)
	original_y = global_position.y
	
	water_manager = get_tree().get_first_node_in_group("water_manager")
	if water_manager and water_manager.has_method("register_buoyant_object"):
		water_manager.register_buoyant_object(self)
	
	wind_system = get_tree().get_first_node_in_group("wind_system")

func _exit_tree():
	if water_manager and water_manager.has_method("unregister_buoyant_object"):
		water_manager.unregister_buoyant_object(self)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	# Apply wind forces directly
	if wind_system and wind_system.has_method("get_wind_at_position"):
		var wind = wind_system.get_wind_at_position(global_position)
		var wind_strength = wind.length()
		
		if wind_strength > 0.5:
			# Wind pushes the crate
			var wind_force = wind * wind_strength * wind_exposed_area * 0.5 * 1.225
			apply_central_force(wind_force)
			
			# Add some random tumbling from wind gusts
			if wind_strength > 5.0:
				var random_torque = Vector3(
					randf_range(-1, 1),
					randf_range(-1, 1),
					randf_range(-1, 1)
				) * wind_strength * 0.01
				apply_torque(random_torque)
	
	# Original water interaction code
	if not water_manager or not water_manager.has_method("get_height_at_position"):
		return
	
	var water_height = water_manager.get_height_at_position(global_position)
	var depth = water_height - global_position.y
	
	if depth > 0:
		var buoyancy_force = Vector3.UP * depth * 9.81 * mass * buoyancy_multiplier
		var damping_force = Vector3.UP * float_velocity * 0.3 * mass
		apply_central_force(buoyancy_force + damping_force)
		
		var water_velocity = Vector3.ZERO
		if water_manager.has_method("get_water_velocity_at"):
			water_velocity = water_manager.get_water_velocity_at(global_position)
		
		var relative_velocity = linear_velocity - water_velocity
		var drag_force = -relative_velocity * water_drag * depth
		apply_central_force(drag_force)
		
		angular_velocity *= (1.0 - angular_water_drag * depth * state.step)
		float_velocity = linear_velocity.y
