extends Node3D
class_name WindSystem

# ============================================================
# WIND SYSTEM - Affects water grid (waves) AND objects (forces)
# Add to your main scene, put in "wind_system" group
# ============================================================

@export_group("Wind Settings")
@export var wind_direction: Vector3 = Vector3(1.0, 0.0, 0.5)
@export var wind_speed: float = 8.0
@export var gust_frequency: float = 0.3
@export var gust_strength_variation: float = 0.5

@export_group("Water Interaction")
@export var affect_water: bool = true
@export var wave_generation_strength: float = 0.15

@export_group("Object Interaction")
@export var affect_objects: bool = true
@export var push_force_multiplier: float = 1.0

var current_wind_vector: Vector3
var gust_strength: float = 0.0
var gust_timer: float = 0.0
var gust_duration: float = 0.0
var target_gust_strength: float = 0.0
var time: float = 0.0
var noise: FastNoiseLite

func _ready() -> void:
	add_to_group("wind_system")
	
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01
	noise.fractal_octaves = 3
	
	current_wind_vector = wind_direction.normalized() * wind_speed
	gust_timer = randf_range(1.0, 3.0)

func _physics_process(delta: float) -> void:
	time += delta
	_update_wind(delta)
	_generate_gusts(delta)
	
	if affect_objects:
		_apply_wind_to_all_objects(delta)

# ============================================================
# WIND CALCULATION
# ============================================================

func _update_wind(delta: float) -> void:
	var base_wind: Vector3 = wind_direction.normalized() * wind_speed
	var variation: float = noise.get_noise_2d(time * 0.1, 0.0) * 0.3 * wind_speed
	var varying_wind: Vector3 = base_wind + wind_direction.normalized() * variation
	var gust_wind: Vector3 = wind_direction.normalized() * gust_strength
	var target: Vector3 = varying_wind + gust_wind
	
	# Directional wobble
	var dir_noise: float = noise.get_noise_2d(0.0, time * 0.05)
	var perpendicular: Vector3 = Vector3(wind_direction.z, 0.0, -wind_direction.x).normalized()
	target += perpendicular * dir_noise * wind_speed * 0.2
	
	current_wind_vector = current_wind_vector.lerp(target, delta * 0.5)

func _generate_gusts(delta: float) -> void:
	gust_timer -= delta
	if gust_timer <= 0.0:
		gust_timer = randf_range(1.0 / gust_frequency, 3.0 / gust_frequency)
		gust_duration = randf_range(1.0, 4.0)
		target_gust_strength = wind_speed * randf_range(-gust_strength_variation, gust_strength_variation * 1.5)
	
	if gust_duration > 0.0:
		gust_duration -= delta
		gust_strength = lerp(gust_strength, target_gust_strength, delta * 2.0)
	else:
		gust_strength = lerp(gust_strength, 0.0, delta * 1.0)

# ============================================================
# PUBLIC API
# ============================================================

func get_wind_at_position(position: Vector3) -> Vector3:
	# Spatial variation based on Perlin noise
	var spatial: float = noise.get_noise_3d(position.x * 0.05, position.y * 0.05, position.z * 0.05)
	var spatial_var: Vector3 = wind_direction.normalized() * spatial * wind_speed * 0.4
	
	# Height variation (wind stronger higher up)
	var height_factor: float = clamp(position.y * 0.1, 0.0, 1.5)
	var height_var: Vector3 = wind_direction.normalized() * wind_speed * height_factor * 0.3
	
	return current_wind_vector + spatial_var + height_var

# ============================================================
# APPLY WIND TO OBJECTS
# ============================================================

func _apply_wind_to_all_objects(delta: float) -> void:
	# Find all RigidBody3D objects in the scene that are on water
	var objects: Array = get_tree().get_nodes_in_group("buoyant_objects")
	if objects.is_empty():
		# Try finding buoyant objects from water manager
		var wm = get_tree().get_first_node_in_group("water_manager")
		if wm and wm.has_method("register_buoyant_object"):
			objects = wm.buoyant_objects
	
	for object in objects:
		if not is_instance_valid(object):
			continue
		if not object is RigidBody3D:
			continue
		_apply_wind_to_object(object, delta)

func _apply_wind_to_object(object: RigidBody3D, delta: float) -> void:
	var wind: Vector3 = get_wind_at_position(object.global_position)
	var wind_strength: float = wind.length()
	
	if wind_strength < 0.5:
		return
	
	# Relative wind (apparent wind)
	var relative_wind: Vector3 = wind - object.linear_velocity
	
	# Get object's exposed area
	var exposed_area: float = _estimate_exposed_area(object)
	
	# Aerodynamic drag force: F = 0.5 * air_density * area * Cd * v^2
	var air_density: float = 1.225
	var drag_coefficient: float = 0.8
	var wind_force: Vector3 = relative_wind.normalized() * relative_wind.length_squared() * air_density * exposed_area * drag_coefficient * 0.5 * push_force_multiplier
	
	# Apply force at center of pressure (slightly above center)
	object.apply_central_force(wind_force * delta * 60.0)
	
	# Wind torque (weathervaning effect)
	var forward: Vector3 = -object.global_transform.basis.z
	var wind_dir_2d: Vector3 = Vector3(relative_wind.x, 0.0, relative_wind.z).normalized()
	var forward_2d: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
	
	if wind_dir_2d.length() > 0.1 and forward_2d.length() > 0.1:
		var cross: Vector3 = forward_2d.cross(wind_dir_2d)
		var torque: Vector3 = Vector3.UP * cross.y * wind_strength * 0.05
		object.apply_torque(torque * delta * 60.0)

func _estimate_exposed_area(object: RigidBody3D) -> float:
	# Estimate based on collision shape or mass
	for child in object.get_children():
		if child is CollisionShape3D and child.shape:
			if child.shape is BoxShape3D:
				var size: Vector3 = child.shape.size * object.scale
				return (size.x * size.y + size.y * size.z) * 0.5  # Average of front and side
			elif child.shape is SphereShape3D:
				var r: float = child.shape.radius * max(object.scale.x, max(object.scale.y, object.scale.z))
				return PI * r * r
	
	return pow(object.mass, 2.0/3.0) * 0.5

# ============================================================
# WIND EFFECT ON WATER (called by water manager)
# ============================================================

func apply_wind_to_water_grid(height_map: Array, grid_size: Vector2i, cell_size: float, foam_map: Array, wind_time: float, delta: float) -> void:
	if not affect_water:
		return
	
	var wind_dir: Vector3 = Vector3(current_wind_vector.x, 0.0, current_wind_vector.z).normalized()
	var ws: float = current_wind_vector.length()
	if ws < 0.2: return
	
	for x in range(0, grid_size.x + 1, 4):
		for z in range(0, grid_size.y + 1, 4):
			var wx: float = x * cell_size
			var wz: float = z * cell_size
			
			# Wind-wave generation (JONSWAP simplified)
			var fetch: float = Vector2(wx, wz).dot(Vector2(wind_dir.x, wind_dir.z))
			var peak_freq: float = 0.87 * pow(ws, -0.67)
			var significant_height: float = 0.021 * ws * ws
			var phase: float = fetch * peak_freq - wind_time * TAU * peak_freq
			
			var wave_height: float = 0.0
			for i in range(3):
				wave_height += sin(phase * (1.0 + i * 0.2) + i * 1.5) * significant_height * exp(-i * 0.5) * 0.3 * wave_generation_strength
			
			if x < height_map.size() and z < height_map[x].size():
				height_map[x][z] = lerp(height_map[x][z], height_map[x][z] + wave_height, 0.1)
				
				# Spread to neighbors
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						if dx == 0 and dz == 0: continue
						var nx: int = x + dx; var nz: int = z + dz
						if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
							height_map[nx][nz] = lerp(height_map[nx][nz], height_map[nx][nz] + wave_height * exp(-sqrt(dx*dx+dz*dz)) * 0.3, 0.05)
				
				if abs(wave_height) > significant_height * 0.6:
					if x < foam_map.size() and z < foam_map[x].size():
						foam_map[x][z] = min(foam_map[x][z] + delta * 2.0, 1.0)
						
