extends Node3D

# Grid configuration
@export var grid_width: int = 50
@export var grid_depth: int = 50
@export var water_size: Vector2 = Vector2(100.0, 100.0)

# Wave parameters with real-world units
@export_range(0.0, 15.0) var wave_height: float = 1.0:
	set(value):
		wave_height = value
		update_wave_parameters()
@export_range(1.0, 100.0) var wave_length: float = 10.0:
	set(value):
		wave_length = value
		update_wave_parameters()
@export_range(0.0, 360.0) var wave_direction: float = 0.0:
	set(value):
		wave_direction = value
		update_wave_parameters()
@export_range(0.0, 30.0) var wave_speed: float = 8.0:
	set(value):
		wave_speed = value
		update_wave_parameters()
@export_range(0.0, 1.0) var wave_disparity: float = 0.5:
	set(value):
		wave_disparity = value
		update_wave_parameters()
@export_range(0.0, 2.0) var wave_swell: float = 1.0:
	set(value):
		wave_swell = value
		update_wave_parameters()
@export_range(0.0, 50.0) var wind_speed: float = 0.0

# Fixed physics constants
var water_density: float = 1025.0
var gravity: float = 9.81

# Physics parameters
@export var buoyancy_strength: float = 15.0
@export var water_drag: float = 3.0
@export var splash_force: float = 5.0

# Runtime variables
var mesh_instance: MeshInstance3D
var array_mesh: ArrayMesh
var bodies_in_water: Dictionary = {}
var elapsed_time: float = 0.0
var original_vertices: Array[Vector3] = []
var vertex_count: int = 0
var control_panel: Control
var menu_visible: bool = true

# Wave system
class GerstnerWave:
	var direction: Vector2
	var amplitude: float
	var wavelength: float
	var speed: float
	var steepness: float
	var phase: float

	func _init(dir: Vector2, amp: float, wave_len: float, spd: float, steep: float = 0.3, phase_offset: float = 0.0):
		direction = dir.normalized()
		amplitude = amp
		wavelength = wave_len
		speed = spd
		steepness = steep
		phase = phase_offset

	func get_displacement(pos: Vector3, time: float) -> Vector3:
		var k = 2.0 * PI / wavelength
		var freq = k * speed
		var dir_vec = Vector3(direction.x, 0, direction.y)
		var theta = k * dir_vec.dot(pos) + freq * time + phase

		var dx = steepness * amplitude * direction.x * cos(theta)
		var dz = steepness * amplitude * direction.y * cos(theta)
		var dy = amplitude * sin(theta)

		return Vector3(dx, dy, dz)

var waves: Array[GerstnerWave] = []

func _ready():
	update_wave_parameters()
	create_water_mesh()
	setup_water_material()
	setup_physics_area()
	create_advanced_control_panel()
	position.y = 0
	print("Water system ready! Wave height: ", wave_height, "m")

func update_wave_parameters():
	# Convert degrees to radians for direction
	var dir_rad = deg_to_rad(wave_direction)
	var main_direction = Vector2(cos(dir_rad), sin(dir_rad))

	# Calculate wave speed
	var theoretical_speed = sqrt(gravity * wave_length / (2 * PI))
	var actual_speed = wave_speed if wave_speed > 0 else theoretical_speed

	# Calculate amplitude from wave height (H = 2A)
	var amplitude = wave_height / 2.0
	var steepness = min(amplitude / wave_length, 0.25) * wave_swell

	# Clear and rebuild waves
	waves.clear()

	# Primary wave
	waves.append(GerstnerWave.new(main_direction, amplitude, wave_length, actual_speed, steepness, 0.0))

	# Secondary waves based on disparity
	var num_waves = int(3 + wave_disparity * 8)
	for i in range(num_waves):
		var angle_offset = randf_range(-45, 45) * wave_disparity
		var dir = main_direction.rotated(deg_to_rad(angle_offset))
		var amp = amplitude * randf_range(0.1, 0.4) * wave_disparity
		var len = wave_length * randf_range(0.3, 0.8)
		var spd = actual_speed * randf_range(0.6, 1.2)
		var steep = steepness * randf_range(0.2, 0.6)
		var phase = randf_range(0, PI * 2)
		waves.append(GerstnerWave.new(dir, amp, len, spd, steep, phase))

	print("Updated waves: ", waves.size(), " components | Height: ", wave_height, "m")

func get_wave_force_direction() -> Vector2:
	var dir_rad = deg_to_rad(wave_direction)
	return Vector2(cos(dir_rad), sin(dir_rad))

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
	material.albedo_color = Color(0.2, 0.6, 0.9, 0.9)
	material.metallic = 0.95
	material.roughness = 0.12
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material

func setup_physics_area():
	var area = Area3D.new()
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(water_size.x, 15.0, water_size.y)
	collision_shape.shape = box_shape
	area.add_child(collision_shape)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body: Node):
	if not bodies_in_water.has(body):
		var body_height = 1.0

		if body is RigidBody3D:
			for child in body.get_children():
				if child is CollisionShape3D and child.shape:
					if child.shape is BoxShape3D:
						body_height = child.shape.size.y
					elif child.shape is CylinderShape3D:
						body_height = child.shape.height
					elif child.shape is SphereShape3D:
						body_height = child.shape.radius * 2
					break
			body_height *= body.scale.y
		elif body is CharacterBody3D:
			body_height = 1.8

		bodies_in_water[body] = {
			"submerged_ratio": 0.0,
			"splash_timer": 0.0,
			"height": body_height
		}

		print("Object entered water: ", body.name)

func _on_body_exited(body: Node):
	if bodies_in_water.has(body):
		bodies_in_water.erase(body)
		print("Object exited water: ", body.name)

func get_water_height_at_position(world_position: Vector3) -> float:
	var local_pos = to_local(world_position)
	var height = 0.0

	for wave in waves:
		var k = 2.0 * PI / wave.wavelength
		var freq = k * wave.speed
		var dir_vec = Vector3(wave.direction.x, 0, wave.direction.y)
		var theta = k * dir_vec.dot(local_pos) + freq * elapsed_time + wave.phase
		height += wave.amplitude * sin(theta)

	return global_position.y + height

func apply_buoyancy_to_rigid_body(body: RigidBody3D, delta: float):
	if not bodies_in_water.has(body):
		return

	var water_height = get_water_height_at_position(body.global_position)
	var body_height = bodies_in_water[body]["height"]
	var body_bottom = body.global_position.y - (body_height * 0.5)
	var submerged_ratio = clamp((water_height - body_bottom) / body_height, 0.0, 1.0)

	if submerged_ratio > 0.01:
		# Buoyancy
		var buoyancy = Vector3.UP * buoyancy_strength * submerged_ratio * gravity
		body.apply_central_force(buoyancy)

		# Drag
		var drag = -body.linear_velocity * water_drag * submerged_ratio
		body.apply_central_force(drag * delta)

func apply_buoyancy_to_character_body(body: CharacterBody3D, delta: float):
	if not bodies_in_water.has(body):
		return

	var water_height = get_water_height_at_position(body.global_position)
	var body_height = bodies_in_water[body]["height"]
	var body_bottom = body.global_position.y - (body_height * 0.5)
	var submerged_ratio = clamp((water_height - body_bottom) / body_height, 0.0, 1.0)

	if submerged_ratio > 0.01:
		var buoyancy = buoyancy_strength * submerged_ratio * gravity * delta
		body.velocity.y += buoyancy

		var drag = -body.velocity * water_drag * submerged_ratio * delta
		body.velocity += drag

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
			total_displacement += displacement

		vertices[i] = original_pos + total_displacement

	var new_arrays = []
	new_arrays.resize(Mesh.ARRAY_MAX)
	new_arrays[Mesh.ARRAY_VERTEX] = vertices
	new_arrays[Mesh.ARRAY_INDEX] = mesh_surface[Mesh.ARRAY_INDEX]
	new_arrays[Mesh.ARRAY_NORMAL] = mesh_surface[Mesh.ARRAY_NORMAL]
	new_arrays[Mesh.ARRAY_TEX_UV] = mesh_surface[Mesh.ARRAY_TEX_UV]

	array_mesh.surface_remove(0)
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)

func _process(delta):
	elapsed_time += delta
	update_vertex_displacements()

	for body in bodies_in_water.keys():
		if not is_instance_valid(body):
			continue

		if body is RigidBody3D:
			apply_buoyancy_to_rigid_body(body, delta)
		elif body is CharacterBody3D:
			apply_buoyancy_to_character_body(body, delta)

# UI Functions - FIXED VERSION
# UI Functions - GODOT 4 COMPATIBLE
func create_advanced_control_panel():
	control_panel = Control.new()
	control_panel.position = Vector2(10, 10)
	control_panel.size = Vector2(380, 550)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	control_panel.add_theme_stylebox_override("panel", style)

	# ScrollContainer - simplified for Godot 4
	var scroll = ScrollContainer.new()
	scroll.size = Vector2(380, 550)
	control_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size = Vector2(360, 600)
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var title = Label.new()
	title.text = "🌊 OCEAN CONTROLS"
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Wave Parameters Section
	var wave_label = Label.new()
	wave_label.text = "WAVE PARAMETERS"
	wave_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(wave_label)

	# Height slider
	add_working_slider(vbox, "Wave Height", wave_height, 0.0, 20.0, 0.1, "height", "m")

	# Length slider
	add_working_slider(vbox, "Wave Length", wave_length, 5.0, 150.0, 1.0, "length", "m")

	# Direction slider
	add_direction_slider(vbox, "Direction", wave_direction, 0.0, 360.0, 1.0, "direction", "°")

	# Speed slider
	add_working_slider(vbox, "Wave Speed", wave_speed, 0.0, 30.0, 0.5, "speed", "m/s")

	# Disparity slider
	add_working_slider(vbox, "Disparity", wave_disparity, 0.0, 1.5, 0.05, "disparity", "")

	# Swell slider
	add_working_slider(vbox, "Swell", wave_swell, 0.5, 3.0, 0.05, "swell", "")

	vbox.add_child(HSeparator.new())

	# Physics Section
	var phys_label = Label.new()
	phys_label.text = "PHYSICS SETTINGS"
	phys_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(phys_label)

	add_working_slider(vbox, "Buoyancy", buoyancy_strength, 0.0, 50.0, 0.5, "buoyancy", "")
	add_working_slider(vbox, "Water Drag", water_drag, 0.0, 20.0, 0.1, "drag", "")

	vbox.add_child(HSeparator.new())

	# Preset Buttons
	var preset_label = Label.new()
	preset_label.text = "QUICK PRESETS"
	preset_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(preset_label)

	var preset_grid = GridContainer.new()
	preset_grid.columns = 2
	preset_grid.add_theme_constant_override("h_separation", 10)

	var calm_btn = Button.new()
	calm_btn.text = "🌊 CALM\n0.8m waves"
	calm_btn.custom_minimum_size = Vector2(160, 45)
	calm_btn.pressed.connect(_on_calm_preset)
	preset_grid.add_child(calm_btn)

	var normal_btn = Button.new()
	normal_btn.text = "🌊 NORMAL\n3m waves"
	normal_btn.custom_minimum_size = Vector2(160, 45)
	normal_btn.pressed.connect(_on_normal_preset)
	preset_grid.add_child(normal_btn)

	var storm_btn = Button.new()
	storm_btn.text = "🌊 STORM\n10m waves"
	storm_btn.custom_minimum_size = Vector2(160, 45)
	storm_btn.pressed.connect(_on_storm_preset)
	preset_grid.add_child(storm_btn)

	var extreme_btn = Button.new()
	extreme_btn.text = "💀 EXTREME\n18m waves"
	extreme_btn.custom_minimum_size = Vector2(160, 45)
	extreme_btn.pressed.connect(_on_extreme_preset)
	preset_grid.add_child(extreme_btn)

	vbox.add_child(preset_grid)

	vbox.add_child(HSeparator.new())

	var hint = Label.new()
	hint.text = "💡 Press ALT+ENTER to toggle this menu"
	hint.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	hint.add_theme_font_size_override("font_size", 10)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	add_child(control_panel)

func add_working_slider(parent: VBoxContainer, label_text: String, initial_value: float, min_val: float, max_val: float, step: float, param_name: String, unit: String):
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)

	# Label row with value
	var label_row = HBoxContainer.new()
	label_row.size_flags_horizontal = Control.SIZE_EXPAND

	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_color_override("font_color", Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND
	label_row.add_child(label)

	var value_label = Label.new()
	value_label.text = str(snapped(initial_value, step)) + (" " + unit if unit != "" else "")
	value_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	label_row.add_child(value_label)

	container.add_child(label_row)

	# Slider
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = initial_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND
	slider.size = Vector2(300, 25)

	slider.value_changed.connect(func(val):
		value_label.text = str(snapped(val, step)) + (" " + unit if unit != "" else "")
		match param_name:
			"height":
				wave_height = val
				update_wave_parameters()
			"length":
				wave_length = val
				update_wave_parameters()
			"speed":
				wave_speed = val
				update_wave_parameters()
			"disparity":
				wave_disparity = val
				update_wave_parameters()
			"swell":
				wave_swell = val
				update_wave_parameters()
			"buoyancy":
				buoyancy_strength = val
			"drag":
				water_drag = val
	)

	container.add_child(slider)
	parent.add_child(container)

func add_direction_slider(parent: VBoxContainer, label_text: String, initial_value: float, min_val: float, max_val: float, step: float, param_name: String, unit: String):
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 3)

	# Label row with value
	var label_row = HBoxContainer.new()
	label_row.size_flags_horizontal = Control.SIZE_EXPAND

	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_color_override("font_color", Color.WHITE)
	label.size_flags_horizontal = Control.SIZE_EXPAND
	label_row.add_child(label)

	var value_label = Label.new()
	value_label.text = str(int(initial_value)) + unit + " (" + get_compass_direction(initial_value) + ")"
	value_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	label_row.add_child(value_label)

	container.add_child(label_row)

	# Slider
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = initial_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND
	slider.size = Vector2(300, 25)

	slider.value_changed.connect(func(val):
		value_label.text = str(int(val)) + unit + " (" + get_compass_direction(val) + ")"
		wave_direction = val
		update_wave_parameters()
	)

	container.add_child(slider)

	# Cardinal direction buttons
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 5)
	button_row.size_flags_horizontal = Control.SIZE_EXPAND

	var directions = [
		["N", 0], ["NE", 45], ["E", 90], ["SE", 135],
		["S", 180], ["SW", 225], ["W", 270], ["NW", 315]
	]

	for dir in directions:
		var btn = Button.new()
		btn.text = dir[0]
		btn.custom_minimum_size = Vector2(38, 28)
		btn.pressed.connect(func(d=dir[1]):
			wave_direction = float(d)
			slider.value = float(d)
			value_label.text = str(d) + unit + " (" + get_compass_direction(float(d)) + ")"
			update_wave_parameters()
		)
		button_row.add_child(btn)

	container.add_child(button_row)
	parent.add_child(container)

func get_compass_direction(degrees: float) -> String:
	var directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
					  "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
	var index = int((degrees + 11.25) / 22.5) % 16
	return directions[index]

func update_ui_sliders():
	if not control_panel:
		return

	var all_sliders = control_panel.find_children("*", "HSlider", true, false)
	for slider in all_sliders:
		var parent_container = slider.get_parent()
		if parent_container and parent_container.get_child_count() >= 2:
			# First child should be the HBoxContainer with labels
			if parent_container.get_child(0) is HBoxContainer:
				var label_row = parent_container.get_child(0)
				if label_row.get_child_count() >= 2:
					var value_label = label_row.get_child(1)
					var text = label_row.get_child(0).text.replace(":", "")

					match text:
						"Wave Height":
							slider.value = wave_height
							value_label.text = str(snapped(wave_height, 0.1)) + " m"
						"Wave Length":
							slider.value = wave_length
							value_label.text = str(snapped(wave_length, 1.0)) + " m"
						"Direction":
							slider.value = wave_direction
							value_label.text = str(int(wave_direction)) + "° (" + get_compass_direction(wave_direction) + ")"
						"Wave Speed":
							slider.value = wave_speed
							value_label.text = str(snapped(wave_speed, 0.5)) + " m/s"
						"Disparity":
							slider.value = wave_disparity
							value_label.text = str(snapped(wave_disparity, 0.05))
						"Swell":
							slider.value = wave_swell
							value_label.text = str(snapped(wave_swell, 0.05))
						"Buoyancy":
							slider.value = buoyancy_strength
							value_label.text = str(snapped(buoyancy_strength, 0.5))
						"Water Drag":
							slider.value = water_drag
							value_label.text = str(snapped(water_drag, 0.1))

func _on_calm_preset():
	wave_height = 0.8
	wave_length = 15.0
	wave_speed = 5.0
	wave_disparity = 0.2
	wave_swell = 0.7
	update_wave_parameters()
	update_ui_sliders()

func _on_normal_preset():
	wave_height = 3.0
	wave_length = 25.0
	wave_speed = 10.0
	wave_disparity = 0.5
	wave_swell = 1.0
	update_wave_parameters()
	update_ui_sliders()

func _on_storm_preset():
	wave_height = 10.0
	wave_length = 50.0
	wave_speed = 18.0
	wave_disparity = 1.0
	wave_swell = 1.5
	update_wave_parameters()
	update_ui_sliders()

func _on_extreme_preset():
	wave_height = 18.0
	wave_length = 80.0
	wave_speed = 25.0
	wave_disparity = 1.2
	wave_swell = 2.0
	update_wave_parameters()
	update_ui_sliders()

func _input(event: InputEvent):
	if event.is_action_pressed("conditions_menu"):
		toggle_menu()

func toggle_menu():
	menu_visible = !menu_visible
	if control_panel:
		control_panel.visible = menu_visible

		if menu_visible:
			print("📊 Conditions Menu Opened")
		else:
			print("📊 Conditions Menu Closed")
