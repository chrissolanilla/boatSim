extends Node3D

@export var water_manager: Node3D
@export var show_grid := true
@export var show_velocity := true
@export var show_height_colors := true
@export var grid_spacing := 5
@export var velocity_spacing := 10

var debug_mesh: ImmediateMesh
var mesh_instance: MeshInstance3D

func _ready():
	debug_mesh = ImmediateMesh.new()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = debug_mesh
	add_child(mesh_instance)

func _process(delta):
	if not water_manager:
		return
	
	debug_mesh.clear_surfaces()
	
	if show_grid:
		_draw_grid()
	if show_velocity:
		_draw_velocity_vectors()

func _draw_grid():
	if not water_manager.has_method("get_height_at_position"):
		return
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN
	material.flags_unshaded = true
	mesh_instance.material_override = material
	
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for x in range(0, int(water_manager.grid_size.x), grid_spacing):
		for z in range(0, int(water_manager.grid_size.y), grid_spacing):
			var pos = Vector3(
				x * water_manager.cell_size,
				water_manager.height_map[x][z],
				z * water_manager.cell_size
			)
			debug_mesh.surface_add_vertex(pos)
			debug_mesh.surface_add_vertex(pos + Vector3.UP * 0.5)
	
	debug_mesh.surface_end()

func _draw_velocity_vectors():
	if not water_manager.has_method("get_water_velocity_at"):
		return
	
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	
	for x in range(0, int(water_manager.grid_size.x), velocity_spacing):
		for z in range(0, int(water_manager.grid_size.y), velocity_spacing):
			var pos = Vector3(
				x * water_manager.cell_size,
				water_manager.height_map[x][z],
				z * water_manager.cell_size
			)
			var vel = water_manager.get_water_velocity_at(pos)
			debug_mesh.surface_add_vertex(pos)
			debug_mesh.surface_add_vertex(pos + vel * 0.1)
	
	debug_mesh.surface_end()
