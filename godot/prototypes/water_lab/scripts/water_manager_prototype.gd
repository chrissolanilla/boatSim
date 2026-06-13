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

# Mesh generation
var water_mesh: ArrayMesh
var mesh_instance: MeshInstance3D

func _ready():
	add_to_group("water_manager")
	_initialize_grids()
	_generate_water_mesh()
	
	# Find wind system in scene
	_find_wind_system()

func _find_wind_system():
	wind_system = get_tree().get_first_node_in_group("wind_system")
	if not wind_system:
		# Try to find by name or create one
		wind_system = get_node_or_null("../WindSystem")
	if wind_system:
		print("Water Manager: Wind system found and linked")
	else:
		print("Water Manager: No wind system found - wind waves disabled")

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
	wind_wave_time += delta
	
	# Generate wind waves first
	if enable_wind_waves and wind_system:
		_apply_wind_to_water(delta)
	
	# Process objects first to get their displacement
	_update_object_displacement(delta)
	
	# Propagate waves
	_propagate_waves(delta)
	
	# Apply boundary conditions
	_apply_boundary_conditions()
	
	# Calculate buoyancy for all objects
	_calculate_buoyancy_forces(delta)
	
	# Update splashes
	_update_splashes(delta)
	
	# Update visual mesh
	_update_visualization()

func _apply_wind_to_water(delta):
	if not wind_system or not wind_system.has_method("get_wind_at_position"):
		return
	
	var wind = wind_system.get_wind_at_position(global_position)
	var wind_strength = wind.length()
	
	if wind_strength < 0.1:
		return
	
	# Apply wind force to create waves across the water surface
	# Skip every few cells for performance
	for x in range(0, grid_size.x + 1, 4):
		for z in range(0, grid_size.y + 1, 4):
			var world_pos = Vector3(
				x * cell_size + global_position.x,
				height_map[x][z] + global_position.y,
				z * cell_size + global_position.z
			)
			
			var local_wind = wind_system.get_wind_at_position(world_pos)
			var local_wind_force = local_wind.length()
			
			if local_wind_force > 0.1:
				# Create wind-driven waves (Gerstner-like waves aligned with wind)
				var wind_dir = local_wind.normalized()
				var wave_alignment = world_pos.dot(Vector3(wind_dir.x, 0, wind_dir.z))
				
				# Multiple wave frequencies for natural look
				var wave1 = sin(wave_alignment * 0.3 + wind_wave_time * 0.8) * local_wind_force * wind_wave_strength * 0.015
				var wave2 = cos(wave_alignment * 0.5 + wind_wave_time * 1.2) * local_wind_force * wind_wave_strength * 0.01
				var wave3 = sin(wave_alignment * 0.15 + wind_wave_time * 0.5) * local_wind_force * wind_wave_strength * 0.02
				
				var total_wave = wave1 + wave2 + wave3
				
				# Apply to the height map
				height_map[x][z] += total_wave
				
				# Smooth propagation to neighboring cells
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						if dx == 0 and dz == 0:
							continue
						var nx = x + dx
						var nz = z + dz
						if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
							var dist = sqrt(dx*dx + dz*dz)
							var spread_factor = exp(-dist) * 0.4
							height_map[nx][nz] += total_wave * spread_factor
				
				# Add foam where waves are steep
				if abs(total_wave) > foam_threshold * 0.5:
					foam_map[x][z] = min(foam_map[x][z] + delta * 1.5, 0.8)

func _update_object_displacement(delta):
	for object in buoyant_objects:
		if not is_instance_valid(object):
			continue
		
		var obj_pos = object.global_position - global_position
		var obj_vel = object.linear_velocity
		
		# Get object dimensions from collision shape or mesh
		var object_bounds = _get_object_bounds(object)
		if object_bounds == Vector3.ZERO:
			continue
		
		var half_extents = object_bounds * 0.5
		
		# Calculate the grid area affected by this object
		var min_x = max(0, int((obj_pos.x - half_extents.x * 1.5) / cell_size))
		var max_x = min(grid_size.x, int((obj_pos.x + half_extents.x * 1.5) / cell_size) + 1)
		var min_z = max(0, int((obj_pos.z - half_extents.z * 1.5) / cell_size))
		var max_z = min(grid_size.y, int((obj_pos.z + half_extents.z * 1.5) / cell_size) + 1)
		
		# Displace water based on object's submerged portion
		for x in range(min_x, max_x):
			for z in range(min_z, max_z):
				var world_x = x * cell_size
				var world_z = z * cell_size
				
				# Distance from object center in horizontal plane
				var dx = (world_x - obj_pos.x) / max(half_extents.x, 0.1)
				var dz = (world_z - obj_pos.z) / max(half_extents.z, 0.1)
				var horizontal_dist = sqrt(dx * dx + dz * dz)
				
				if horizontal_dist < 1.3:
					# Calculate how much the object penetrates the water at this point
					var water_height = height_map[x][z]
					var object_bottom = obj_pos.y - half_extents.y
					var object_top = obj_pos.y + half_extents.y
					
					# Smooth falloff for displacement
					var falloff = 1.0 - smoothstep(0.0, 1.3, horizontal_dist)
					
					# If object is below water surface, push water up
					if object_top < water_height:
						# Object is fully submerged - displace water upward
						var displacement = (water_height - object_top) * falloff * 0.2
						height_map[x][z] += displacement
					elif object_bottom < water_height:
						# Object is partially submerged - create depression
						var penetration = water_height - object_bottom
						var target_height = object_bottom + penetration * 0.1
						height_map[x][z] = lerp(height_map[x][z], target_height, falloff * 0.3)
					
					# Create wake behind moving objects
					if obj_vel.length() > 1.0:
						var wake_effect = obj_vel.length() * falloff * 0.01
						height_map[x][z] -= wake_effect * (1.0 - abs(dz))  # Wake trails behind

func _get_object_bounds(object: RigidBody3D) -> Vector3:
	# Try to get bounds from collision shape first
	for child in object.get_children():
		if child is CollisionShape3D and child.shape:
			if child.shape is BoxShape3D:
				return child.shape.size * object.scale
			elif child.shape is SphereShape3D:
				var r = child.shape.radius
				return Vector3(r * 2, r * 2, r * 2) * object.scale
			elif child.shape is CapsuleShape3D:
				var r = child.shape.radius
				var h = child.shape.height
				return Vector3(r * 2, h, r * 2) * object.scale
	
	# Fallback to mesh bounds
	var mesh_instance = object.find_child("MeshInstance3D", true, false)
	if mesh_instance and mesh_instance.mesh:
		return mesh_instance.mesh.get_aabb().size * object.scale
	
	# Default size based on mass
	var default_size = pow(object.mass / water_density, 1.0/3.0)
	return Vector3(default_size, default_size, default_size)

func _calculate_buoyancy_forces(delta):
	for object in buoyant_objects:
		if not is_instance_valid(object):
			continue
		
		_calculate_object_buoyancy(object, delta)

func _calculate_object_buoyancy(object: RigidBody3D, delta: float):
	var object_bounds = _get_object_bounds(object)
	if object_bounds == Vector3.ZERO:
		return
	
	var half_extents = object_bounds * 0.5
	var obj_pos = object.global_position
	
	# Create a grid of sample points through the object's volume
	var samples_per_axis = 5
	var sample_points = []
	
	for x in range(samples_per_axis):
		for y in range(samples_per_axis):
			for z in range(samples_per_axis):
				var local_point = Vector3(
					lerp(-half_extents.x, half_extents.x, (x + 0.5) / samples_per_axis),
					lerp(-half_extents.y, half_extents.y, (y + 0.5) / samples_per_axis),
					lerp(-half_extents.z, half_extents.z, (z + 0.5) / samples_per_axis)
				)
				sample_points.append(local_point)
	
	var total_submerged_volume = 0.0
	var center_of_buoyancy = Vector3.ZERO
	var total_drag_force = Vector3.ZERO
	var sample_volume = object_bounds.x * object_bounds.y * object_bounds.z / (samples_per_axis * samples_per_axis * samples_per_axis)
	
	for local_point in sample_points:
		var world_point = object.to_global(local_point)
		var water_height = get_height_at_position(world_point)
		var depth = water_height - world_point.y
		
		if depth > 0:
			# This sample point is submerged
			total_submerged_volume += sample_volume
			center_of_buoyancy += world_point * sample_volume
			
			# Calculate water velocity at this point for drag
			var water_velocity = get_water_velocity_at(world_point)
			var relative_velocity = object.linear_velocity - water_velocity
			var point_drag = -relative_velocity * 0.5 * depth * sample_volume
			total_drag_force += point_drag
	
	if total_submerged_volume > 0:
		# Archimedes' principle: Buoyancy force = weight of displaced fluid
		var buoyancy_force = Vector3.UP * water_density * gravity * total_submerged_volume
		
		# Calculate center of buoyancy (centroid of submerged volume)
		center_of_buoyancy /= total_submerged_volume
		
		# Apply buoyancy force at center of buoyancy
		object.apply_force(buoyancy_force, center_of_buoyancy - obj_pos)
		
		# Apply drag forces
		object.apply_central_force(total_drag_force)
		
		# Angular drag (water resistance to rotation)
		var submerged_ratio = total_submerged_volume / (object_bounds.x * object_bounds.y * object_bounds.z)
		var angular_drag_factor = 1.0 - min(submerged_ratio * 2.0, 0.9)
		object.angular_velocity *= angular_drag_factor
		
		# Righting moment - tends to keep object upright
		var object_up = object.global_transform.basis.y
		if object_up.dot(Vector3.UP) < 0.99:
			var righting_axis = object_up.cross(Vector3.UP).normalized()
			var righting_strength = (1.0 - object_up.dot(Vector3.UP)) * submerged_ratio * 10.0
			object.apply_torque(righting_axis * righting_strength)
		
		# Wind-driven water currents affect object more
		if wind_system and wind_system.has_method("get_wind_at_position"):
			var wind = wind_system.get_wind_at_position(obj_pos)
			var wind_drift = Vector3(wind.x, 0, wind.z) * submerged_ratio * 0.01
			object.apply_central_force(wind_drift * object.mass)

func _propagate_waves(delta):
	# Store current heights
	for x in range(1, grid_size.x):
		for z in range(1, grid_size.y):
			previous_heights[x][z] = height_map[x][z]
	
	var wave_speed_sq = wave_speed * wave_speed * delta * delta
	
	for x in range(2, grid_size.x - 2):
		for z in range(2, grid_size.y - 2):
			# 2D wave equation using finite differences
			var d2x = height_map[x+1][z] - 2*height_map[x][z] + height_map[x-1][z]
			var d2z = height_map[x][z+1] - 2*height_map[x][z] + height_map[x][z-1]
			
			# Update using wave equation
			var new_height = 2*height_map[x][z] - previous_heights[x][z] + wave_speed_sq * (d2x + d2z)
			
			# Apply damping
			new_height = lerp(new_height, base_height, 1.0 - damping)
			
			# Store velocity
			velocity_map[x][z] = (new_height - previous_heights[x][z]) / max(delta, 0.001)
			
			# Update foam
			var steepness = abs(d2x) + abs(d2z)
			if steepness > foam_threshold:
				foam_map[x][z] = min(foam_map[x][z] + delta * 3.0, 1.0)
			else:
				foam_map[x][z] = max(foam_map[x][z] - delta * 2.0, 0.0)
			
			height_map[x][z] = new_height

func _apply_boundary_conditions():
	# Absorbing boundaries to prevent wave reflection
	var absorption = 5
	for i in range(grid_size.x + 1):
		for z in range(absorption):
			var factor = float(z) / absorption
			height_map[i][z] = lerp(height_map[i][z], base_height, factor)
			height_map[i][grid_size.y - z] = lerp(height_map[i][grid_size.y - z], base_height, factor)
	
	for i in range(grid_size.y + 1):
		for x in range(absorption):
			var factor = float(x) / absorption
			height_map[x][i] = lerp(height_map[x][i], base_height, factor)
			height_map[grid_size.x - x][i] = lerp(height_map[grid_size.x - x][i], base_height, factor)

func get_height_at_position(world_pos: Vector3) -> float:
	var local_pos = world_pos - global_position
	var grid_x = clampi(int(local_pos.x / cell_size), 0, grid_size.x)
	var grid_z = clampi(int(local_pos.z / cell_size), 0, grid_size.y)
	
	# Bilinear interpolation
	var frac_x = clampf(local_pos.x / cell_size - grid_x, 0.0, 1.0)
	var frac_z = clampf(local_pos.z / cell_size - grid_z, 0.0, 1.0)
	
	var next_x = min(grid_x + 1, grid_size.x)
	var next_z = min(grid_z + 1, grid_size.y)
	
	var h00 = height_map[grid_x][grid_z]
	var h10 = height_map[next_x][grid_z]
	var h01 = height_map[grid_x][next_z]
	var h11 = height_map[next_x][next_z]
	
	return lerp(lerp(h00, h10, frac_x), lerp(h01, h11, frac_x), frac_z)

func get_water_velocity_at(world_pos: Vector3) -> Vector3:
	var local_pos = world_pos - global_position
	var grid_x = clampi(int(local_pos.x / cell_size), 1, grid_size.x - 1)
	var grid_z = clampi(int(local_pos.z / cell_size), 1, grid_size.y - 1)
	
	# Calculate gradient for horizontal velocity
	var dh_dx = (height_map[grid_x + 1][grid_z] - height_map[grid_x - 1][grid_z]) / (2 * cell_size)
	var dh_dz = (height_map[grid_x][grid_z + 1] - height_map[grid_x][grid_z - 1]) / (2 * cell_size)
	
	# Add wind-driven surface current
	var wind_current = Vector3.ZERO
	if wind_system and wind_system.has_method("get_wind_at_position"):
		var wind = wind_system.get_wind_at_position(world_pos + global_position)
		wind_current = Vector3(wind.x, 0, wind.z) * 0.02  # 2% of wind speed
	
	return Vector3(-dh_dx * wave_speed, velocity_map[grid_x][grid_z], -dh_dz * wave_speed) + wind_current

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
					height_map[nx][nz] += intensity * falloff

func _update_splashes(delta):
	var active = []
	for splash in splashes:
		splash.age += delta
		if splash.age < splash.lifetime:
			active.append(splash)
	splashes = active

func register_buoyant_object(object: RigidBody3D):
	if object not in buoyant_objects:
		buoyant_objects.append(object)

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
	
	var material = StandardMaterial3D.new()
	material.albedo_color = wave_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.1
	material.metallic = 0.1
	mesh_instance.material_override = material
	
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
	mesh_instance.mesh = st.commit()

# Helper function (Godot might not have this built-in)
func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
