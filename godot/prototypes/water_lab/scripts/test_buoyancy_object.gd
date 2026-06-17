extends RigidBody3D

@export var object_mass := 100.0  # kg
@export var object_size := Vector3(2.0, 1.0, 2.0)  # meters
@export var buoyancy_multiplier := 1.0

var water_manager: Node3D
var start_position: Vector3

func _ready():
	# Set up the rigid body
	mass = object_mass
	
	# Create a visible mesh so we can see the object
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = object_size
	mesh_instance.mesh = box_mesh
	
	# Add a material to make it visible
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.4, 0.2, 1.0)  # Orange-brown
	material.roughness = 0.5
	mesh_instance.material_override = material
	add_child(mesh_instance)
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = object_size
	collision_shape.shape = box_shape
	add_child(collision_shape)
	
	# Calculate and store volume
	var volume = object_size.x * object_size.y * object_size.z
	set_meta("volume", volume)
	
	# Calculate density (for debugging)
	var density = mass / volume
	print("Test Object Created:")
	print("  Size: ", object_size)
	print("  Volume: %.2f m³" % volume)
	print("  Mass: %.1f kg" % mass)
	print("  Density: %.1f kg/m³ (Water is 1000 kg/m³)" % density)
	if density < 1000:
		print("  Object should FLOAT (density < water)")
	elif density > 1000:
		print("  Object should SINK (density > water)")
	else:
		print("  Object should be NEUTRALLY BUOYANT")
	
	# Store start position
	start_position = global_position
	
	# Connect to water manager
	water_manager = get_tree().get_first_node_in_group("water_manager")
	if water_manager and water_manager.has_method("register_buoyant_object"):
		water_manager.register_buoyant_object(self)
		print("  Connected to water manager")
	else:
		print("  ERROR: No water manager found!")

func _exit_tree():
	if water_manager and water_manager.has_method("unregister_buoyant_object"):
		water_manager.unregister_buoyant_object(self)

func _physics_process(delta):
	# Debug visualization
	if Input.is_key_pressed(KEY_R):
		# Reset position
		global_position = start_position
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	
	# Print debug info occasionally
	if Engine.get_physics_frames() % 60 == 0:
		var water_height = 0.0
		if water_manager and water_manager.has_method("get_height_at_position"):
			water_height = water_manager.get_height_at_position(global_position)
		
		var depth = water_height - global_position.y
		var submerged = depth > 0
		
		print("Object State: Pos=%.1f, Water=%.1f, Depth=%.2f, Submerged=%s, Vel=%.2f" % [
			global_position.y, water_height, depth, submerged, linear_velocity.length()
		])

func _input(event):
	if event.is_action_pressed("ui_up"):
		# Apply upward force to test buoyancy
		apply_central_impulse(Vector3.UP * 5.0)
		print("Applied upward impulse")
	
	if event.is_action_pressed("ui_down"):
		# Push down to submerge
		apply_central_impulse(Vector3.DOWN * 10.0)
		print("Applied downward impulse")
