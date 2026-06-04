extends Node3D

@export var spawn_on_start: bool = true
@export var object_count: int = 5
@export var spawn_area: float = 8.0

# NEW: Size controls
@export var cube_size: float = 1.2
@export var sphere_radius: float = 0.6
@export var boat_length: float = 2.5
@export var boat_width: float = 1.5
@export var boat_height: float = 0.4

enum ObjectType { CUBE, SPHERE, BOAT }
@export var object_type: ObjectType = ObjectType.CUBE

func _ready():
	if spawn_on_start:
		spawn_test_objects()

func spawn_test_objects():
	for i in range(object_count):
		var test_object: RigidBody3D = null
		
		match object_type:
			ObjectType.CUBE:
				test_object = create_cube()
			ObjectType.SPHERE:
				test_object = create_sphere()
			ObjectType.BOAT:
				test_object = create_boat()
		
		if test_object:
			var random_pos = Vector3(
				randf_range(-spawn_area, spawn_area),
				randf_range(2, 5),
				randf_range(-spawn_area, spawn_area)
			)
			test_object.position = random_pos
			add_child(test_object)

func create_cube() -> RigidBody3D:
	var cube = RigidBody3D.new()
	cube.name = "TestCube_" + str(randi())
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(cube_size, cube_size, cube_size)
	mesh_instance.mesh = box_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(randf(), randf(), randf(), 1.0)
	mesh_instance.material_override = material
	
	cube.add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(cube_size, cube_size, cube_size)
	collision.shape = box_shape
	cube.add_child(collision)
	
	cube.mass = cube_size * 2.0  # Scale mass with size
	
	return cube

func create_sphere() -> RigidBody3D:
	var sphere = RigidBody3D.new()
	sphere.name = "TestSphere_" + str(randi())
	
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = sphere_radius
	sphere_mesh.height = sphere_radius * 2
	mesh_instance.mesh = sphere_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(randf(), randf(), randf(), 1.0)
	material.metallic = 0.5
	mesh_instance.material_override = material
	
	sphere.add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = sphere_radius
	collision.shape = sphere_shape
	sphere.add_child(collision)
	
	sphere.mass = sphere_radius * 3.0
	
	return sphere

func create_boat() -> RigidBody3D:
	var boat = RigidBody3D.new()
	boat.name = "TestBoat_" + str(randi())
	
	var hull = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(boat_length, boat_height, boat_width)
	hull.mesh = box_mesh
	
	var hull_material = StandardMaterial3D.new()
	hull_material.albedo_color = Color(0.5, 0.35, 0.2, 1.0)
	hull.material_override = hull_material
	
	boat.add_child(hull)
	
	var deck = MeshInstance3D.new()
	var deck_mesh = BoxMesh.new()
	deck_mesh.size = Vector3(boat_length * 0.9, boat_height * 0.3, boat_width * 0.9)
	deck.mesh = deck_mesh
	
	var deck_material = StandardMaterial3D.new()
	deck_material.albedo_color = Color(0.6, 0.5, 0.3, 1.0)
	deck.material_override = deck_material
	deck.position.y = boat_height / 2 + 0.05
	
	boat.add_child(deck)
	
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(boat_length, boat_height, boat_width)
	collision.shape = box_shape
	boat.add_child(collision)
	
	boat.mass = boat_length * boat_width * 2.0
	
	return boat
