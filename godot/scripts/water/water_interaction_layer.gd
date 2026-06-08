extends Node3D

@export var water_physics: Node3D
@export var debug_mode: bool = true

func _ready():
	if not water_physics:
		water_physics = get_node("/root/WaterWorld/WaterManager")
	
	if water_physics:
		print("✓ Water manager found")

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position)

func _handle_click(mouse_pos: Vector2):
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# Set collision mask to detect water (layer 1)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_pos = result.position
		var hit_name = result.collider.name if result.collider else "Unknown"
		
		print("✓ Hit: ", hit_name, " at position: ", hit_pos)
		
		# Create splash effect
		_create_splash(hit_pos)
	else:
		print("No hit detected - make sure water has collision")

func _create_splash(position: Vector3):
	# Get water height for correct splash position
	var splash_y = position.y
	if water_physics and water_physics.has_method("get_water_height"):
		splash_y = water_physics.get_water_height(position.x, position.z) + 0.1
	
	var splash_pos = Vector3(position.x, splash_y, position.z)
	
	# Create expanding ring effect (works every time)
	var ring = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.15
	cylinder.bottom_radius = 0.15
	cylinder.height = 0.05
	ring.mesh = cylinder
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.8, 1.0, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	
	ring.position = splash_pos
	add_child(ring)
	
	# Animate ring
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector3(3, 1, 3), 0.6)
	tween.parallel().tween_property(material, "albedo_color", Color(0.7, 0.8, 1.0, 0), 0.6)
	tween.tween_callback(ring.queue_free)
	
	# Also add some particles
	_add_particles(splash_pos)

func _add_particles(position: Vector3):
	var particles = GPUParticles3D.new()
	particles.one_shot = true
	particles.lifetime = 0.8
	particles.amount = 20
	particles.position = position
	
	var process_material = ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, 1, 0)
	process_material.spread = 80.0
	process_material.gravity = Vector3(0, -10, 0)
	process_material.initial_velocity_min = 2.0
	process_material.initial_velocity_max = 5.0
	particles.process_material = process_material
	
	var quad = QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	particles.draw_pass_1 = quad
	
	var particle_material = StandardMaterial3D.new()
	particle_material.albedo_color = Color(0.6, 0.7, 0.95, 0.7)
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = particle_material
	
	add_child(particles)
	particles.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()
