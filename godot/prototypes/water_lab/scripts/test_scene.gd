extends Node3D

@export var spawn_test_objects := true
@export var number_of_objects := 5
@export var spawn_area := 10.0

var water_manager: Node3D
var test_objects: Array = []

func _ready():
	water_manager = get_tree().get_first_node_in_group("water_manager")
	
	if spawn_test_objects:
		_spawn_test_objects()
	
	# Create UI for controls
	_create_test_ui()

func _spawn_test_objects():
	# Load the test object scene
	var test_object_scene = load("res://scenes/test_buoyancy_object.tscn")
	if not test_object_scene:
		# Create objects programmatically if scene doesn't exist
		_create_test_objects_programmatically()
		return
	
	for i in range(number_of_objects):
		var obj = test_object_scene.instantiate()
		
		# Position objects at different heights
		var x = randf_range(-spawn_area, spawn_area)
		var z = randf_range(-spawn_area, spawn_area)
		var y = water_manager.base_height + randf_range(-2.0, 3.0)  # Some above, some below water
		
		obj.global_position = Vector3(x, y, z)
		
		# Give each object slightly different properties
		if obj is RigidBody3D:
			obj.mass = randf_range(50.0, 500.0)
		
		add_child(obj)
		test_objects.append(obj)
		
		print("Spawned test object at: ", obj.global_position)

func _create_test_objects_programmatically():
	for i in range(number_of_objects):
		var obj = RigidBody3D.new()
		obj.name = "TestObject_%d" % i
		
		# Add mesh
		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		var size = Vector3(
			randf_range(0.5, 3.0),
			randf_range(0.3, 1.5),
			randf_range(0.5, 3.0)
		)
		box.size = size
		mesh.mesh = box
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(randf(), randf(), randf())
		mesh.material_override = mat
		obj.add_child(mesh)
		
		# Add collision
		var collision = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		collision.shape = box_shape
		obj.add_child(collision)
		
		# Set properties
		obj.mass = randf_range(50.0, 500.0)
		obj.set_meta("volume", size.x * size.y * size.z)
		
		# Position
		var x = randf_range(-spawn_area, spawn_area)
		var z = randf_range(-spawn_area, spawn_area)
		var y = water_manager.base_height + randf_range(-2.0, 5.0)
		obj.global_position = Vector3(x, y, z)
		
		# Add buoyancy script
		var script = GDScript.new()
		script.source_code = _get_buoyancy_script_code()
		script.reload()
		obj.set_script(script)
		
		add_child(obj)
		test_objects.append(obj)

func _get_buoyancy_script_code() -> String:
	return """extends RigidBody3D

var water_manager: Node3D

func _ready():
	water_manager = get_tree().get_first_node_in_group("water_manager")
	if water_manager and water_manager.has_method("register_buoyant_object"):
		water_manager.register_buoyant_object(self)

func _exit_tree():
	if water_manager and water_manager.has_method("unregister_buoyant_object"):
		water_manager.unregister_buoyant_object(self)
"""

func _create_test_ui():
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	var control = Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(control)
	
	var label = Label.new()
	label.text = "Buoyancy Test Scene\nControls:\nArrow Up: Push object up\nArrow Down: Push object down\nR: Reset object position\nSpace: Toggle pause"
	label.position = Vector2(10, 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 16)
	control.add_child(label)

func _physics_process(delta):
	# Update water manager connection for all objects
	for obj in test_objects:
		if not is_instance_valid(obj):
			continue
		
		# Ensure objects stay connected
		if not obj.water_manager:
			obj.water_manager = water_manager
			if water_manager and water_manager.has_method("register_buoyant_object"):
				water_manager.register_buoyant_object(obj)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Toggle physics pause
		get_tree().paused = not get_tree().paused
		print("Physics paused: ", get_tree().paused)
