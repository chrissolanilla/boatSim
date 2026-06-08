extends GPUParticles3D

func trigger_splash(position: Vector3, strength: float):
	global_position = position
	
	# Adjust emission based on strength
	amount = int(strength * 50)
	one_shot = true
	emitting = true
	
	# Auto-queue free after particles finish
	await get_tree().create_timer(2.0).timeout
	queue_free()

## To use: SplashEffect.trigger_splash(water_position, splash_strength)
