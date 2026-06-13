extends Node3D
class_name SplashManager

@export var water_manager: WaterManager
@export var splash_particle_scene: PackedScene
@export var max_splashes := 50

var active_splashes: Array[GPUParticles3D] = []

func create_splash(position: Vector3, velocity: Vector3, size: float):
	if active_splashes.size() >= max_splashes:
		var old_splash = active_splashes.pop_front()
		old_splash.queue_free()
	
	var splash = splash_particle_scene.instantiate()
	splash.global_position = position
	splash.emitting = true
	
	# Scale particles based on impact
	var particles = splash as GPUParticles3D
	if particles:
		particles.amount = int(size * 50)
		particles.lifetime = size * 0.5
	
	add_child(splash)
	active_splashes.append(splash)
	
	# Auto cleanup
	splash.finished.connect(func(): 
		active_splashes.erase(splash)
		splash.queue_free()
	)

func _on_object_entered_water(object: BuoyantObject):
	var impact_velocity = object.linear_velocity.length()
	if impact_velocity > 2.0:
		var splash_pos = object.global_position
		var splash_size = min(impact_velocity * 0.1, 3.0)
		create_splash(splash_pos, object.linear_velocity, splash_size)
		water_manager.create_splash(splash_pos, impact_velocity * 0.05)
