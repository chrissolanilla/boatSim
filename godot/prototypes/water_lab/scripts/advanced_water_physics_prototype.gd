extends Node
class_name AdvancedWaterPhysics

@export var water_manager: WaterManager
@export var wind_strength := 1.0
@export var wind_direction := Vector3(1, 0, 0)
@export var wave_amplitude := 0.5
@export var wave_frequency := 0.5

var time: float = 0.0
var perlin_noise: FastNoiseLite

func _ready():
	perlin_noise = FastNoiseLite.new()
	perlin_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	perlin_noise.frequency = 0.05
	perlin_noise.fractal_octaves = 4

func _physics_process(delta):
	if not water_manager:
		return
	
	time += delta
	_generate_wind_waves(delta)
	_apply_environmental_forces(delta)

func _generate_wind_waves(delta):
	for x in range(water_manager.grid_size.x):
		for z in range(water_manager.grid_size.y):
			var world_x = x * water_manager.cell_size
			var world_z = z * water_manager.cell_size
			
			# Gerstner waves
			var wave1 = sin(world_x * 0.5 + time * wave_frequency) * wave_amplitude
			var wave2 = cos(world_z * 0.3 + time * wave_frequency * 1.3) * wave_amplitude * 0.7
			var wave3 = sin((world_x + world_z) * 0.4 + time * wave_frequency * 0.7) * wave_amplitude * 0.5
			
			# Wind effect
			var wind_effect = perlin_noise.get_noise_2d(world_x * 0.1 + time * 0.5, world_z * 0.1) * wind_strength
			
			water_manager.height_map[x][z] += (wave1 + wave2 + wave3 + wind_effect) * delta * 0.1

func _apply_environmental_forces(delta):
	# Apply to all buoyant objects
	for object in water_manager.buoyant_objects:
		if is_instance_valid(object):
			# Wind force on exposed parts
			var wind_force = wind_direction.normalized() * wind_strength * 10.0
			object.apply_central_force(wind_force * delta)
			
			# Current drift
			var water_velocity = water_manager.get_water_velocity_at(object.global_position)
			var drift_force = water_velocity * 50.0
			object.apply_central_force(drift_force * delta)
