extends Node3D
class_name WaterManager

@export var grid_width: int = 64
@export var grid_depth: int = 64
@export var water_size: Vector2 = Vector2(5000.0, 5000.0)
@export_range(0.0, 15.0) var wave_height: float = 1.0:
	set(value):
		wave_height = value
		waves_dirty = true
@export_range(1.0, 200.0) var wave_length: float = 20.0:
	set(value):
		wave_length = value
		waves_dirty = true
@export_range(0.0, 360.0) var wave_direction: float = 0.0:
	set(value):
		wave_direction = value
		waves_dirty = true
@export_range(0.0, 40.0) var wave_speed: float = 8.0:
	set(value):
		wave_speed = value
		waves_dirty = true
@export_range(0.0, 1.5) var wave_disparity: float = 0.45:
	set(value):
		wave_disparity = value
		waves_dirty = true
@export_range(0.1, 3.0) var wave_swell: float = 1.0:
	set(value):
		wave_swell = value
		waves_dirty = true
@export var wave_seed: int = 1:
	set(value):
		wave_seed = value
		waves_dirty = true
@export var visualize_surface: bool = true
@export var normal_sample_distance: float = 1.0
@export var interaction_grid_path: NodePath

var gravity: float = 9.81
var elapsed_time: float = 0.0
var waves_dirty: bool = true
var mesh_instance: MeshInstance3D
var array_mesh: ArrayMesh
var original_vertices: Array[Vector3] = []
var vertex_count: int = 0
var interaction_grid: WaterInteractionGrid

class GerstnerWave:
	var direction: Vector2
	var amplitude: float
	var wavelength: float
	var speed: float
	var steepness: float
	var phase: float

	func _init(dir: Vector2, amp: float, wave_len: float, spd: float, steep: float, phase_offset: float) -> void:
		direction = dir.normalized()
		amplitude = amp
		wavelength = max(wave_len, 0.01)
		speed = spd
		steepness = steep
		phase = phase_offset

	func get_displacement(local_position: Vector3, time: float) -> Vector3:
		var k := 2.0 * PI / wavelength
		var frequency := k * speed
		var dir_vec := Vector3(direction.x, 0.0, direction.y)
		var theta := k * dir_vec.dot(local_position) + frequency * time + phase
		var horizontal := steepness * amplitude * cos(theta)
		return Vector3(horizontal * direction.x, amplitude * sin(theta), horizontal * direction.y)

var waves: Array[GerstnerWave] = []


func _ready() -> void:
	_setup_interaction_grid()
	_rebuild_waves()
	if visualize_surface:
		_create_water_mesh()
		_setup_water_material()


func _process(delta: float) -> void:
	elapsed_time += delta

	if waves_dirty:
		_rebuild_waves()

	if visualize_surface:
		_update_vertex_displacements()


func get_water_height_at_position(world_position: Vector3) -> float:
	return global_position.y + get_water_displacement_at_position(world_position).y


func get_water_normal_at_position(world_position: Vector3) -> Vector3:
	var sample := max(normal_sample_distance, 0.01)
	var center_height := get_water_height_at_position(world_position)
	var x_height := get_water_height_at_position(world_position + Vector3(sample, 0.0, 0.0))
	var z_height := get_water_height_at_position(world_position + Vector3(0.0, 0.0, sample))
	var tangent_x := Vector3(sample, x_height - center_height, 0.0)
	var tangent_z := Vector3(0.0, z_height - center_height, sample)
	return tangent_z.cross(tangent_x).normalized()


func get_water_displacement_at_position(world_position: Vector3) -> Vector3:
	var base_displacement := _get_base_displacement_at_position(world_position)
	var interaction_state := _get_interaction_state(world_position)
	return base_displacement + interaction_state["displacement"] + Vector3(0.0, interaction_state["height_offset"], 0.0)


func get_water_state_at_position(world_position: Vector3) -> Dictionary:
	var base_displacement := _get_base_displacement_at_position(world_position)
	var interaction_state := _get_interaction_state(world_position)
	var displacement := base_displacement + interaction_state["displacement"] + Vector3(0.0, interaction_state["height_offset"], 0.0)

	return {
		"world_position": world_position,
		"surface_height": global_position.y + displacement.y,
		"base_height": global_position.y + base_displacement.y,
		"interaction_height": interaction_state["height_offset"],
		"displacement": displacement,
		"normal": get_water_normal_at_position(world_position),
		"current_velocity": interaction_state["current_velocity"],
		"turbulence": interaction_state["turbulence"],
		"wake_strength": interaction_state["wake_strength"],
		"dirty_water": interaction_state["dirty_water"],
		"prop_wash": interaction_state["prop_wash"],
		"slip_multiplier": interaction_state["slip_multiplier"],
	}


func _setup_interaction_grid() -> void:
	if interaction_grid_path != NodePath():
		interaction_grid = get_node_or_null(interaction_grid_path) as WaterInteractionGrid

	if not interaction_grid:
		interaction_grid = get_node_or_null("InteractionGrid") as WaterInteractionGrid

	if not interaction_grid:
		interaction_grid = WaterInteractionGrid.new()
		interaction_grid.name = "InteractionGrid"
		add_child(interaction_grid)


func _rebuild_waves() -> void:
	waves_dirty = false
	waves.clear()

	var direction_radians := deg_to_rad(wave_direction)
	var main_direction := Vector2(cos(direction_radians), sin(direction_radians))
	var theoretical_speed := sqrt(gravity * wave_length / (2.0 * PI))
	var actual_speed := wave_speed if wave_speed > 0.0 else theoretical_speed
	var amplitude := wave_height * 0.5
	var steepness := min(amplitude / max(wave_length, 0.01), 0.25) * wave_swell
	var rng := RandomNumberGenerator.new()
	if wave_seed == 0:
		rng.randomize()
	else:
		rng.seed = wave_seed

	waves.append(GerstnerWave.new(main_direction, amplitude, wave_length, actual_speed, steepness, 0.0))

	var secondary_wave_count := int(3 + wave_disparity * 8.0)
	for i in range(secondary_wave_count):
		var angle_offset := deg_to_rad(rng.randf_range(-45.0, 45.0) * wave_disparity)
		var direction := main_direction.rotated(angle_offset)
		var secondary_amplitude := amplitude * rng.randf_range(0.1, 0.4) * wave_disparity
		var secondary_length := wave_length * rng.randf_range(0.3, 0.8)
		var secondary_speed := actual_speed * rng.randf_range(0.6, 1.2)
		var secondary_steepness := steepness * rng.randf_range(0.2, 0.6)
		var phase := rng.randf_range(0.0, PI * 2.0)
		waves.append(GerstnerWave.new(direction, secondary_amplitude, secondary_length, secondary_speed, secondary_steepness, phase))


func _get_base_displacement_at_position(world_position: Vector3) -> Vector3:
	var local_position := to_local(world_position)
	var displacement := Vector3.ZERO
	for wave in waves:
		displacement += wave.get_displacement(local_position, elapsed_time)
	return displacement


func _get_interaction_state(world_position: Vector3) -> Dictionary:
	if interaction_grid:
		return interaction_grid.get_interaction_state(world_position)

	return {
		"height_offset": 0.0,
		"displacement": Vector3.ZERO,
		"current_velocity": Vector3.ZERO,
		"turbulence": 0.0,
		"wake_strength": 0.0,
		"dirty_water": 0.0,
		"prop_wash": 0.0,
		"slip_multiplier": 1.0,
	}


func _create_water_mesh() -> void:
	array_mesh = ArrayMesh.new()
	original_vertices.clear()

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()

	for z in range(grid_depth):
		for x in range(grid_width):
			var u := float(x) / float(max(grid_width - 1, 1))
			var v := float(z) / float(max(grid_depth - 1, 1))
			var x_position := (u - 0.5) * water_size.x
			var z_position := (v - 0.5) * water_size.y
			var vertex := Vector3(x_position, 0.0, z_position)
			vertices.append(vertex)
			normals.append(Vector3.UP)
			uvs.append(Vector2(u, v))
			original_vertices.append(vertex)

	for z in range(grid_depth - 1):
		for x in range(grid_width - 1):
			var index := z * grid_width + x
			indices.append(index)
			indices.append(index + grid_width)
			indices.append(index + 1)
			indices.append(index + 1)
			indices.append(index + grid_width)
			indices.append(index + grid_width + 1)

	vertex_count = vertices.size()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)

	mesh_instance.mesh = array_mesh


func _setup_water_material() -> void:
	if not mesh_instance:
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.58, 0.85, 0.92)
	material.metallic = 0.1
	material.roughness = 0.08
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = material


func _update_vertex_displacements() -> void:
	if not array_mesh or original_vertices.is_empty():
		return

	var surface_arrays := array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]

	for i in range(vertex_count):
		var local_origin := original_vertices[i]
		var world_origin := to_global(local_origin)
		vertices[i] = local_origin + get_water_displacement_at_position(world_origin)

	var updated_arrays := []
	updated_arrays.resize(Mesh.ARRAY_MAX)
	updated_arrays[Mesh.ARRAY_VERTEX] = vertices
	updated_arrays[Mesh.ARRAY_INDEX] = surface_arrays[Mesh.ARRAY_INDEX]
	updated_arrays[Mesh.ARRAY_NORMAL] = surface_arrays[Mesh.ARRAY_NORMAL]
	updated_arrays[Mesh.ARRAY_TEX_UV] = surface_arrays[Mesh.ARRAY_TEX_UV]

	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, updated_arrays)
