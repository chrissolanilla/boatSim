extends Node3D
class_name AdvancedWaterPhysics

@export var resolution: int = 256
@export var water_size: float = 100.0
@export var wind_speed: float = 10.0
@export var wave_amplitude: float = 0.3
@export var wave_length: float = 2.0
@export var viscosity: float = 0.98
@export var gravity: float = 9.8

var time: float = 0.0
var water_mesh: MeshInstance3D
var water_material: ShaderMaterial

func _ready():
	await get_tree().process_frame
	_setup_water()

func _setup_water():
	# Find or create water mesh
	water_mesh = get_node_or_null("../WaterPlane")
	if not water_mesh:
		print("Creating water mesh...")
		water_mesh = MeshInstance3D.new()
		water_mesh.name = "WaterPlane"
		var plane_mesh = PlaneMesh.new()
		plane_mesh.size = Vector2(water_size, water_size)
		plane_mesh.subdivide_width = 128
		plane_mesh.subdivide_depth = 128
		water_mesh.mesh = plane_mesh
		add_child(water_mesh)
		water_mesh.owner = get_tree().edited_scene_root if get_tree().edited_scene_root else self

	# Create material
	var shader = preload("res://shaders/water_visual.gdshader")
	if shader:
		water_material = ShaderMaterial.new()
		water_material.shader = shader
		water_material.set_shader_parameter("water_color_deep", Color(0.02, 0.15, 0.3))
		water_material.set_shader_parameter("water_color_shallow", Color(0.1, 0.5, 0.7))
		water_material.set_shader_parameter("wave_strength", wave_amplitude)
		water_material.set_shader_parameter("time", time)
		water_material.set_shader_parameter("foam_intensity", 0.5)
		water_material.set_shader_parameter("transparency", 0.85)
		water_material.set_shader_parameter("fresnel_strength", 5.0)
		water_material.set_shader_parameter("reflection_intensity", 0.7)

		# Create placeholder texture for heightmap (will be updated by compute shader later)
		var placeholder_texture = create_placeholder_texture()
		water_material.set_shader_parameter("heightmap_texture", placeholder_texture)
		water_material.set_shader_parameter("foam_texture", placeholder_texture)

		water_mesh.material_override = water_material
		print("Water material created successfully")
	else:
		print("ERROR: Could not load water_visual.gdshader")

func create_placeholder_texture():
	var image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	# Create a simple wave pattern
	for x in range(512):
		for y in range(512):
			var height = sin(x * 0.05) * cos(y * 0.05) * 0.5 + 0.5
			var color_value = int(height * 255)
			image.set_pixel(x, y, Color(color_value/255.0, color_value/255.0, color_value/255.0, 1.0))

	return ImageTexture.create_from_image(image)

func _process(delta):
	time += delta * 0.5
	if water_material:
		water_material.set_shader_parameter("time", time)

func get_height_at_position(x: float, z: float) -> float:
	# Simplified height calculation for buoyancy
	return sin(x * 0.5) * cos(z * 0.5) * 0.2
