extends Node3D

@export var splash_scene: PackedScene
@export var water_manager: Node3D

func _ready():
	# Don't try to assign a GPUParticles3D to a PackedScene variable
	if not splash_scene:
		print("No splash scene assigned - will use fallback particles")

func trigger_splash(position: Vector3, strength: float = 1.0):
	# Create splash directly without needing a PackedScene
	_create_particle_splash(position, strength)

func _create_particle_splash(position: Vector3, strength: float):
	# Create particles directly
	var particles = GPUParticles3D.new()
	particles.one_shot = true
	particles.lifetime = 0.8
	particles.amount = int(20 * clamp(strength, 0.5, 3.0))
	particles.position = position
	
	# Create particle material
	var process_material = ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 1, 0)
	process_material.spread = 70.0
	process_material.gravity = Vector3(0, -12, 0)
	process_material.initial_velocity_min = 2.0
	process_material.initial_velocity_max = 5.0
	particles.process_material = process_material
	
	# Create visual for particles
	var quad = QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	particles.draw_pass_1 = quad
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.7, 0.95, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = material
	
	add_child(particles)
	particles.emitting = true
	
	# Auto-remove after finishing
	await get_tree().create_timer(particles.lifetime + 0.3).timeout
	particles.queue_free()
	
	print("✓ Splash at: ", position)
