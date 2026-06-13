# Add this as a new script: water_physics_grid.gd
extends Node3D
class_name WaterPhysicsGrid

## Grid-based water physics manager that only calculates physics around central objects

@export_group("Grid Configuration")
@export var grid_size := 32  # Grid resolution (32x32)
@export var cell_size := 2.0  # Meters per cell
@export var update_rate := 30.0  # Updates per second

@export_group("Object Tracking")
@export var track_objects: Array[Node3D] = []  # Objects to center grid on
@export var track_player := true
@export var track_vehicles := true

@export_group("Performance")
@export var max_objects_tracked := 5
@export var physics_lod_distance := 100.0  # Disable physics beyond this distance

# Grid data structure
var height_field: Array[Array]  # 2D array of heights
var velocity_field: Array[Array]  # 2D array of vertical velocities
var grid_center: Vector2  # Current grid center in world space
var last_update_time: float = 0.0

# Object tracking
var tracked_objects: Array[Node3D] = []
var object_positions: Dictionary  # Object -> last position
var object_velocities: Dictionary  # Object -> velocity

# Async update system
var update_queue: Array[Vector2] = []  # Grid cells needing update
var update_thread: Thread
var update_mutex: Mutex
var is_updating := false

func _ready():
	_initialize_grid()
	_setup_tracked_objects()
	
	if update_thread == null:
		update_thread = Thread.new()

func _initialize_grid():
	height_field.resize(grid_size)
	velocity_field.resize(grid_size)
	
	for x in range(grid_size):
		height_field[x] = []
		velocity_field[x] = []
		height_field[x].resize(grid_size)
		velocity_field[x].resize(grid_size)
		
		for z in range(grid_size):
			height_field[x][z] = 0.0
			velocity_field[x][z] = 0.0

func _setup_tracked_objects():
	tracked_objects.clear()
	
	if track_player:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			tracked_objects.append(player)
	
	for obj in track_objects:
		if obj and not tracked_objects.has(obj):
			tracked_objects.append(obj)
	
	# Limit tracked objects
	while tracked_objects.size() > max_objects_tracked:
		tracked_objects.remove_at(tracked_objects.size() - 1)

func _process(delta: float):
	if Time.get_ticks_msec() / 1000.0 - last_update_time < 1.0 / update_rate:
		return
	
	last_update_time = Time.get_ticks_msec() / 1000.0
	
	# Update tracked objects
	_update_tracked_objects()
	
	# Calculate grid center based on tracked objects
	var new_center = _calculate_grid_center()
	
	# Only update if center changed significantly
	if new_center.distance_to(grid_center) > cell_size * 0.5:
		grid_center = new_center
		_queue_grid_update()
	
	# Process async updates
	if not is_updating and update_queue.size() > 0:
		_process_async_updates()

func _update_tracked_objects():
	_setup_tracked_objects()  # Refresh tracked objects
	
	for obj in tracked_objects:
		if not is_instance_valid(obj):
			continue
		
		var current_pos = obj.global_position
		var last_pos = object_positions.get(obj, current_pos)
		
		# Store velocity for prediction
		var velocity = (current_pos - last_pos) / (1.0 / update_rate)
		object_velocities[obj] = velocity
		object_positions[obj] = current_pos

func _calculate_grid_center() -> Vector2:
	if tracked_objects.is_empty():
		return grid_center
	
	var center_sum := Vector2.ZERO
	var total_weight := 0.0
	
	for obj in tracked_objects:
		if is_instance_valid(obj):
			var pos = Vector2(obj.global_position.x, obj.global_position.z)
			var weight = 1.0
			
			# Give more weight to faster moving objects
			if object_velocities.has(obj):
				var speed = object_velocities[obj].length()
				weight += min(speed * 0.1, 2.0)
			
			center_sum += pos * weight
			total_weight += weight
	
	return center_sum / total_weight if total_weight > 0 else grid_center

func _queue_grid_update():
	update_queue.clear()
	
	# Calculate which grid cells need updating
	var start_x = int((grid_center.x - (grid_size * cell_size) / 2.0) / cell_size)
	var start_z = int((grid_center.y - (grid_size * cell_size) / 2.0) / cell_size)
	
	for x in range(grid_size):
		for z in range(grid_size):
			var world_x = (start_x + x) * cell_size
			var world_z = (start_z + z) * cell_size
			update_queue.append(Vector2(world_x, world_z))

func _process_async_updates():
	if update_thread.is_alive():
		return
	
	is_updating = true
	update_mutex = Mutex.new()
	
	# Calculate which objects to include for physics LOD
	var active_objects = []
	for obj in tracked_objects:
		if is_instance_valid(obj):
			var distance = Vector2(obj.global_position.x, obj.global_position.z).distance_to(grid_center)
			if distance < physics_lod_distance:
				active_objects.append(obj)
	
	update_thread.start(_async_update_grid.bind(update_queue.duplicate(), active_objects))

func _async_update_grid(queue: Array, objects: Array):
	var temp_height_field = _create_temp_grid()
	var temp_velocity_field = _create_temp_grid()
	
	# Get reference to water mesh for height queries
	var water_mesh = get_node_or_null("../WaterMesh")  # Adjust path as needed
	if not water_mesh or not water_mesh.has_method("get_height"):
		push_error("Water mesh not found or missing get_height method")
		is_updating = false
		return
	
	# Process each grid cell
	for idx in range(queue.size()):
		var world_pos = queue[idx]
		var x = idx % grid_size
		var z = idx / grid_size
		
		# Calculate world position
		var world_3d = Vector3(world_pos.x, 0, world_pos.y)
		
		# Get water height at this position
		var height = water_mesh.get_height(world_3d)
		temp_height_field[x][z] = height
		
		# Calculate velocity based on neighboring frames
		if height_field[x][z] != 0:
			temp_velocity_field[x][z] = (height - height_field[x][z]) * update_rate
		
		# Check if any tracked objects need this cell
		for obj in objects:
			if is_instance_valid(obj):
				var obj_pos = Vector2(obj.global_position.x, obj.global_position.z)
				var cell_pos = Vector2(world_pos.x, world_pos.y)
				
				if obj_pos.distance_to(cell_pos) < cell_size * 2:
					# High detail calculation for cells near objects
					var detailed_height = _calculate_detailed_height(world_3d, water_mesh)
					temp_height_field[x][z] = detailed_height
					break
	
	# Swap grids with mutex protection
	update_mutex.lock()
	height_field = temp_height_field
	velocity_field = temp_velocity_field
	update_mutex.unlock()
	
	is_updating = false

func _create_temp_grid():
	var grid = []
	grid.resize(grid_size)
	for i in range(grid_size):
		grid[i] = []
		grid[i].resize(grid_size)
		for j in range(grid_size):
			grid[i][j] = 0.0
	return grid

func _calculate_detailed_height(world_pos: Vector3, water_mesh) -> float:
	# Calculate with more samples for accuracy
	var total_height := 0.0
	var samples := 0
	
	var offsets = [
		Vector2(0, 0),
		Vector2(0.25, 0.25), Vector2(-0.25, 0.25),
		Vector2(0.25, -0.25), Vector2(-0.25, -0.25)
	]
	
	for offset in offsets:
		var sample_pos = world_pos + Vector3(offset.x, 0, offset.y)
		total_height += water_mesh.get_height(sample_pos)
		samples += 1
	
	return total_height / samples

## Public API methods

func get_height_at(world_pos: Vector3, use_detailed: bool = false) -> float:
	"""Get water height at world position from grid data"""
	if not _is_within_grid(world_pos):
		# Fall back to direct calculation
		var water_mesh = get_node_or_null("../WaterMesh")
		if water_mesh and water_mesh.has_method("get_height"):
			return water_mesh.get_height(world_pos)
		return 0.0
	
	var local_pos = _world_to_grid(Vector2(world_pos.x, world_pos.z))
	var x = int(local_pos.x)
	var z = int(local_pos.y)
	
	# Bilinear interpolation for smooth height
	var fx = local_pos.x - x
	var fz = local_pos.y - z
	
	var h00 = height_field[x][z]
	var h10 = height_field[min(x + 1, grid_size - 1)][z]
	var h01 = height_field[x][min(z + 1, grid_size - 1)]
	var h11 = height_field[min(x + 1, grid_size - 1)][min(z + 1, grid_size - 1)]
	
	var h0 = lerp(h00, h10, fx)
	var h1 = lerp(h01, h11, fx)
	
	return lerp(h0, h1, fz)

func get_velocity_at(world_pos: Vector3) -> Vector3:
	"""Get water surface velocity at world position"""
	if not _is_within_grid(world_pos):
		return Vector3.ZERO
	
	var local_pos = _world_to_grid(Vector2(world_pos.x, world_pos.z))
	var x = int(local_pos.x)
	var z = int(local_pos.y)
	
	# Get vertical velocity
	var vert_velocity = velocity_field[x][z]
	
	# Calculate horizontal velocity from height gradient
	var height = get_height_at(world_pos)
	var height_dx = get_height_at(world_pos + Vector3(cell_size, 0, 0)) - height
	var height_dz = get_height_at(world_pos + Vector3(0, 0, cell_size)) - height
	
	return Vector3(height_dx * 5.0, vert_velocity, height_dz * 5.0)

func get_slope_at(world_pos: Vector3) -> Vector3:
	"""Get water surface normal/slope"""
	var h = get_height_at(world_pos)
	var hx = get_height_at(world_pos + Vector3(cell_size * 0.5, 0, 0))
	var hz = get_height_at(world_pos + Vector3(0, 0, cell_size * 0.5))
	
	var dx = (hx - h) / cell_size
	var dz = (hz - h) / cell_size
	
	return Vector3(dx, 0, dz).normalized()

func _is_within_grid(world_pos: Vector3) -> bool:
	var half_size = grid_size * cell_size * 0.5
	var local_x = world_pos.x - grid_center.x
	var local_z = world_pos.z - grid_center.y
	
	return abs(local_x) <= half_size and abs(local_z) <= half_size

func _world_to_grid(world_pos: Vector2) -> Vector2:
	var half_size = grid_size * cell_size * 0.5
	var local_x = world_pos.x - grid_center.x
	var local_z = world_pos.y - grid_center.y
	
	var grid_x = (local_x + half_size) / cell_size
	var grid_z = (local_z + half_size) / cell_size
	
	return Vector2(grid_x, grid_z)

func _exit_tree():
	if update_thread and update_thread.is_alive():
		update_thread.wait_to_finish()

# Example usage in your existing water mesh script
# Add this method to your original water mesh script:

func get_height_optimized(world_pos: Vector3, physics_grid: WaterPhysicsGrid) -> float:
	"""Optimized height query using physics grid"""
	if physics_grid and physics_grid._is_within_grid(world_pos):
		return physics_grid.get_height_at(world_pos)
	else:
		# Fall back to original method for distant objects
		return get_height(world_pos)
