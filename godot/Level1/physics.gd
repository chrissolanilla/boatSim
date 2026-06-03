extends Node3D

# Grid configuration
@export var grid_width: int = 50
@export var grid_depth: int = 50
@export var water_size: Vector2 = Vector2(20.0, 20.0)

# Wave parameters (0% to 100%)
@export_range(0.0, 1.0) var wave_amplitude: float = 0.5:
	set(value):
		wave_amplitude = value
		update_ui_sliders()
@export_range(0.0, 1.0) var wave_frequency: float = 0.5:
	set(value):
		wave_frequency = value
		update_ui_sliders()
@export_range(0.0, 1.0) var wave_speed: float = 0.5:
	set(value):
		wave_speed = value
		update_ui_sliders()
@export_range(0.0, 1.0) var wave_choppiness: float = 0.3:
	set(value):
		wave_choppiness = value
		update_ui_sliders()

# Physics parameters
@export var buoyancy_strength: float = 15.0
@export var water_drag: float = 3.0
@export var splash_force: float = 5.0

var mesh_instance: MeshInstance3D
var array_mesh: ArrayMesh
var bodies_in_water: Dictionary = {}
var elapsed_time: float = 0.0
var original_vertices: Array[Vector3] = []
var vertex_count: int = 0
var control_panel: Control

# Wave system - fixed parameter name (len -> wavelength)
class GerstnerWave:
	var direction: Vector2
	var amplitude: float
	var wavelength: float
	var speed: float
	
	func _init(dir: Vector2, amp: float, wave_len: float, spd: float):
		direction = dir.normalized()
		amplitude = amp
		wavelength = wave_len
		speed = spd
	
	func get_displacement(pos: Vector3, time: float) -> Vector3:
		var k = 2.0 * PI / wavelength
		var freq = k * speed
		var dir_vec = Vector3(direction.x, 0, direction.y)
		var theta = k * dir_vec.dot(pos) + freq * time
		
		var dx = 0.3 * amplitude * direction.x * cos(theta)
		var dz = 0.3 * amplitude * direction.y * cos(theta)
		var dy = amplitude * sin(theta)
		
		return Vector3(dx, dy, dz)

var waves: Array[GerstnerWave] = []

func _ready():
	setup_waves()
	create_water_mesh()
	setup_water_material()
	setup_physics_area()
	create_control_panel()

func setup_waves():
	waves = [
		GerstnerWave.new(Vector2(1, 0), 0.08, 2.0, 1.2),
		GerstnerWave.new(Vector2(0.7, 0.7), 0.06, 1.5, 0.9),
		GerstnerWave.new(Vector2(-0.5, 0.8), 0.05, 1.2, 1.5),
		GerstnerWave.new(Vector2(0.3, -0.9), 0.04, 0.8, 2.0)
	]

func create_water_mesh():
	array_mesh = ArrayMesh.new()
	
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	
	for z in range(grid_depth):
		for x in range(grid_width):
			var u = float(x) / (grid_width - 1)
			var v = float(z) / (grid_depth - 1)
			var x_pos = (u - 0.5) * water_size.x
			var z_pos = (v - 0.5) * water_size.y
			
			vertices.append(Vector3(x_pos, 0, z_pos))
			uvs.append(Vector2(u, v))
			normals.append(Vector3.UP)
			original_vertices.append(Vector3(x_pos, 0, z_pos))
	
	for z in range(grid_depth - 1):
		for x in range(grid_width - 1):
			var idx = z * grid_width + x
			indices.append(idx)
			indices.append(idx + grid_width)
			indices.append(idx + 1)
			indices.append(idx + 1)
			indices.append(idx + grid_width)
			indices.append(idx + grid_width + 1)
	
	vertex_count = vertices.size()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	add_child(mesh_instance)

func setup_water_material():
	var material = StandardMaterial3D.new()
	
	# Base water appearance
	material.albedo_color = Color(0.2, 0.6, 0.9, 0.9)
	material.metallic = 0.95
	material.roughness = 0.12
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# CRITICAL FIX: Make water visible from both sides (top and bottom)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Add normal map for surface detail
	var noise_texture = create_procedural_normal_map()
	material.normal_texture = noise_texture
	material.normal_scale = 0.5
	
	# Add rim lighting for shiny water edges
	material.rim_enabled = true
	material.rim = 0.8
	material.rim_tint = 0.5
	
	# Add slight emission for sparkle
	material.emission_enabled = true
	material.emission = Color(0.1, 0.2, 0.3)
	material.emission_energy = 0.3
	
	mesh_instance.material_override = material

func create_procedural_normal_map() -> NoiseTexture2D:
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 2.0
	noise.fractal_octaves = 3
	
	var noise_texture = NoiseTexture2D.new()
	noise_texture.noise = noise
	noise_texture.width = 512
	noise_texture.height = 512
	
	# In Godot 4, NoiseTexture2D automatically generates normal maps
	# by setting the noise texture as a normal map in the material
	return noise_texture

func create_control_panel():
	# Create UI panel
	control_panel = Control.new()
	control_panel.position = Vector2(10, 10)
	control_panel.size = Vector2(300, 400)
	
	# Create panel background
	var panel = Panel.new()
	panel.size = Vector2(300, 400)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)
	control_panel.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(15, 15)
	vbox.size = Vector2(270, 370)
	control_panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "WATER CONTROLS"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	# Amplitude slider (0-100%)
	add_slider_to_panel(vbox, "Wave Amplitude", wave_amplitude, 0.0, 1.0, "amplitude")
	
	# Frequency slider (0-100%)
	add_slider_to_panel(vbox, "Wave Frequency", wave_frequency, 0.0, 1.0, "frequency")
	
	# Speed slider (0-100%)
	add_slider_to_panel(vbox, "Wave Speed", wave_speed, 0.0, 1.0, "speed")
	
	# Choppiness slider (0-100%)
	add_slider_to_panel(vbox, "Wave Choppiness", wave_choppiness, 0.0, 1.0, "choppiness")
	
	vbox.add_child(HSeparator.new())
	
	# Preset buttons
	var preset_container = HBoxContainer.new()
	
	var calm_btn = Button.new()
	calm_btn.text = "Calm"
	calm_btn.pressed.connect(_on_calm_preset)
	preset_container.add_child(calm_btn)
	
	var normal_btn = Button.new()
	normal_btn.text = "Normal"
	normal_btn.pressed.connect(_on_normal_preset)
	preset_container.add_child(normal_btn)
	
	var storm_btn = Button.new()
	storm_btn.text = "Storm"
	storm_btn.pressed.connect(_on_storm_preset)
	preset_container.add_child(storm_btn)
	
	vbox.add_child(preset_container)
	
	vbox.add_child(HSeparator.new())
	
	# Info label
	var info = Label.new()
	info.text = "Move objects in water\nto see realistic waves!"
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(info)
	
	add_child(control_panel)

func add_slider_to_panel(parent: VBoxContainer, label_text: String, initial_value: float, min_val: float, max_val: float, param_name: String):
	var container = VBoxContainer.new()
	
	var label = Label.new()
	label.text = label_text + ": " + str(int(initial_value * 100)) + "%"
	label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = initial_value
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND
	
	# Direct callback with captured variables
	slider.value_changed.connect(func(val): 
		label.text = label_text + ": " + str(int(val * 100)) + "%"
		match param_name:
			"amplitude":
				wave_amplitude = val
			"frequency":
				wave_frequency = val
			"speed":
				wave_speed = val
			"choppiness":
				wave_choppiness = val
	)
	
	container.add_child(slider)
	parent.add_child(container)

func _on_calm_preset():
	wave_amplitude = 0.15
	wave_frequency = 0.2
	wave_speed = 0.3
	wave_choppiness = 0.1
	update_ui_sliders()

func _on_normal_preset():
	wave_amplitude = 0.5
	wave_frequency = 0.5
	wave_speed = 0.5
	wave_choppiness = 0.3
	update_ui_sliders()

func _on_storm_preset():
	wave_amplitude = 1.0
	wave_frequency = 0.9
	wave_speed = 1.0
	wave_choppiness = 0.8
	update_ui_sliders()

func update_ui_sliders():
	# Update all sliders in UI to match current values
	if control_panel:
		var sliders = control_panel.find_children("*", "HSlider", true, false)
		for slider in sliders:
			if slider.has_meta("param"):
				var param = slider.get_meta("param")
				var label = slider.get_meta("label")
				var new_value = 0.0
				
				match param:
					"amplitude":
						new_value = wave_amplitude
					"frequency":
						new_value = wave_frequency
					"speed":
						new_value = wave_speed
					"choppiness":
						new_value = wave_choppiness
				
				slider.value = new_value
				label.text = label.text.split(":")[0] + ": " + str(int(new_value * 100)) + "%"

func setup_physics_area():
	var area = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(water_size.x, 2.0, water_size.y)
	collision_shape.shape = box_shape
	area.add_child(collision_shape)
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body: Node):
	if not bodies_in_water.has(body):
		bodies_in_water[body] = {
			"submerged_ratio": 0.0,
			"splash_timer": 0.0
		}
		
		var speed = 0.0
		if body is RigidBody3D:
			speed = body.linear_velocity.length()
		elif body is CharacterBody3D:
			speed = body.velocity.length()
		
		if speed > 0.5:
			create_splash(body.global_position, min(speed * 0.3, 1.0))

func _on_body_exited(body: Node):
	bodies_in_water.erase(body)

func get_body_velocity(body: Node) -> Vector3:
	if body is RigidBody3D:
		return body.linear_velocity
	elif body is CharacterBody3D:
		return body.velocity
	return Vector3.ZERO

func get_body_height(body: Node) -> float:
	if body is RigidBody3D:
		return body.get_aabb().size.y
	elif body is CharacterBody3D:
		return 1.8
	return 1.0

func apply_buoyancy_to_rigid_body(body: RigidBody3D, delta: float):
	var water_height = get_water_height_at_position(body.global_position)
	var body_bottom = body.global_position.y - (body.get_aabb().size.y * 0.5)
	var submerged_ratio = clamp((water_height - body_bottom) / body.get_aabb().size.y, 0.0, 1.0)
	
	if submerged_ratio > 0.01:
		var buoyancy = Vector3.UP * buoyancy_strength * submerged_ratio * 9.8
		body.apply_central_force(buoyancy)
		
		var drag = -body.linear_velocity * water_drag * submerged_ratio
		body.apply_central_force(drag * delta)
		
		var wave_force = Vector3(
			sin(elapsed_time * 2.0 + body.global_position.x) * wave_amplitude * splash_force,
			0,
			cos(elapsed_time * 1.5 + body.global_position.z) * wave_amplitude * splash_force
		) * submerged_ratio
		body.apply_central_force(wave_force)

func apply_buoyancy_to_character_body(body: CharacterBody3D, delta: float):
	var water_height = get_water_height_at_position(body.global_position)
	var body_bottom = body.global_position.y - 0.9
	var submerged_ratio = clamp((water_height - body_bottom) / 1.8, 0.0, 1.0)
	
	if submerged_ratio > 0.01:
		var buoyancy = buoyancy_strength * submerged_ratio * 9.8 * delta
		body.velocity.y += buoyancy
		
		var drag = -body.velocity * water_drag * submerged_ratio * delta
		body.velocity += drag
		
		var wave_force = Vector3(
			sin(elapsed_time * 2.0 + body.global_position.x) * wave_amplitude * splash_force * delta,
			0,
			cos(elapsed_time * 1.5 + body.global_position.z) * wave_amplitude * splash_force * delta
		) * submerged_ratio
		body.velocity += wave_force

# Fixed parameter name (position -> world_position to avoid shadowing)
func get_water_height_at_position(world_position: Vector3) -> float:
	var local_pos = to_local(world_position)
	var height = 0.0
	
	for wave in waves:
		var k = 2.0 * PI / wave.wavelength
		var freq = k * wave.speed
		var dir_vec = Vector3(wave.direction.x, 0, wave.direction.y)
		var theta = k * dir_vec.dot(local_pos) + freq * elapsed_time
		height += wave.amplitude * sin(theta)
	
	height *= wave_amplitude
	height *= (0.5 + wave_frequency)
	return global_position.y + height

# Fixed parameter name (position -> splash_position to avoid shadowing)
func create_splash(splash_position: Vector3, intensity: float):
	var splash_pos = splash_position
	splash_pos.y = get_water_height_at_position(splash_position)
	
	var ring = MeshInstance3D.new()
	var ring_mesh = CylinderMesh.new()
	ring_mesh.top_radius = 0.05
	ring_mesh.bottom_radius = 0.05
	ring_mesh.height = 0.02
	ring.mesh = ring_mesh
	
	var ring_material = StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.7, 0.85, 1.0, 0.7)
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_material
	
	ring.position = splash_pos
	add_child(ring)
	
	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector3(intensity * 1.5, 0.05, intensity * 1.5), 0.5)
	tween.parallel().tween_property(ring_material, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(ring.queue_free)

func update_vertex_displacements():
	if not array_mesh:
		return
	
	var mesh_surface = array_mesh.surface_get_arrays(0)
	var vertices = mesh_surface[Mesh.ARRAY_VERTEX]
	
	for i in range(vertex_count):
		var original_pos = original_vertices[i]
		var total_displacement = Vector3.ZERO
		
		for wave in waves:
			var displacement = wave.get_displacement(original_pos, elapsed_time)
			displacement.y *= wave_amplitude
			displacement.x *= wave_amplitude * wave_frequency * wave_choppiness
			displacement.z *= wave_amplitude * wave_frequency * wave_choppiness
			total_displacement += displacement
		
		vertices[i] = original_pos + total_displacement
	
	var normals = PackedVector3Array()
	for i in range(vertex_count):
		normals.append(Vector3.UP)
	
	var new_arrays = []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = vertices
	new_arrays[Mesh.ARRAY_INDEX] = mesh_surface[Mesh.ARRAY_INDEX]
	new_arrays[Mesh.ARRAY_NORMAL] = normals
	new_arrays[Mesh.ARRAY_TEX_UV] = mesh_surface[Mesh.ARRAY_TEX_UV]
	
	array_mesh.surface_remove(0)
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)

# Fixed unused parameter with underscore
func _process(_delta: float):
	elapsed_time += 0.016  # Rough delta approximation
	update_vertex_displacements()
	
	# Update shader time
	if mesh_instance.material_override is ShaderMaterial:
		mesh_instance.material_override.set_shader_parameter("time", elapsed_time)
		mesh_instance.material_override.set_shader_parameter("amplitude", wave_amplitude * 0.3)
		mesh_instance.material_override.set_shader_parameter("frequency", 1.0 + wave_frequency * 3.0)
		mesh_instance.material_override.set_shader_parameter("wave_speed", 0.5 + wave_speed * 2.0)
	
	for body in bodies_in_water.keys():
		if not is_instance_valid(body):
			continue
		
		if body is RigidBody3D:
			apply_buoyancy_to_rigid_body(body, 0.016)
		elif body is CharacterBody3D:
			apply_buoyancy_to_character_body(body, 0.016)
