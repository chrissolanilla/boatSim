extends RigidBody3D

@export var water_manager: Node3D
@export var buoyancy_strength: float = 8.0
@export var water_drag: float = 3.0
@export var bounce_damping: float = 0.5

var buoyancy_points: Array = []

func _ready():
	# Find water manager if not set
	if not water_manager:
		water_manager = get_node("/root/WaterWorld/WaterManager")
	
	# Make sure we found it
	if water_manager:
		print("Water manager found!")
	else:
		print("WARNING: Water manager not found!")
	
	# Create buoyancy points
	_create_buoyancy_points()
	
	# Physics settings
	gravity_scale = 1.0
	linear_damp = 0.3

func _create_buoyancy_points():
	# Simple buoyancy points (works for any object)
	buoyancy_points = [
		Vector3(-0.5, 0, -0.5),
		Vector3(0.5, 0, -0.5),
		Vector3(-0.5, 0, 0.5),
		Vector3(0.5, 0, 0.5),
		Vector3(0, 0, 0)
	]

func _integrate_forces(state: PhysicsDirectBodyState3D):
	# Check if water manager exists
	if not water_manager:
		return
	
	# Check if water_manager has the function
	if not water_manager.has_method("get_water_height"):
		return
	
	var total_buoyancy = 0.0
	var buoyancy_center = Vector3.ZERO
	
	for point in buoyancy_points:
		# Get world position of buoyancy point
		var world_point = global_transform * point
		
		# Get water height at that position
		var water_height = water_manager.get_water_height(world_point.x, world_point.z)
		var depth = water_height - world_point.y
		
		if depth > 0:
			# Limit depth to prevent huge forces
			var limited_depth = min(depth, 1.0)
			
			# Calculate force
			var force_magnitude = buoyancy_strength * limited_depth
			var force = Vector3.UP * force_magnitude
			
			# Apply force
			state.apply_force(force, world_point - state.transform.origin)
			total_buoyancy += force_magnitude
			buoyancy_center += world_point * force_magnitude
			
			# Apply drag
			var velocity_at_point = state.linear_velocity
			var drag_force = -velocity_at_point * water_drag * limited_depth
			state.apply_force(drag_force, world_point - state.transform.origin)
	
	# Apply damping to stop bouncing
	if total_buoyancy > 0:
		buoyancy_center = buoyancy_center / total_buoyancy
		
		# Damp vertical velocity
		var damping_force = -state.linear_velocity.y * bounce_damping * 10.0
		state.apply_central_force(Vector3.UP * damping_force)
