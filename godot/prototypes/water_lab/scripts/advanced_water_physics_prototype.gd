extends Node
class_name AdvancedWaterPhysics

# ============================================================
# Advanced Water Physics - Handles ONLY:
# - Wave generation (Gerstner waves, wind waves, Perlin noise)
# - Environmental forces (wind on objects, water currents)
# - Wave spectrum calculations
# ============================================================

@export_group("Wave Settings")
@export var water_manager: Node3D
@export var wave_amplitude: float = 0.5
@export var wave_frequency: float = 0.5
@export var wave_choppiness: float = 0.3
@export var wave_direction: Vector2 = Vector2(0.7, 0.3)

@export_group("Wind Waves")
@export var wind_wave_enabled: bool = true
@export var wind_strength: float = 5.0
@export var wind_direction: Vector3 = Vector3(1.0, 0.0, 0.5)
@export var fetch_distance: float = 100.0

@export_group("Environmental Forces")
@export var apply_wind_to_objects: bool = true
@export var apply_currents_to_objects: bool = true
@export var wind_force_scale: float = 10.0
@export var current_force_scale: float = 50.0

var time: float = 0.0
var perlin_noise: FastNoiseLite
var wind_system: Node3D

# Pre-calculated wave parameters
var _wave_params: Array[Dictionary] = []

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	perlin_noise = FastNoiseLite.new()
	perlin_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	perlin_noise.frequency = 0.05
	perlin_noise.fractal_octaves = 4
	perlin_noise.fractal_lacunarity = 2.0
	perlin_noise.fractal_gain = 0.5
	
	wind_system = get_tree().get_first_node_in_group("wind_system")
	
	_generate_wave_spectrum()

func _generate_wave_spectrum() -> void:
	# Pre-calculate wave parameters for different frequencies
	var directions: Array[Vector2] = [
		wave_direction,
		wave_direction.rotated(PI * 0.15),
		wave_direction.rotated(-PI * 0.1),
	]
	
	var amplitudes: Array[float] = [1.0, 0.7, 0.5, 0.3, 0.2]
	var frequencies: Array[float] = [1.0, 1.3, 1.7, 2.1, 2.5]
	var speeds: Array[float] = [1.0, 0.85, 0.7, 0.55, 0.4]
	
	for dir in directions:
		for i in range(amplitudes.size()):
			_wave_params.append({
				"direction": dir,
				"amplitude": amplitudes[i] * wave_amplitude,
				"frequency": frequencies[i] * wave_frequency,
				"speed": speeds[i],
				"phase": randf() * TAU
			})

# ============================================================
# PHYSICS PROCESS
# ============================================================

func _physics_process(delta: float) -> void:
	if not water_manager:
		return
	
	time += delta
	
	if water_manager.has_method("_propagate_waves"):
		_apply_wave_height_field(delta)
	
	if apply_wind_to_objects or apply_currents_to_objects:
		_apply_environmental_forces(delta)

# ============================================================
# WAVE GENERATION
# ============================================================

func _apply_wave_height_field(delta: float) -> void:
	if not water_manager.has_method("get_height_at_position"):
		return
	
	var grid_size: Vector2i = water_manager.grid_size
	var cell_size: float = water_manager.cell_size
	
	for x in range(0, grid_size.x + 1, 4):
		for z in range(0, grid_size.y + 1, 4):
			var world_x: float = x * cell_size
			var world_z: float = z * cell_size
			
			var height: float = _calculate_wave_height(Vector2(world_x, world_z))
			
			if water_manager.height_map.size() > x and water_manager.height_map[x].size() > z:
				water_manager.height_map[x][z] += height * delta * 0.5
				
				# Propagate to neighbors
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						var nx: int = x + dx
						var nz: int = z + dz
						if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
							var dist: float = sqrt(dx * dx + dz * dz)
							water_manager.height_map[nx][nz] += height * delta * 0.5 * exp(-dist) * 0.4
	
	# Apply wind waves separately
	if wind_wave_enabled and wind_system and wind_system.has_method("get_wind_at_position"):
		_apply_wind_waves(delta)

func _calculate_wave_height(position: Vector2) -> float:
	var height: float = 0.0
	
	for wave in _wave_params:
		var dir: Vector2 = wave["direction"]
		var amp: float = wave["amplitude"]
		var freq: float = wave["frequency"]
		var speed: float = wave["speed"]
		var phase: float = wave["phase"]
		
		var dot_product: float = position.dot(dir)
		var wave_phase: float = dot_product * freq + time * speed + phase
		
		height += sin(wave_phase) * amp
		height += cos(wave_phase * 1.3) * amp * 0.3  # Secondary harmonic
	
	# Add Perlin noise for natural variation
	var noise_val: float = perlin_noise.get_noise_2d(position.x * 0.05 + time * 0.1, position.y * 0.05)
	height += noise_val * wave_amplitude * 0.2
	
	return height

func _apply_wind_waves(delta: float) -> void:
	if not wind_system:
		return
	
	var wind: Vector3 = wind_system.get_wind_at_position(water_manager.global_position)
	var wind_speed: float = wind.length()
	var wind_dir: Vector2 = Vector2(wind.x, wind.z).normalized()
	
	if wind_speed < 0.5:
		return
	
	var grid_size: Vector2i = water_manager.grid_size
	var cell_size: float = water_manager.cell_size
	
	# JONSWAP spectrum parameters
	var significant_height: float = 0.021 * wind_speed * wind_speed
	var peak_freq: float = 0.87 * pow(wind_speed, -0.67)
	
	for x in range(0, grid_size.x + 1, 5):
		for z in range(0, grid_size.y + 1, 5):
			var world_x: float = x * cell_size
			var world_z: float = z * cell_size
			var pos: Vector2 = Vector2(world_x, world_z)
			
			var fetch: float = pos.dot(wind_dir)
			var wave_phase: float = fetch * peak_freq - time * TAU * peak_freq
			
			var wind_wave: float = 0.0
			for i in range(3):
				var amp: float = significant_height * exp(-i * 0.5) * 0.3
				wind_wave += sin(wave_phase * (1.0 + i * 0.2) + i * 1.5) * amp * wind_strength * 0.01
			
			if water_manager.height_map.size() > x and water_manager.height_map[x].size() > z:
				water_manager.height_map[x][z] += wind_wave * delta

# ============================================================
# ENVIRONMENTAL FORCES ON OBJECTS
# ============================================================

func _apply_environmental_forces(delta: float) -> void:
	if not water_manager.has_method("register_buoyant_object"):
		return
	
	var objects: Array = water_manager.buoyant_objects
	if objects.is_empty():
		return
	
	for object in objects:
		if not is_instance_valid(object):
			continue
		
		# Skip objects with their own wind handling (BoatController)
		if object.has_method("_apply_wind"):
			continue
		
		if apply_wind_to_objects:
			_apply_wind_force(object, delta)
		
		if apply_currents_to_objects and water_manager.has_method("get_water_velocity_at"):
			_apply_current_force(object, delta)

func _apply_wind_force(object: RigidBody3D, delta: float) -> void:
	var wind: Vector3 = wind_direction.normalized() * wind_strength
	if wind_system and wind_system.has_method("get_wind_at_position"):
		wind = wind_system.get_wind_at_position(object.global_position)
	
	var relative_wind: Vector3 = wind - object.linear_velocity
	var wind_force: Vector3 = relative_wind.normalized() * relative_wind.length_squared() * 0.6125
	object.apply_central_force(wind_force * wind_force_scale * delta)

func _apply_current_force(object: RigidBody3D, delta: float) -> void:
	var water_vel: Vector3 = water_manager.get_water_velocity_at(object.global_position)
	var relative_vel: Vector3 = water_vel - object.linear_velocity
	object.apply_central_force(relative_vel * current_force_scale * delta)

# ============================================================
# PUBLIC API - Can be called by other systems
# ============================================================

func get_wave_height_at(position: Vector2) -> float:
	return _calculate_wave_height(position)

func get_wave_normal_at(position: Vector2) -> Vector3:
	var eps: float = 0.1
	var h: float = _calculate_wave_height(position)
	var hx: float = _calculate_wave_height(position + Vector2(eps, 0))
	var hz: float = _calculate_wave_height(position + Vector2(0, eps))
	
	return Vector3((h - hx) / eps, 1.0, (h - hz) / eps).normalized()
