
# Water3D.gd - Attach to a Node3D as your water system
extends Node3D

# Grid configuration
@export var grid_width: int = 100    # Number of vertices along X
@export var grid_depth: int = 100    # Number of vertices along Z
@export var water_size: Vector2 = Vector2(20.0, 20.0)  # Size in world units

# Wave parameters (0% to 100%)
@export_range(0.0, 1.0) var wave_amplitude: float = 0.5:
	set(value):
		wave_amplitude = value
		update_shader_parameters()
@export_range(0.0, 1.0) var wave_frequency: float = 0.5:
	set(value):
		wave_frequency = value
		update_shader_parameters()
@export_range(0.0, 1.0) var wave_speed: float = 0.5:
	set(value):
		wave_speed = value
		update_shader_parameters()
@export_range(0.0, 1.0) var choppiness: float = 0.3:  # Makes waves sharper
	set(value):
		choppiness = value
		update_shader_parameters()

# Water appearance
@export var water_color: Color = Color(0.2, 0.5, 0.8)
@export var foam_color: Color = Color(0.9, 0.95, 1.0)
@export var wave_normal_strength: float = 1.5
@export var transparency: float = 0.85

# Physics parameters
@export var buoyancy_strength: float = 15.0
@export var water_drag: float = 3.0
@export var splash_force: float = 5.0

# Wave types (Gerstner waves for 3D realism)
class GerstnerWave:
	var direction: Vector2
	var amplitude: float
	var wavelength: float
	var speed: float
	var steepness: float
	
	func _init(dir: Vector2, amp: float, len: float, spd: float, steep: float):
		direction = dir.normalized()
		amplitude = amp
		wavelength = len
		speed = spd
		steepness = steep
	
	func get_displacement(pos: Vector3, time: float) -> Vector3:
		var k = 2.0 * PI / wavelength
		var freq = k * speed
		var dir_vec = Vector3(direction.x, 0, direction.y)
		var theta = k * dir_vec.dot(pos) + freq * time
		
		var dx = steepness * amplitude * direction.x * cos(theta)
		var dz = steepness * amplitude * direction.y * cos(theta)
		var dy = amplitude * sin(theta)
		
		return Vector3(dx, dy, dz)

var waves: Array[GerstnerWave] = []
var elapsed_time: float = 0.0

# Mesh and visual components
var mesh_instance: MeshInstance3D
var water_material: ShaderMaterial
var wave_texture: ViewportTexture
var foam_particles: GPUParticles3D

# Physics bodies in water
var bodies_in_water: Dictionary = {}  # body -> {submerged_ratio, splash_timer}

func _ready():
	setup_waves()
	create_water_mesh()
	create_water_material()
	create_foam_system()
	setup_physics_area()
	
func setup_waves():
	# Create multiple Gerstner waves for realistic 3D water
	waves = [
		GerstnerWave.new(Vector2(1, 0), 0.08, 2.0, 1.2, 0.5),
		GerstnerWave.new(Vector2(0.7, 0.7), 0.06, 1.5, 0.9, 0.4),
		GerstnerWave.new(Vector2(-0.5, 0.8), 0.05, 1.2, 1.5, 0.3),
		GerstnerWave.new(Vector2(0.3, -0.9), 0.04, 0.8, 2.0, 0.2),
		GerstnerWave.new(Vector2(-0.8, -0.2), 0.07, 1.8, 0.7, 0.45)
	]

func create_water_mesh():
	# Create dynamic mesh for water surface
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Generate vertices, UVs, and indices
	var vertices = []
	var uvs = []
	var indices = []
	
	# Build vertex and UV arrays first
	for z in range(grid_depth):
		for x in range(grid_width):
			var u = float(x) / (grid_width - 1)
			var v = float(z) / (grid_depth - 1)
			var x_pos = (u - 0.5) * water_size.x
			var z_pos = (v - 0.5) * water_size.y
			
			vertices.append(Vector3(x_pos, 0, z_pos))
			uvs.append(Vector2(u, v))  # UV coordinates for texturing
	
	# Generate triangle indices
	for z in range(grid_depth - 1):
		for x in range(grid_width - 1):
			var idx = z * grid_width + x
			# First triangle
			indices.append(idx)
			indices.append(idx + grid_width)
			indices.append(idx + 1)
			# Second triangle
			indices.append(idx + 1)
			indices.append(idx + grid_width)
			indices.append(idx + grid_width + 1)
	
	# Add ALL vertices first with their UVs
	for i in range(vertices.size()):
		surface_tool.set_uv(uvs[i])  # Set UV before adding vertex
		surface_tool.add_vertex(vertices[i])
	
	# Add indices (triangles)
	for i in range(0, indices.size(), 3):
		surface_tool.add_index(indices[i])
		surface_tool.add_index(indices[i+1])
		surface_tool.add_index(indices[i+2])
	
	# Generate normals and tangents for lighting
	surface_tool.generate_normals()
	surface_tool.generate_tangents()
	
	# Commit the mesh
	var mesh = surface_tool.commit()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

func create_water_material():
	water_material = ShaderMaterial.new()
	
	var shader_code = """
    shader_type spatial;
    render_mode blend_mix, depth_draw_opaque, cull_back;
    
    uniform sampler2D wave_texture : source_color;
    uniform vec4 water_color : source_color = vec4(0.2, 0.5, 0.8, 0.85);
    uniform vec4 foam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
    uniform float wave_strength = 0.5;
    uniform float wave_frequency = 2.0;
    uniform float wave_speed = 1.5;
    uniform float choppiness = 0.3;
    uniform float normal_strength = 1.5;
    uniform float time;
    
    // Random function for foam
    float random(vec2 uv) {
        return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
    }
    
    void vertex() {
        vec3 pos = VERTEX;
        vec2 uv = UV * wave_frequency;
        
        // Multiple wave layers for complexity
        float wave1 = sin(uv.x * 2.0 + time * wave_speed) * cos(uv.y * 1.8 + time * 0.9);
        float wave2 = sin(uv.y * 2.5 - time * 1.2) * 0.7;
        float wave3 = sin((uv.x * 1.5 + uv.y * 1.2) * 1.8 + time * 1.4) * 0.5;
        float wave4 = sin(uv.x * 4.0 + time * 2.0) * 0.3 * sin(uv.y * 3.0);
        
        float height = (wave1 + wave2 + wave3 + wave4) * wave_strength;
        
        // Choppiness effect (horizontal displacement for sharp waves)
        pos.x += wave1 * choppiness * wave_strength;
        pos.z += wave2 * choppiness * wave_strength;
        pos.y = height;
        
        VERTEX = pos;
        
        // Calculate normals for lighting
        vec3 tangent = vec3(1.0, 0.0, 0.0);
        vec3 bitangent = vec3(0.0, 0.0, 1.0);
        
        float hx = sin((uv.x + 0.05) * 2.0 + time * wave_speed) * cos(uv.y * 1.8 + time * 0.9) - wave1;
        float hz = sin(uv.x * 2.0 + time * wave_speed) * cos((uv.y + 0.05) * 1.8 + time * 0.9) - wave1;
        
        tangent.y = hx * wave_strength * normal_strength;
        bitangent.y = hz * wave_strength * normal_strength;
        
        NORMAL = normalize(cross(tangent, bitangent));
    }
    
    void fragment() {
        vec2 uv = UV * wave_frequency * 2.0;
        float foam_amount = 0.0;
        
        // Foam generation at wave peaks
        float wave_intensity = abs(sin(uv.x * 3.0 + time * wave_speed) * 
                                   cos(uv.y * 2.5 + time * 1.2)) * 0.5;
        
        // Random foam for realism
        foam_amount = step(0.85, wave_intensity + random(UV * 100.0) * 0.2);
        
        // Refraction effect
        vec2 refract_offset = vec2(sin(time * 2.0), cos(time * 1.7)) * 0.02;
        vec3 refraction = vec3(0.1, 0.3, 0.6) + vec3(0.05) * sin(UV.xyx * 10.0 + time);
        
        vec3 final_color = mix(water_color.rgb, refraction, 0.5);
        final_color = mix(final_color, foam_color.rgb, foam_amount);
        
        ALBEDO = final_color;
        METALLIC = 0.92;
        ROUGHNESS = 0.08 + foam_amount * 0.3;
        ALPHA = water_color.a;
        
        // Emission for foam
        EMISSION = foam_color.rgb * foam_amount * 0.5;
    }
    """
	
	var shader = Shader.new()
	shader.set_code(shader_code)
	water_material.shader = shader
	mesh_instance.material_override = water_material

func update_shader_parameters():
	if water_material:
		# Map 0-1 range to sensible shader values
		var mapped_strength = wave_amplitude * 0.3
		var mapped_freq = 1.0 + wave_frequency * 3.0
		var mapped_speed = 0.5 + wave_speed * 2.0
		var mapped_choppiness = choppiness * 0.5
		
		water_material.set_shader_parameter("wave_strength", mapped_strength)
		water_material.set_shader_parameter("wave_frequency", mapped_freq)
		water_material.set_shader_parameter("wave_speed", mapped_speed)
		water_material.set_shader_parameter("choppiness", mapped_choppiness)
		water_material.set_shader_parameter("water_color", water_color)
		water_material.set_shader_parameter("foam_color", foam_color)

func create_foam_system():
	foam_particles = GPUParticles3D.new()
	foam_particles.amount = 500
	foam_particles.lifetime = 0.8
	foam_particles.one_shot = false
	foam_particles.emitting = true
	foam_particles.explosiveness = 0.3
	
	var particle_material = ParticleProcessMaterial.new()
	
	# These properties exist in Godot 4
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 45.0
	particle_material.initial_velocity_min = 1.0
	particle_material.initial_velocity_max = 3.0
	particle_material.gravity = Vector3(0, -9.8, 0)
	particle_material.damping = 2.0
	particle_material.scale_min = 0.03
	particle_material.scale_max = 0.12
	
	# Set color with alpha
	particle_material.color = Color(0.9, 0.95, 1.0, 0.8)
	
	foam_particles.process_material = particle_material
	add_child(foam_particles)

func setup_physics_area():
	var area = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(water_size.x, 0.5, water_size.y)
	collision_shape.shape = box_shape
	area.add_child(collision_shape)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	area.body_shape_entered.connect(_on_body_contact)
	
	add_child(area)

func get_water_height_at_position(pos: Vector3) -> float:
	# Calculate height from Gerstner waves at any world position
	var local_pos = to_local(pos)
	var height = 0.0
	
	for wave in waves:
		var k = 2.0 * PI / wave.wavelength
		var freq = k * wave.speed
		var dir_vec = Vector3(wave.direction.x, 0, wave.direction.y)
		var theta = k * dir_vec.dot(local_pos) + freq * elapsed_time
		height += wave.amplitude * sin(theta)
		
		# Apply wave amplitude scaling (0-100% control)
		height *= wave_amplitude
	
	# Apply frequency scaling
	height *= (0.5 + wave_frequency)
	
	return global_position.y + height

func _on_body_entered(body: Node):
	if body is RigidBody3D or body is CharacterBody3D:
		if not bodies_in_water.has(body):
			bodies_in_water[body] = {
				"submerged_ratio": 0.0,
				"splash_timer": 0.0,
				"last_velocity": Vector3.ZERO
			}
			
			# Initial splash
			create_splash(body.global_position, body.linear_velocity.length() * 0.5)

func _on_body_exited(body: Node):
	bodies_in_water.erase(body)

func _on_body_contact(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int):
	# Handle collisions between objects in water
	if bodies_in_water.has(body) and body is RigidBody3D:
		var impact_force = body.linear_velocity.length()
		if impact_force > 2.0:
			create_splash(body.global_position, impact_force * 0.3)

func create_splash(position: Vector3, intensity: float):
	var local_pos = to_local(position)
	var particle_pos = global_position
	particle_pos.x = position.x
	particle_pos.z = position.z
	particle_pos.y = get_water_height_at_position(position)
	
	foam_particles.global_position = particle_pos
	
	# Emit burst of particles
	var burst_amount = min(50, int(intensity * 20))
	foam_particles.amount = burst_amount
	foam_particles.restart()
	foam_particles.amount = 1000  # Reset for continuous emission
	
	# Add ripple ring (using a simple mesh instance)
	var ring = MeshInstance3D.new()
	var ring_mesh = CylinderMesh.new()
	ring_mesh.top_radius = 0.2
	ring_mesh.bottom_radius = 0.2
	ring_mesh.height = 0.05
	ring.mesh = ring_mesh
	ring.position = particle_pos
	ring.scale = Vector3(intensity, 1, intensity)
	add_child(ring)
	
	# Animate and remove ring
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector3(intensity * 2, 0, intensity * 2), 0.5)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)

func apply_buoyancy(body: RigidBody3D, delta: float):
	if not bodies_in_water.has(body):
		return
	
	var body_pos = body.global_position
	var water_height = get_water_height_at_position(body_pos)
	var body_bottom = body_pos.y - (body.get_aabb().size.y * 0.5)
	
	var submerged_ratio = clamp((water_height - body_bottom) / body.get_aabb().size.y, 0.0, 1.0)
	bodies_in_water[body]["submerged_ratio"] = submerged_ratio
	
	if submerged_ratio > 0.01:
		# Buoyancy force (Archimedes principle)
		var buoyancy_force = Vector3.UP * buoyancy_strength * submerged_ratio * 9.8
		body.apply_central_force(buoyancy_force)
		
		# Drag force (water resistance)
		var drag = -body.linear_velocity * water_drag * submerged_ratio * delta
		body.apply_central_force(drag)
		
		# Angular drag
		body.apply_torque(-body.angular_velocity * 2.0 * submerged_ratio)
		
		# Wave force (push objects with wave motion)
		var wave_force = Vector3(
			sin(elapsed_time * 2.0 + body_pos.x) * wave_amplitude * 2.0,
			0,
			cos(elapsed_time * 1.5 + body_pos.z) * wave_amplitude * 2.0
		) * submerged_ratio * splash_force
		body.apply_central_force(wave_force)
		
		# Create splashes for fast-moving objects
		var speed = body.linear_velocity.length()
		if speed > 3.0 and bodies_in_water[body]["splash_timer"] <= 0:
			create_splash(body_pos, speed * 0.2)
			bodies_in_water[body]["splash_timer"] = 0.2
		else:
			bodies_in_water[body]["splash_timer"] -= delta

func _process(delta):
	elapsed_time += delta
	
	# Update shader time
	if water_material:
		water_material.set_shader_parameter("time", elapsed_time)
	
	# Update Gerstner wave mesh vertices
	update_vertex_displacements()
	
	# Update physics for bodies in water
	for body in bodies_in_water.keys():
		if is_instance_valid(body) and body is RigidBody3D:
			apply_buoyancy(body, delta)

func update_vertex_displacements():
	# Update each vertex based on Gerstner waves
	var mesh = mesh_instance.mesh
	var mesh_data_tool = MeshDataTool.new()
	mesh_data_tool.create_from_surface(mesh, 0)
	
	var vertex_count = mesh_data_tool.get_vertex_count()
	
	for i in range(vertex_count):
		var vertex = mesh_data_tool.get_vertex(i)
		var total_displacement = Vector3.ZERO
		
		for wave in waves:
			var displacement = wave.get_displacement(vertex, elapsed_time)
			displacement.y *= wave_amplitude
			displacement.x *= wave_amplitude * choppiness
			displacement.z *= wave_amplitude * choppiness
			total_displacement += displacement
		
		mesh_data_tool.set_vertex(i, vertex + total_displacement)
	
	# Recalculate normals for proper lighting
	mesh_data_tool.generate_normals()
	mesh_data_tool.commit_to_surface(mesh)
	mesh_instance.mesh = mesh

# Public function to manually add ripples
func add_ripple(position: Vector3, strength: float, radius: float = 1.0):
	create_splash(position, strength)
	
	# Apply force to nearby physics bodies
	var bodies = get_tree().get_nodes_in_group("physics_bodies")
	for body in bodies:
		if body is RigidBody3D and body.global_position.distance_to(position) < radius:
			var direction = (body.global_position - position).normalized()
			var force = direction * strength * splash_force * 10.0
			body.apply_central_impulse(force)

# Helper function to spawn floating objects
func spawn_floating_object(model: PackedScene, position: Vector3):
	var instance = model.instantiate()
	add_child(instance)
	instance.global_position = position
	instance.global_position.y = get_water_height_at_position(position)
	
	if instance is RigidBody3D:
		instance.set_collision_layer_value(1, true)
		instance.add_to_group("physics_bodies")
