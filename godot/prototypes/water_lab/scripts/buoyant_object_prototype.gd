extends RigidBody3D

@export var custom_volume: float = 0.0  # If 0, auto-calculate from bounds
@export var buoyancy_multiplier: float = 1.0
@export var water_drag_multiplier: float = 1.0
@export var angular_drag_multiplier: float = 1.0

var water_manager: Node3D
var object_volume: float = 0.0

func _ready():
	# Calculate or use custom volume
	if custom_volume > 0:
		object_volume = custom_volume
	else:
		object_volume = _calculate_volume()
	
	set_meta("volume", object_volume)
	
	water_manager = get_tree().get_first_node_in_group("water_manager")
	if water_manager and water_manager.has_method("register_buoyant_object"):
		water_manager.register_buoyant_object(self)

func _exit_tree():
	if water_manager and water_manager.has_method("unregister_buoyant_object"):
		water_manager.unregister_buoyant_object(self)

func _calculate_volume() -> float:
	# Try collision shape first
	for child in get_children():
		if child is CollisionShape3D and child.shape:
			if child.shape is BoxShape3D:
				var size = child.shape.size * scale
				return size.x * size.y * size.z
			elif child.shape is SphereShape3D:
				var r = child.shape.radius * max(scale.x, max(scale.y, scale.z))
				return 4.0/3.0 * PI * r * r * r
			elif child.shape is CapsuleShape3D:
				var r = child.shape.radius * max(scale.x, scale.z)
				var h = child.shape.height * scale.y
				return PI * r * r * (4.0/3.0 * r + h)
	
	# Fallback to mesh
	var mesh_instance = find_child("MeshInstance3D", true, false)
	if mesh_instance and mesh_instance.mesh:
		var aabb = mesh_instance.mesh.get_aabb()
		var size = aabb.size * scale
		return size.x * size.y * size.z * 0.5  # Approximate
	
	# Default volume based on mass (assuming density similar to water)
	return mass / 1000.0
