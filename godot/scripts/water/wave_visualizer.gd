extends Node3D

@export var water_manager: Node3D
@export var particle_count: int = 50
@export var area_size: float = 50.0

func _ready():
	_create_visualizers()

func _create_visualizers():
	# Create floating particles that move with waves
	for i in range(particle_count):
		var particle = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.1
		particle.mesh = sphere
		
		# Random position
		var x = randf_range(-area_size, area_size)
		var z = randf_range(-area_size, area_size)
		particle.position = Vector3(x, 0, z)
		
		# Random color (bright colors stand out)
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(randf(), randf(), randf(), 0.8)
		material.emission_enabled = true
		material.emission = material.albedo_color * 0.5
		particle.material_override = material
		
		add_child(particle)
		
		# Store data
		particle.set_meta("speed", randf_range(0.5, 2.0))
		particle.set_meta("offset", randf() * PI * 2)

func _process(delta):
	if not water_manager:
		return
	
	for particle in get_children():
		var x = particle.position.x
		var z = particle.position.z
		var water_height = water_manager.get_water_height(x, z)
		particle.position.y = water_height + 0.1
		
		# Bobbing animation
		var bob = sin(Time.get_ticks_msec() * 0.003 * particle.get_meta("speed") + particle.get_meta("offset")) * 0.05
		particle.position.y += bob
