extends Node3D

@export_group("Wind Settings")
@export var wind_direction := Vector3(1, 0, 0.5)  # Base direction
@export var wind_speed := 8.0  # m/s (increased for noticeable effect)
@export var gust_frequency := 0.3
@export var gust_strength_variation := 0.7  # More variation
@export var wind_gustiness := 0.4

@export_group("Water Interaction")
@export var wave_generation_strength := 0.15
@export var wind_wave_size := 0.4

@export_group("Vehicle Interaction")
@export var vehicle_wind_force_multiplier := 2.0  # Increased
@export var sail_force_multiplier := 3.0

var current_wind_vector: Vector3
var gust_time: float = 0.0
var gust_timer: float = 0.0
var gust_strength: float = 0.0
var gust_duration: float = 0.0
var target_gust_strength: float = 0.0

var noise: FastNoiseLite
var time: float = 0.0

func _ready():
	add_to_group("wind_system")
	
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01
	noise.fractal_octaves = 3
	
	current_wind_vector = wind_direction.normalized() * wind_speed
	gust_timer = randf_range(1.0, 3.0)
	
	print("Wind System initialized: Direction=%s, Speed=%.1f m/s" % [wind_direction, wind_speed])

func _physics_process(delta):
	time += delta
	_update_wind(delta)
	_generate_gusts(delta)

func _update_wind(delta):
	# Base wind
	var base_wind = wind_direction.normalized() * wind_speed
	
	# Natural variation using noise
	var noise_value = noise.get_noise_2d(time * 0.1, 0)
	var variation = noise_value * wind_gustiness * wind_speed
	var varying_wind = base_wind + wind_direction.normalized() * variation
	
	# Add gust effect
	var gust_wind = wind_direction.normalized() * gust_strength
	
	# Combine
	var target_wind = varying_wind + gust_wind
	current_wind_vector = current_wind_vector.lerp(target_wind, delta * 0.5)
	
	# Directional variation
	var directional_noise = noise.get_noise_2d(0, time * 0.05)
	var perpendicular = Vector3(wind_direction.z, 0, -wind_direction.x).normalized()
	current_wind_vector += perpendicular * directional_noise * wind_speed * 0.3

func _generate_gusts(delta):
	gust_timer -= delta
	
	if gust_timer <= 0:
		# Start new gust
		gust_timer = randf_range(1.0 / gust_frequency, 3.0 / gust_frequency)
		gust_duration = randf_range(1.0, 4.0)
		target_gust_strength = wind_speed * randf_range(-gust_strength_variation, gust_strength_variation * 1.5)
	
	if gust_duration > 0:
		gust_duration -= delta
		gust_strength = lerp(gust_strength, target_gust_strength, delta * 2.0)
	else:
		gust_strength = lerp(gust_strength, 0.0, delta * 1.0)

func get_wind_at_position(position: Vector3) -> Vector3:
	# Spatial variation
	var spatial_noise = noise.get_noise_3d(position.x * 0.05, position.y * 0.05, position.z * 0.05)
	var spatial_variation = spatial_noise * wind_speed * 0.4
	
	# Height-based variation (wind stronger higher up)
	var height_factor = clamp(position.y * 0.1, 0.0, 1.5)
	var height_wind = wind_direction.normalized() * wind_speed * height_factor * 0.3
	
	return current_wind_vector + wind_direction.normalized() * spatial_variation + height_wind

# Debug - draw wind arrows in editor
func _draw_wind_debug():
	if not Engine.is_editor_hint():
		return
	
	# This helps visualize wind in the editor
	var debug_parent = get_node_or_null("DebugWindVisuals")
	if not debug_parent:
		debug_parent = Node3D.new()
		debug_parent.name = "DebugWindVisuals"
		add_child(debug_parent)
