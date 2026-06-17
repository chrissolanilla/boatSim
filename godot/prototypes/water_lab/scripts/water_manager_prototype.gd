extends Node3D

# Grid configuration
@export var grid_size := Vector2i(100, 100)
@export var cell_size := 1.0
@export var wave_speed := 3.0
@export var damping := 0.995
@export var base_height := 0.0

# Physics parameters
@export var gravity := 9.81
@export var water_density := 1000.0  # kg/m³ (fresh water)
@export var air_density := 1.225  # kg/m³

# Visualization
@export var mesh_resolution := 50
@export var wave_color := Color(0.1, 0.3, 0.8, 0.7)
@export var foam_threshold := 0.3

# Wind interaction
@export var enable_wind_waves := true
@export var wind_wave_strength := 0.3

# Internal arrays
var height_map: Array = []
var previous_heights: Array = []
var velocity_map: Array = []
var foam_map: Array = []

# Registered objects
var buoyant_objects: Array = []
var splashes: Array = []

# Wind system reference
var wind_system: Node3D
var wind_wave_time: float = 0.0
var physics_frame_count: int = 0

# Interaction grid reference (for wake/disturbance system)
var interaction_grid: Node3D = null

# Mesh generation
var water_mesh: ArrayMesh
var mesh_instance: MeshInstance3D
var water_material: StandardMaterial3D

func _ready():
	add_to_group("water_manager")
	_initialize_grids()
	_generate_water_mesh()
	_find_wind_system()

func _find_wind_system():
	wind_system = get_tree().get_first_node_in_group("wind_system")
	if not wind_system:
		wind_system = get_node_or_null("../WindSystem")

func _initialize_grids():
	height_map = []
	previous_heights = []
	velocity_map = []
	foam_map = []
	
	for x in range(grid_size.x + 1):
		var height_row = []
		var prev_row = []
		var vel_row = []
		var foam_row = []
		
		for z in range(grid_size.y + 1):
			height_row.append(base_height)
			prev_row.append(base_height)
			vel_row.append(0.0)
			foam_row.append(0.0)
		
		height_map.append(height_row)
		previous_heights.append(prev_row)
		velocity_map.append(vel_row)
		foam_map.append(foam_row)

func _physics_process(delta):
	physics_frame_count += 1
	wind_wave_time += delta
	
	# Step 1: Generate environmental waves (wind, etc.)
	if enable_wind_waves and wind_system:
		_apply_wind_to_water(delta)
	
	# Step 2: Calculate and apply object displacements on water
	_update_object_displacement(delta)
	
	# Step 3: Propagate all waves through the grid
	_propagate_waves(delta)
	
	# Step 4: Apply absorbing boundary conditions
	_apply_boundary_conditions()
	
	# Step 5: Calculate buoyancy forces based on current water state
	_calculate_all_buoyancy_forces(delta)
	
	# Step 6: Update splash particle effects
	_update_splashes(delta)
	
	# Step 7: Update visual mesh (throttled for performance)
	if physics_frame_count % 2 == 0:
		_update_visualization()

# ============================================================
# NEW FUNCTION: Get complete water state at a position
# ============================================================
func get_water_state_at_position(world_pos: Vector3) -> Dictionary:
	var surface_height = get_height_at_position(world_pos)
	var normal = get_water_normal_at(world_pos)
	var velocity = get_water_velocity_at(world_pos)
	
	# Calculate turbulence based on wave steepness
	var local_pos = world_pos - global_position
	var grid_x = clampi(int(local_pos.x / cell_size), 1, grid_size.x - 1)
	var grid_z = clampi(int(local_pos.z / cell_size), 1, grid_size.y - 1)
	
	var steepness = abs(height_map[grid_x+1][grid_z] - height_map[grid_x-1][grid_z]) + \
					abs(height_map[grid_x][grid_z+1] - height_map[grid_x][grid_z-1])
	var turbulence = min(steepness * 2.0, 1.0)
	
	# Slip multiplier - reduces engine effectiveness in rough water
	var slip_multiplier = 1.0 - turbulence * 0.5
	
	# Wake strength from foam
	var wake_strength = 0.0
	if grid_x >= 0 and grid_x <= grid_size.x and grid_z >= 0 and grid_z <= grid_size.y:
		wake_strength = foam_map[grid_x][grid_z]
	
	return {
		"surface_height": surface_height,
		"normal": normal,
		"velocity": velocity,
		"turbulence": turbulence,
		"slip_multiplier": slip_multiplier,
		"wake_strength": wake_strength
	}

# ============================================================
# NEW FUNCTION: Get water normal at a position
# ============================================================
func get_water_normal_at(world_pos: Vector3) -> Vector3:
	var local_pos = world_pos - global_position
	var grid_x = clampi(int(local_pos.x / cell_size), 1, grid_size.x - 1)
	var grid_z = clampi(int(local_pos.z / cell_size), 1, grid_size.y - 1)
	
	# Calculate normal from surrounding heights
	var h_right = height_map[min(grid_x + 1, grid_size.x)][grid_z]
	var h_left = height_map[max(grid_x - 1, 0)][grid_z]
	var h_forward = height_map[grid_x][min(grid_z + 1, grid_size.y)]
	var h_back = height_map[grid_x][max(grid_z - 1, 0)]
	
	var normal = Vector3(
		(h_left - h_right) / (2.0 * cell_size),
		1.0,
		(h_back - h_forward) / (2.0 * cell_size)
	).normalized()
	
	return normal

# ============================================================
# EXISTING FUNCTION: Get water height at a position
# ============================================================
func get_water_height_at_position(world_pos: Vector3) -> float:
	return get_height_at_position(world_pos)

# ============================================================
# EXISTING FUNCTION: Add disturbance to interaction grid
# ============================================================
func add_disturbance(position: Vector3, intensity: float, radius: float, direction: Vector3 = Vector3.ZERO, velocity_strength: float = 0.0, turbulence: float = 0.0, slip: float = 1.0):
	# This creates a splash/disturbance in the water
	create_splash(position, intensity, radius)
	
	# Also push water in a direction if specified
	if direction.length() > 0 and velocity_strength > 0:
		var local_pos = position - global_position
		var center_x = int(local_pos.x / cell_size)
		var center_z = int(local_pos.z / cell_size)
		var int_radius = ceili(radius)
		
		for dx in range(-int_radius, int_radius + 1):
			for dz in range(-int_radius, int_radius + 1):
				var nx = center_x + dx
				var nz = center_z + dz
				if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
					var dist = sqrt(dx*dx + dz*dz)
					if dist <= radius:
						var falloff = 1.0 - smoothstep(0.0, radius, dist)
						var push = direction * velocity_strength * falloff * 0.01
						height_map[nx][nz] += push.length() * falloff * 0.1

func _apply_wind_to_water(delta):
	if not wind_system or not wind_system.has_method("get_wind_at_position"):
		return
	
	var base_wind = wind_system.get_wind_at_position(global_position)
	var wind_strength = base_wind.length()
	
	if wind_strength < 0.2:
		return
	
	var wind_dir = Vector3(base_wind.x, 0, base_wind.z).normalized()
	
	for x in range(0, grid_size.x + 1, 4):
		for z in range(0, grid_size.y + 1, 4):
			var world_x = x * cell_size + global_position.x
			var world_z = z * cell_size + global_position.z
			var world_pos = Vector3(world_x, height_map[x][z] + global_position.y, world_z)
			
			var local_wind = wind_system.get_wind_at_position(world_pos)
			var local_wind_strength = local_wind.length()
			
			if local_wind_strength < 0.2:
				continue
			
			var significant_wave_height = 0.021 * local_wind_strength * local_wind_strength
			var peak_frequency = 0.87 * pow(local_wind_strength, -0.67)
			
			var fetch_distance = world_pos.dot(wind_dir)
			var wave_phase = fetch_distance * peak_frequency - wind_wave_time * 2.0 * PI * peak_frequency
			
			var wave_height = 0.0
			for i in range(3):
				var component_freq = peak_frequency * (0.7 + i * 0.3)
				var component_amp = significant_wave_height * exp(-i * 0.5) * 0.3
				var component_phase = wave_phase * (1.0 + i * 0.2) + i * 1.5
				wave_height += sin(component_phase) * component_amp * wind_wave_strength
			
			height_map[x][z] = lerp(height_map[x][z], base_height + wave_height, 0.1)
			
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					var nx = x + dx
					var nz = z + dz
					if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
						var dist = sqrt(dx*dx + dz*dz)
						var spread_factor = exp(-dist * 0.8) * 0.3
						height_map[nx][nz] = lerp(height_map[nx][nz], base_height + wave_height * spread_factor, 0.05)
			
			if abs(wave_height) > significant_wave_height * 0.6:
				foam_map[x][z] = min(foam_map[x][z] + delta * 2.0, 1.0)

func _update_object_displacement(delta):
	for object in buoyant_objects:
		if not is_instance_valid(object):
			continue
		
		var obj_world_pos = object.global_position
		var obj_local_pos = obj_world_pos - global_position
		var obj_velocity = object.linear_velocity
		
		var object_bounds = _get_object_bounds(object)
		if object_bounds == Vector3.ZERO:
			continue
		
		var half_extents = object_bounds * 0.5
		var object_volume = object_bounds.x * object_bounds.y * object_bounds.z
		
		var water_surface_height = get_height_at_position(obj_world_pos)
		var object_bottom_y = obj_world_pos.y - half_extents.y
		var object_top_y = obj_world_pos.y + half_extents.y
		
		var submerged_fraction = clamp((water_surface_height - object_bottom_y) / object_bounds.y, 0.0, 1.0)
		var displaced_volume = object_volume * submerged_fraction
		
		var influence_radius = max(half_extents.x, half_extents.z) * 1.5
		var grid_radius = int(influence_radius / cell_size) + 2
		
		var center_grid_x = int(obj_local_pos.x / cell_size)
		var center_grid_z = int(obj_local_pos.z / cell_size)
		
		var min_x = max(0, center_grid_x - grid_radius)
		var max_x = min(grid_size.x, center_grid_x + grid_radius)
		var min_z = max(0, center_grid_z - grid_radius)
		var max_z = min(grid_size.y, center_grid_z + grid_radius)
		
		for x in range(min_x, max_x):
			for z in range(min_z, max_z):
				var world_x = x * cell_size
				var world_z = z * cell_size
				
				var dx = (world_x - obj_local_pos.x) / max(half_extents.x, 0.1)
				var dz = (world_z - obj_local_pos.z) / max(half_extents.z, 0.1)
				var horizontal_dist = sqrt(dx * dx + dz * dz)
				
				if horizontal_dist > 2.0:
					continue
				
				var current_height = height_map[x][z]
				var object_bottom_at_point = obj_local_pos.y - half_extents.y * sqrt(1.0 - min(horizontal_dist * horizontal_dist * 0.5, 1.0))
				var object_top_at_point = obj_local_pos.y + half_extents.y * sqrt(1.0 - min(horizontal_dist * horizontal_dist * 0.5, 1.0))
				
				var falloff = exp(-horizontal_dist * horizontal_dist * 1.5)
				
				if object_top_at_point < current_height:
					var displacement = (current_height - object_top_at_point) * falloff * 0.5
					height_map[x][z] += displacement
				elif object_bottom_at_point < current_height and object_top_at_point > current_height:
					var penetration = current_height - object_bottom_at_point
					var target_height = object_bottom_at_point + penetration * 0.2
					height_map[x][z] = lerp(current_height, target_height, falloff * 0.3)
				
				if obj_velocity.length() > 0.5:
					var velocity_dir = Vector3(obj_velocity.x, 0, obj_velocity.z).normalized()
					var velocity_magnitude = obj_velocity.length()
					
					var froude_number = velocity_magnitude / sqrt(gravity * object_bounds.x)
					var wake_strength = froude_number * froude_number * 0.1 * falloff
					
					var relative_pos = Vector3(world_x - obj_local_pos.x, 0, world_z - obj_local_pos.z)
					var behind_factor = max(0, -relative_pos.dot(velocity_dir)) / max(influence_radius, 0.1)
					
					if behind_factor > 0:
						var wake_angle = 19.47 * PI / 180.0
						var lateral_distance = abs(relative_pos.cross(velocity_dir).length())
						var expected_wake_distance = behind_factor * tan(wake_angle)
						
						var wake_factor = exp(-pow(lateral_distance - expected_wake_distance, 2) * 10.0)
						var wake_height = -velocity_magnitude * wake_strength * wake_factor * behind_factor * 0.05
						height_map[x][z] += wake_height

func _get_object_bounds(object: RigidBody3D) -> Vector3:
	for child in object.get_children():
		if child is CollisionShape3D and child.shape:
			if child.shape is BoxShape3D:
				return child.shape.size * object.scale
			elif child.shape is SphereShape3D:
				var r = child.shape.radius * max(object.scale.x, max(object.scale.y, object.scale.z))
				return Vector3(r * 2, r * 2, r * 2)
			elif child.shape is CapsuleShape3D:
				var r = child.shape.radius * max(object.scale.x, object.scale.z)
				var h = child.shape.height * object.scale.y
				return Vector3(r * 2, h + r * 2, r * 2)
			elif child.shape is CylinderShape3D:
				var r = child.shape.radius * max(object.scale.x, object.scale.z)
				var h = child.shape.height * object.scale.y
				return Vector3(r * 2, h, r * 2)
	
	var mesh_instance = object.find_child("MeshInstance3D", true, false)
	if mesh_instance and mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		return aabb.size * object.scale
	
	if object.mass > 0:
		var default_size = pow(object.mass / water_density, 1.0/3.0)
		return Vector3(default_size, default_size, default_size)
	
	return Vector3(1, 1, 1)

func _calculate_all_buoyancy_forces(delta):
	for object in buoyant_objects:
		if not is_instance_valid(object):
			continue
		_calculate_object_buoyancy(object, delta)

func _calculate_object_buoyancy(object: RigidBody3D, delta: float):
	var object_bounds = _get_object_bounds(object)
	if object_bounds == Vector3.ZERO:
		return
	
	var half_extents = object_bounds * 0.5
	var total_volume = object_bounds.x * object_bounds.y * object_bounds.z
	var obj_pos = object.global_position
	
	var samples_per_axis = clampi(int(max(object_bounds.x, max(object_bounds.y, object_bounds.z)) * 2), 4, 8)
	
	var total_submerged_volume = 0.0
	var center_of_buoyancy = Vector3.ZERO
	var total_drag_force = Vector3.ZERO
	var total_lift_force = Vector3.ZERO
	var average_reynolds_number = 0.0
	
	var sample_volume = total_volume / (samples_per_axis * samples_per_axis * samples_per_axis)
	var submerged_samples = 0
	
	for x in range(samples_per_axis):
		for y in range(samples_per_axis):
			for z in range(samples_per_axis):
				var local_point = Vector3(
					lerp(-half_extents.x, half_extents.x, (x + 0.5) / samples_per_axis),
					lerp(-half_extents.y, half_extents.y, (y + 0.5) / samples_per_axis),
					lerp(-half_extents.z, half_extents.z, (z + 0.5) / samples_per_axis)
				)
				
				var world_point = object.to_global(local_point)
				var water_height = get_height_at_position(world_point)
				var depth = water_height - world_point.y
				
				if depth > 0:
					total_submerged_volume += sample_volume
					center_of_buoyancy += world_point * sample_volume
					submerged_samples += 1
					
					var water_velocity = get_water_velocity_at(world_point)
					var relative_velocity = object.linear_velocity - water_velocity
					
					var point_reynolds = relative_velocity.length() * object_bounds.x / 1.0e-6
					average_reynolds_number += point_reynolds
					
					var drag_coefficient = 0.5
					if point_reynolds > 1000:
						drag_coefficient = 0.4
					
					var point_drag = -relative_velocity.normalized() * relative_velocity.length_squared() * water_density * drag_coefficient * sample_volume * 0.1
					total_drag_force += point_drag
					
					var surface_normal = (world_point - obj_pos).normalized()
					var flow_lift = surface_normal.cross(relative_velocity).cross(surface_normal) * relative_velocity.length() * depth * sample_volume * 0.01
					total_lift_force += flow_lift
	
	if submerged_samples > 0:
		average_reynolds_number /= submerged_samples
	
	if total_submerged_volume > 0.001:
		var displaced_mass = water_density * total_submerged_volume
		var buoyancy_force = Vector3.UP * gravity * displaced_mass
		
		center_of_buoyancy /= total_submerged_volume
		
		object.apply_force(buoyancy_force, center_of_buoyancy - obj_pos)
		object.apply_central_force(total_drag_force)
		object.apply_central_force(total_lift_force * 0.5)
		
		var submerged_ratio = total_submerged_volume / total_volume
		
		var angular_velocity_magnitude = object.angular_velocity.length()
		var rotational_re = angular_velocity_magnitude * object_bounds.x * object_bounds.x / 1.0e-6
		var angular_drag_coefficient = 0.1 * (1.0 + 1.0 / sqrt(max(rotational_re, 1.0)))
		var angular_drag_factor = 1.0 - min(submerged_ratio * angular_drag_coefficient, 0.95)
		object.angular_velocity *= angular_drag_factor
		
		var object_up = object.global_transform.basis.y
		var upright_dot = object_up.dot(Vector3.UP)
		
		if upright_dot < 0.995:
			var moment_of_inertia = (object_bounds.x * pow(object_bounds.z, 3)) / 12.0
			var metacentric_height = moment_of_inertia / max(total_submerged_volume, 0.001) - half_extents.y * (0.5 - submerged_ratio)
			
			var righting_axis = object_up.cross(Vector3.UP).normalized()
			var righting_arm = metacentric_height * sin(acos(upright_dot))
			var righting_torque = righting_axis * righting_arm * displaced_mass * gravity * submerged_ratio
			
			object.apply_torque(righting_torque)
		
		if wind_system and wind_system.has_method("get_wind_at_position"):
			var wind = wind_system.get_wind_at_position(obj_pos)
			var surface_current = Vector3(wind.x, 0, wind.z) * 0.03
			object.apply_central_force(surface_current * displaced_mass * 0.1)
		
		if average_reynolds_number > 0:
			var wetted_surface_area = pow(total_submerged_volume, 2.0/3.0) * 4.84
			var skin_friction_coefficient = 0.075 / pow(log(average_reynolds_number) - 2, 2)
			var skin_friction = -object.linear_velocity.normalized() * object.linear_velocity.length_squared() * water_density * skin_friction_coefficient * wetted_surface_area * 0.5
			object.apply_central_force(skin_friction)

func _propagate_waves(delta):
	for x in range(grid_size.x + 1):
		for z in range(grid_size.y + 1):
			previous_heights[x][z] = height_map[x][z]
	
	var dt2 = delta * delta
	var wave_speed_sq = wave_speed * wave_speed
	
	for x in range(2, grid_size.x - 2):
		for z in range(2, grid_size.y - 2):
			var laplacian = (height_map[x+1][z] + height_map[x-1][z] + height_map[x][z+1] + height_map[x][z-1] - 4.0 * height_map[x][z]) / (cell_size * cell_size)
			
			var new_height = 2.0 * height_map[x][z] - previous_heights[x][z] + wave_speed_sq * laplacian * dt2
			
			var wave_steepness = abs(laplacian)
			var adaptive_damping = damping
			if wave_steepness > 0.5:
				adaptive_damping = damping * 0.95
			
			new_height = lerp(new_height, base_height, 1.0 - adaptive_damping)
			new_height = clamp(new_height, base_height - 5.0, base_height + 5.0)
			
			velocity_map[x][z] = (new_height - previous_heights[x][z]) / max(delta, 0.0001)
			
			if wave_steepness > foam_threshold:
				foam_map[x][z] = min(foam_map[x][z] + delta * 4.0, 1.0)
			else:
				foam_map[x][z] = max(foam_map[x][z] - delta * 2.0, 0.0)
			
			height_map[x][z] = new_height

func _apply_boundary_conditions():
	var absorption_width = 8
	var absorption_strength = 0.9
	
	for i in range(grid_size.x + 1):
		for z in range(absorption_width):
			var factor = pow(float(z) / absorption_width, 2) * absorption_strength
			height_map[i][z] = lerp(height_map[i][z], base_height, factor)
			height_map[i][grid_size.y - z] = lerp(height_map[i][grid_size.y - z], base_height, factor)
	
	for i in range(grid_size.y + 1):
		for x in range(absorption_width):
			var factor = pow(float(x) / absorption_width, 2) * absorption_strength
			height_map[x][i] = lerp(height_map[x][i], base_height, factor)
			height_map[grid_size.x - x][i] = lerp(height_map[grid_size.x - x][i], base_height, factor)

func get_height_at_position(world_pos: Vector3) -> float:
	var local_pos = world_pos - global_position
	var grid_x = local_pos.x / cell_size
	var grid_z = local_pos.z / cell_size
	
	var x0 = clampi(int(floor(grid_x)), 0, grid_size.x)
	var z0 = clampi(int(floor(grid_z)), 0, grid_size.y)
	var x1 = clampi(x0 + 1, 0, grid_size.x)
	var z1 = clampi(z0 + 1, 0, grid_size.y)
	
	var fx = clampf(grid_x - x0, 0.0, 1.0)
	var fz = clampf(grid_z - z0, 0.0, 1.0)
	
	var h00 = height_map[x0][z0]
	var h10 = height_map[x1][z0]
	var h01 = height_map[x0][z1]
	var h11 = height_map[x1][z1]
	
	return lerp(lerp(h00, h10, fx), lerp(h01, h11, fx), fz)

func get_water_velocity_at(world_pos: Vector3) -> Vector3:
	var local_pos = world_pos - global_position
	var grid_x = clampi(int(local_pos.x / cell_size), 1, grid_size.x - 1)
	var grid_z = clampi(int(local_pos.z / cell_size), 1, grid_size.y - 1)
	
	var dh_dx = (height_map[grid_x + 1][grid_z] - height_map[grid_x - 1][grid_z]) / (2.0 * cell_size)
	var dh_dz = (height_map[grid_x][grid_z + 1] - height_map[grid_x][grid_z - 1]) / (2.0 * cell_size)
	
	var horizontal_vel = Vector3(-dh_dx, 0, -dh_dz) * wave_speed
	var vertical_vel = velocity_map[grid_x][grid_z]
	
	if wind_system and wind_system.has_method("get_wind_at_position"):
		var wind = wind_system.get_wind_at_position(world_pos + global_position)
		var wind_current = Vector3(wind.x, 0, wind.z) * 0.03
		return Vector3(horizontal_vel.x, vertical_vel, horizontal_vel.z) + wind_current
	
	return Vector3(horizontal_vel.x, vertical_vel, horizontal_vel.z)

func create_splash(position: Vector3, intensity: float, radius: float = 2.0):
	var local_pos = position - global_position
	var center_x = int(local_pos.x / cell_size)
	var center_z = int(local_pos.z / cell_size)
	var int_radius = ceili(radius)
	
	for dx in range(-int_radius, int_radius + 1):
		for dz in range(-int_radius, int_radius + 1):
			var nx = center_x + dx
			var nz = center_z + dz
			if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
				var dist = sqrt(dx*dx + dz*dz)
				if dist <= radius:
					var falloff = 1.0 - smoothstep(0.0, radius, dist)
					height_map[nx][nz] += intensity * falloff * falloff
	
	splashes.append({
		"position": position,
		"intensity": intensity,
		"radius": radius,
		"lifetime": 2.0,
		"age": 0.0
	})

func _update_splashes(delta):
	var active_splashes = []
	for splash in splashes:
		splash.age += delta
		if splash.age < splash.lifetime:
			active_splashes.append(splash)
	splashes = active_splashes

func register_buoyant_object(object: RigidBody3D):
	if object not in buoyant_objects:
		buoyant_objects.append(object)
		print("Water Manager: Registered buoyant object - ", object.name)

func unregister_buoyant_object(object: RigidBody3D):
	buoyant_objects.erase(object)

func _generate_water_mesh():
	water_mesh = ArrayMesh.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step_x = float(grid_size.x) / mesh_resolution
	var step_z = float(grid_size.y) / mesh_resolution
	
	for x in range(mesh_resolution + 1):
		for z in range(mesh_resolution + 1):
			var world_x = x * step_x * cell_size
			var world_z = z * step_z * cell_size
			st.set_uv(Vector2(float(x) / mesh_resolution, float(z) / mesh_resolution))
			st.add_vertex(Vector3(world_x, base_height, world_z))
	
	for x in range(mesh_resolution):
		for z in range(mesh_resolution):
			var i = x * (mesh_resolution + 1) + z
			st.add_index(i)
			st.add_index(i + mesh_resolution + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + mesh_resolution + 1)
			st.add_index(i + mesh_resolution + 2)
	
	st.generate_normals()
	water_mesh = st.commit()
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = water_mesh
	
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = wave_color
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.05
	water_material.metallic = 0.1
	water_material.flags_unshaded = false
	mesh_instance.material_override = water_material
	
	add_child(mesh_instance)

func _update_visualization():
	if not mesh_instance:
		return
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step_x = float(grid_size.x) / mesh_resolution
	var step_z = float(grid_size.y) / mesh_resolution
	
	for x in range(mesh_resolution + 1):
		for z in range(mesh_resolution + 1):
			var grid_x = mini(int(x * step_x), grid_size.x)
			var grid_z = mini(int(z * step_z), grid_size.y)
			var height = height_map[grid_x][grid_z]
			var foam = foam_map[grid_x][grid_z]
			
			var world_x = x * step_x * cell_size
			var world_z = z * step_z * cell_size
			
			st.set_uv(Vector2(float(x) / mesh_resolution, float(z) / mesh_resolution))
			
			var color = wave_color
			var height_factor = (height - base_height) * 0.5 + 0.5
			color = color.lightened(height_factor * 0.2)
			color.a = 0.7 + foam * 0.3
			st.set_color(color)
			
			st.add_vertex(Vector3(world_x, height, world_z))
	
	for x in range(mesh_resolution):
		for z in range(mesh_resolution):
			var i = x * (mesh_resolution + 1) + z
			st.add_index(i)
			st.add_index(i + mesh_resolution + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + mesh_resolution + 1)
			st.add_index(i + mesh_resolution + 2)
	
	st.generate_normals()
	
	var new_mesh = st.commit()
	mesh_instance.mesh = new_mesh

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clampf((x - edge0) / max(edge1 - edge0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func get_water_height_global() -> float:
	return global_position.y + base_height

func get_wave_amplitude_at(world_pos: Vector3) -> float:
	return abs(get_height_at_position(world_pos) - base_height)
