extends GPUParticles3D

@export var water_physics: AdvancedWaterPhysics
@export var follow_object: Node3D

func _process(delta: float):
	if follow_object:
		global_position = follow_object.global_position
		
		# Create wake particles based on speed
		if follow_object is BuoyantObject:
			var speed = follow_object.linear_velocity.length()
			emitting = speed > 2.0
			
			if emitting:
				var emission_rate = min(speed * 50, 500)
				process_material.emission_rect_extents.x = speed * 0.5
