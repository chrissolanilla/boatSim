extends Node3D

@export var water_size: float = 100.0
@export var water_height: float = 0.0
@export var wave_height: float = 0.15
@export var wave_speed: float = 1.2

var water_mesh: MeshInstance3D
var water_material: ShaderMaterial
var elapsed_time: float = 0.0

func _ready():
	print("=== Water Manager Starting ===")
	_create_water_surface()
	print("=== Water Manager Ready ===")

func _create_water_surface():
	# Create the mesh
	water_mesh = MeshInstance3D.new()
	water_mesh.name = "WaterSurface"
	
	# Create the plane
	var plane = PlaneMesh.new()
	plane.size = Vector2(water_size, water_size)
	plane.subdivide_width = 100
	plane.subdivide_depth = 100
	water_mesh.mesh = plane
	water_mesh.position.y = water_height
	
	# Load the shader
	var shader_path = "res://shaders/ocean_water.gdshader"
	
	if ResourceLoader.exists(shader_path):
		print("✓ Shader found at: ", shader_path)
		var shader = ResourceLoader.load(shader_path)
		
		if shader:
			print("✓ Shader loaded successfully")
			water_material = ShaderMaterial.new()
			water_material.shader = shader
			water_material.set_shader_parameter("wave_height", wave_height)
			water_material.set_shader_parameter("wave_speed", wave_speed)
			water_material.set_shader_parameter("deep_color", Color(0.02, 0.1, 0.25))
			water_material.set_shader_parameter("shallow_color", Color(0.1, 0.5, 0.7))
			water_mesh.material_override = water_material
			print("✓ Material created and applied")
		else:
			print("✗ Failed to load shader resource")
			_use_fallback_material()
	else:
		print("✗ Shader NOT found at: ", shader_path)
		print("  Make sure the file exists at: res://shaders/ocean_water.gdshader")
		_use_fallback_material()
	
	add_child(water_mesh)
	print("✓ Water surface added to scene")
	_add_water_collision()

func _add_water_collision():
	# Create collision shape for water so clicks register
	var collision = StaticBody3D.new()
	collision.name = "WaterCollision"
	
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(water_size, 0.5, water_size)
	collision_shape.shape = box_shape
	collision_shape.position.y = -0.25
	
	collision.add_child(collision_shape)
	water_mesh.add_child(collision)
	
	print("✓ Water collision added - clicks will now register")

func _use_fallback_material():
	print("→ Using fallback blue material")
	var fallback = StandardMaterial3D.new()
	fallback.albedo_color = Color(0.1, 0.4, 0.7)
	fallback.metallic = 0.9
	fallback.roughness = 0.15
	water_mesh.material_override = fallback

func _process(delta):
	elapsed_time += delta
	if water_material:
		water_material.set_shader_parameter("wave_time", elapsed_time)

func get_water_height(x: float, z: float) -> float:
	var t = elapsed_time * wave_speed
	var total_height = water_height
	
	# Cascade 1: Large rolling waves
	total_height += sin(x * 0.2 + t) * cos(z * 0.15 + t * 0.6) * wave_height
	total_height += sin(x * 0.5 - t * 0.8) * wave_height * 0.4
	
	# Cascade 2: Medium waves
	total_height += sin(x * 0.8 + t * 1.1) * cos(z * 0.7 + t * 0.9) * wave_height * 0.3
	total_height += cos(z * 1.0 + t * 0.7) * wave_height * 0.25
	
	# Cascade 3: Small ripples
	total_height += sin(x * 2.0 + t * 1.8) * cos(z * 1.8 + t * 1.5) * wave_height * 0.15
	total_height += sin((x * 3.0 + z * 2.5) + t * 2.2) * wave_height * 0.1
	
	return total_height

	
func _create_foam_texture():
	var foam_image = Image.create(512, 512, false, Image.FORMAT_RGBA8)
	
	# Procedural foam pattern
	for x in 512:
		for y in 512:
			var noise1 = sin(x * 0.03) * cos(y * 0.03)
			var noise2 = sin(x * 0.08 + 2.0) * sin(y * 0.08)
			var foam_value = (noise1 + noise2) * 0.5 + 0.5
			foam_value = clamp(foam_value * 0.8, 0.0, 1.0)
			var val = int(foam_value * 255)
			foam_image.set_pixel(x, y, Color(val/255.0, val/255.0, val/255.0, 1.0))
	
	var foam_texture = ImageTexture.create_from_image(foam_image)
	water_material.set_shader_parameter("foam_texture", foam_texture)

@export var wave_cascades: int = 3  # Large, medium, small waves
