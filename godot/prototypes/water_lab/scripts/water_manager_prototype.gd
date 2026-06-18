extends Node3D

# ============================================================
# WATER MANAGER + WIND SYSTEM - Complete grid-based water physics
# - Grid-based wave propagation
# - Integrated wind system (waves + object forces)
# - Expanded visual mesh with camera following
# - Buoyancy for simple objects
# - Splash and disturbance system
# ============================================================

@export_group("Grid Configuration")
@export var grid_size := Vector2i(100, 100)
@export var cell_size := 1.0
@export var base_height := 0.0

@export_group("Wave Physics")
@export var wave_speed := 3.0
@export var damping := 0.995
@export var gravity := 9.81
@export var water_density := 1000.0

@export_group("Visualization")
@export var mesh_resolution := 50
@export var wave_color := Color(0.1, 0.3, 0.8, 0.7)
@export var foam_threshold := 0.3
@export var visual_scale_multiplier: float = 2.0
@export var follow_camera: bool = true
@export var camera_node: Camera3D = null

@export_group("Water Interaction Visuals")
@export var enable_water_ripples: bool = true
@export var ripple_lifetime: float = 2.0
@export var ripple_spread_speed: float = 3.0
@export var splash_intensity_multiplier: float = 1.0

@export_group("Wind")
@export var enable_wind: bool = true
@export var wind_direction: Vector3 = Vector3(1.0, 0.0, 0.5)
@export var wind_speed: float = 8.0
@export var gust_frequency: float = 0.3
@export var gust_strength_variation: float = 0.5
@export var wind_wave_strength: float = 0.15
@export var wind_push_force: float = 1.0

# ============================================================
# GRID DATA
# ============================================================
var height_map: Array = []
var previous_heights: Array = []
var velocity_map: Array = []
var foam_map: Array = []

# ============================================================
# OBJECT TRACKING
# ============================================================
var buoyant_objects: Array = []
var splashes: Array = []

# ============================================================
# WIND STATE
# ============================================================
var current_wind_vector: Vector3 = Vector3.ZERO
var gust_strength: float = 0.0
var gust_timer: float = 0.0
var gust_duration: float = 0.0
var target_gust_strength: float = 0.0
var wind_time: float = 0.0
var wind_noise: FastNoiseLite = null
var physics_frame_count: int = 0

# ============================================================
# VISUAL MESH
# ============================================================
var mesh_instance: MeshInstance3D = null
var water_material: StandardMaterial3D = null
var _last_camera_grid_pos: Vector2i = Vector2i(-999999, -999999)

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	add_to_group("water_manager")
	add_to_group("wind_system")
	
	# Init wind noise
	wind_noise = FastNoiseLite.new()
	wind_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	wind_noise.frequency = 0.01
	wind_noise.fractal_octaves = 3
	
	# Init wind
	current_wind_vector = wind_direction.normalized() * wind_speed
	gust_timer = randf_range(1.0, 3.0)
	
	_initialize_grids()
	_generate_visual_mesh()
	_find_camera()

func _initialize_grids() -> void:
	height_map.clear()
	previous_heights.clear()
	velocity_map.clear()
	foam_map.clear()
	
	for x in range(grid_size.x + 1):
		var h = []
		var p = []
		var v = []
		var f = []
		for z in range(grid_size.y + 1):
			h.append(base_height)
			p.append(base_height)
			v.append(0.0)
			f.append(0.0)
		height_map.append(h)
		previous_heights.append(p)
		velocity_map.append(v)
		foam_map.append(f)

func _find_camera() -> void:
	if camera_node:
		return
	var vp = get_viewport()
	if vp:
		camera_node = vp.get_camera_3d()

# ============================================================
# MAIN PHYSICS LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	physics_frame_count += 1
	
	if enable_wind:
		_update_wind(delta)
		_generate_gusts(delta)
		_apply_wind_to_grid(delta)
		_apply_wind_to_objects(delta)
	
	_update_object_displacement(delta)
	
	# ADD THIS LINE:
	_check_object_water_interactions(delta)
	
	_propagate_waves(delta)
	_apply_boundary_conditions()
	_apply_buoyancy_to_simple_objects(delta)
	_update_splashes(delta)
	
	if physics_frame_count % 2 == 0:
		_update_visual_mesh()

# ============================================================
# WIND SYSTEM
# ============================================================

func _update_wind(delta: float) -> void:
	wind_time += delta
	
	var base_wind: Vector3 = wind_direction.normalized() * wind_speed
	var variation: float = wind_noise.get_noise_2d(wind_time * 0.1, 0.0) * 0.3 * wind_speed
	var varying_wind: Vector3 = base_wind + wind_direction.normalized() * variation
	var gust_wind: Vector3 = wind_direction.normalized() * gust_strength
	var target: Vector3 = varying_wind + gust_wind
	
	var dir_noise: float = wind_noise.get_noise_2d(0.0, wind_time * 0.05)
	var perp: Vector3 = Vector3(wind_direction.z, 0.0, -wind_direction.x).normalized()
	target += perp * dir_noise * wind_speed * 0.2
	
	current_wind_vector = current_wind_vector.lerp(target, delta * 0.5)

func _generate_gusts(delta: float) -> void:
	gust_timer -= delta
	if gust_timer <= 0.0:
		gust_timer = randf_range(1.0 / max(gust_frequency, 0.01), 3.0 / max(gust_frequency, 0.01))
		gust_duration = randf_range(1.0, 4.0)
		target_gust_strength = wind_speed * randf_range(-gust_strength_variation, gust_strength_variation * 1.5)
	
	if gust_duration > 0.0:
		gust_duration -= delta
		gust_strength = lerp(gust_strength, target_gust_strength, delta * 2.0)
	else:
		gust_strength = lerp(gust_strength, 0.0, delta * 1.0)

func get_wind_at_position(position: Vector3) -> Vector3:
	var spatial: float = wind_noise.get_noise_3d(position.x * 0.05, position.y * 0.05, position.z * 0.05)
	var spatial_var: Vector3 = wind_direction.normalized() * spatial * wind_speed * 0.4
	var height_factor: float = clamp(position.y * 0.1, 0.0, 1.5)
	var height_var: Vector3 = wind_direction.normalized() * wind_speed * height_factor * 0.3
	return current_wind_vector + spatial_var + height_var

func _apply_wind_to_grid(delta: float) -> void:
	if not enable_wind:
		return
	
	var wind_dir: Vector3 = Vector3(current_wind_vector.x, 0.0, current_wind_vector.z).normalized()
	var ws: float = current_wind_vector.length()
	if ws < 0.2:
		return
	
	for x in range(0, grid_size.x + 1, 4):
		for z in range(0, grid_size.y + 1, 4):
			var wx: float = x * cell_size + global_position.x
			var wz: float = z * cell_size + global_position.z
			var wpos: Vector3 = Vector3(wx, height_map[x][z] + global_position.y, wz)
			
			var lw: Vector3 = get_wind_at_position(wpos)
			var lws: float = lw.length()
			if lws < 0.2:
				continue
			
			var hs: float = 0.021 * lws * lws
			var pf: float = 0.87 * pow(lws, -0.67)
			var fd: float = wpos.dot(wind_dir)
			var phase: float = fd * pf - wind_time * TAU * pf
			
			var wh: float = 0.0
			for i in range(3):
				wh += sin(phase * (1.0 + i * 0.2) + i * 1.5) * hs * exp(-i * 0.5) * 0.3 * wind_wave_strength
			
			height_map[x][z] = lerp(height_map[x][z], base_height + wh, 0.1)
			
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					var nx: int = x + dx
					var nz: int = z + dz
					if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
						height_map[nx][nz] = lerp(height_map[nx][nz], base_height + wh * exp(-sqrt(dx*dx+dz*dz) * 0.8) * 0.3, 0.05)
			
			if abs(wh) > hs * 0.6:
				foam_map[x][z] = min(foam_map[x][z] + delta * 2.0, 1.0)

func _apply_wind_to_objects(delta: float) -> void:
	if wind_push_force <= 0.0:
		return
	
	for object in buoyant_objects:
		if not is_instance_valid(object):
			continue
		if not object is RigidBody3D:
			continue
		if object.has_method("_apply_wind"):
			continue
		
		var wind: Vector3 = get_wind_at_position(object.global_position)
		var ws: float = wind.length()
		if ws < 0.5:
			continue
		
		var relative_wind: Vector3 = wind - object.linear_velocity
		var area: float = _estimate_object_area(object)
		var force: Vector3 = relative_wind.normalized() * relative_wind.length_squared() * 1.225 * area * 0.4 * wind_push_force
		object.apply_central_force(force * delta * 60.0)
		
		var forward: Vector3 = -object.global_transform.basis.z
		var wind_2d: Vector3 = Vector3(relative_wind.x, 0.0, relative_wind.z).normalized()
		var fwd_2d: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
		if wind_2d.length() > 0.1 and fwd_2d.length() > 0.1:
			object.apply_torque(Vector3.UP * fwd_2d.cross(wind_2d).y * ws * 0.05 * delta * 60.0)

func _estimate_object_area(object: RigidBody3D) -> float:
	for child in object.get_children():
		if child is CollisionShape3D and child.shape:
			if child.shape is BoxShape3D:
				var s: Vector3 = child.shape.size * object.scale
				return (s.x * s.y + s.y * s.z) * 0.5
			elif child.shape is SphereShape3D:
				var r: float = child.shape.radius * max(object.scale.x, max(object.scale.y, object.scale.z))
				return PI * r * r
	return pow(object.mass, 2.0/3.0) * 0.5

# ============================================================
# GRID WAVE PROPAGATION
# ============================================================

func _propagate_waves(delta: float) -> void:
	for x in range(grid_size.x + 1):
		for z in range(grid_size.y + 1):
			previous_heights[x][z] = height_map[x][z]
	
	var dt2: float = delta * delta
	var c2: float = wave_speed * wave_speed
	var dx2: float = cell_size * cell_size
	
	for x in range(2, grid_size.x - 2):
		for z in range(2, grid_size.y - 2):
			var laplacian: float = (height_map[x+1][z] + height_map[x-1][z] + height_map[x][z+1] + height_map[x][z-1] - 4.0 * height_map[x][z]) / dx2
			var new_height: float = 2.0 * height_map[x][z] - previous_heights[x][z] + c2 * laplacian * dt2
			
			var steepness: float = abs(laplacian)
			var adapt_damp: float = damping * (0.95 if steepness > 0.5 else 1.0)
			new_height = lerp(new_height, base_height, 1.0 - adapt_damp)
			new_height = clamp(new_height, base_height - 5.0, base_height + 5.0)
			
			velocity_map[x][z] = (new_height - previous_heights[x][z]) / max(delta, 0.0001)
			
			if steepness > foam_threshold:
				foam_map[x][z] = min(foam_map[x][z] + delta * 4.0, 1.0)
			else:
				foam_map[x][z] = max(foam_map[x][z] - delta * 2.0, 0.0)
			
			height_map[x][z] = new_height

func _apply_boundary_conditions() -> void:
	var w: int = 8
	for i in range(grid_size.x + 1):
		for z in range(w):
			var f: float = pow(float(z) / w, 2) * 0.9
			height_map[i][z] = lerp(height_map[i][z], base_height, f)
			height_map[i][grid_size.y - z] = lerp(height_map[i][grid_size.y - z], base_height, f)
	for i in range(grid_size.y + 1):
		for x in range(w):
			var f: float = pow(float(x) / w, 2) * 0.9
			height_map[x][i] = lerp(height_map[x][i], base_height, f)
			height_map[grid_size.x - x][i] = lerp(height_map[grid_size.x - x][i], base_height, f)

# ============================================================
# OBJECT INTERACTION WITH GRID
# ============================================================

func _update_object_displacement(delta: float) -> void:
	for object in buoyant_objects:
		if not is_instance_valid(object):
			continue
		if object.get_node_or_null("BuoyancyComponent"):
			continue
		
		var obj_pos: Vector3 = object.global_position
		var local_pos: Vector3 = obj_pos - global_position
		var obj_vel: Vector3 = object.linear_velocity
		var bounds: Vector3 = _get_object_bounds(object)
		if bounds == Vector3.ZERO:
			continue
		
		var he: Vector3 = bounds * 0.5
		var radius: int = int(max(he.x, he.z) * 1.5 / cell_size) + 2
		var cx: int = int(local_pos.x / cell_size)
		var cz: int = int(local_pos.z / cell_size)
		
		for x in range(max(0, cx - radius), min(grid_size.x, cx + radius)):
			for z in range(max(0, cz - radius), min(grid_size.y, cz + radius)):
				var dx: float = (x * cell_size - local_pos.x) / max(he.x, 0.1)
				var dz: float = (z * cell_size - local_pos.z) / max(he.z, 0.1)
				var dist: float = sqrt(dx*dx + dz*dz)
				if dist > 2.0:
					continue
				
				var falloff: float = exp(-dist * dist * 1.5)
				var h: float = height_map[x][z]
				var bottom: float = local_pos.y - he.y * sqrt(1.0 - min(dist*dist*0.5, 1.0))
				var top: float = local_pos.y + he.y * sqrt(1.0 - min(dist*dist*0.5, 1.0))
				
				if top < h:
					height_map[x][z] += (h - top) * falloff * 0.5
				elif bottom < h and top > h:
					var pen: float = h - bottom
					height_map[x][z] = lerp(h, bottom + pen * 0.2, falloff * 0.3)
				
				if obj_vel.length() > 0.5:
					var vdir: Vector3 = Vector3(obj_vel.x, 0, obj_vel.z).normalized()
					var fn: float = obj_vel.length() / sqrt(gravity * bounds.x)
					var rel: Vector3 = Vector3(x*cell_size - local_pos.x, 0, z*cell_size - local_pos.z)
					var bf: float = max(0, -rel.dot(vdir)) / max(radius*cell_size, 0.1)
					if bf > 0:
						height_map[x][z] -= obj_vel.length() * fn*fn * 0.1 * falloff * exp(-pow(abs(rel.cross(vdir).length()) - bf*tan(0.34), 2)*10) * bf * 0.05

func _get_object_bounds(object: RigidBody3D) -> Vector3:
	for child in object.get_children():
		if child is CollisionShape3D and child.shape:
			if child.shape is BoxShape3D:
				return child.shape.size * object.scale
			elif child.shape is SphereShape3D:
				var r: float = child.shape.radius * max(object.scale.x, max(object.scale.y, object.scale.z))
				return Vector3(r*2, r*2, r*2)
			elif child.shape is CapsuleShape3D:
				var r: float = child.shape.radius * max(object.scale.x, object.scale.z)
				return Vector3(r*2, child.shape.height*object.scale.y + r*2, r*2)
	var mi = object.find_child("MeshInstance3D", true, false)
	if mi and mi.mesh:
		return mi.mesh.get_aabb().size * object.scale
	if object.mass > 0:
		var s: float = pow(object.mass / water_density, 1.0/3.0)
		return Vector3(s, s, s)
	return Vector3(1, 1, 1)

# ============================================================
# BUOYANCY FOR SIMPLE OBJECTS
# ============================================================

func _apply_buoyancy_to_simple_objects(delta: float) -> void:
	for object in buoyant_objects:
		if not is_instance_valid(object): continue
		if object.get_node_or_null("BuoyancyComponent"): continue
		_calculate_buoyancy(object, delta)

func _calculate_buoyancy(object: RigidBody3D, delta: float) -> void:
	var bounds: Vector3 = _get_object_bounds(object)
	if bounds == Vector3.ZERO: return
	
	var he: Vector3 = bounds * 0.5
	var total_volume: float = bounds.x * bounds.y * bounds.z
	var pos: Vector3 = object.global_position
	var mass: float = object.mass
	
	# Get water height at object center
	var water_height: float = get_height_at_position(pos)
	var object_bottom: float = pos.y - he.y
	var depth: float = water_height - object_bottom
	
	if depth <= 0.0: return
	
	# Submersion ratio (0 = barely touching, 1 = fully submerged)
	var submerged_ratio: float = clamp(depth / bounds.y, 0.0, 1.0)
	var submerged_volume: float = total_volume * submerged_ratio
	
	# Archimedes: buoyancy = density * gravity * displaced_volume
	var buoyancy: float = water_density * gravity * submerged_volume
	
	# Damping based on vertical speed
	var damping: float = -object.linear_velocity.y * mass * 2.0 * submerged_ratio
	
	# Apply smooth forces
	object.apply_central_force(Vector3.UP * (buoyancy + damping))
	
	# Horizontal water drag
	var water_vel: Vector3 = get_water_velocity_at(pos)
	object.apply_central_force(-(object.linear_velocity - water_vel) * mass * 0.3 * submerged_ratio)
	
	# Angular drag
	object.angular_velocity *= 1.0 - min(submerged_ratio * 3.0 * delta, 0.9)
	
	# Keep upright gently
	var up: Vector3 = object.global_transform.basis.y
	var dot: float = up.dot(Vector3.UP)
	if dot < 0.95:
		var axis: Vector3 = up.cross(Vector3.UP).normalized()
		object.apply_torque(axis * (1.0 - dot) * mass * 2.0 * submerged_ratio)
		
		
# ============================================================
# WATER INTERACTION VISUALS - Ripples, splashes, foam
# ============================================================

func _check_object_water_interactions(delta: float) -> void:
	if not enable_water_ripples:
		return
	
	for object in buoyant_objects:
		if not is_instance_valid(object):
			continue
		
		var obj_pos: Vector3 = object.global_position
		var obj_vel: Vector3 = object.linear_velocity
		var speed: float = obj_vel.length()
		
		var bounds: Vector3 = _get_object_bounds(object)
		if bounds == Vector3.ZERO:
			continue
		
		var he: Vector3 = bounds * 0.5
		var water_height: float = get_height_at_position(obj_pos)
		var object_bottom: float = obj_pos.y - he.y
		var object_top: float = obj_pos.y + he.y
		var depth: float = water_height - object_bottom
		
		# Object is entering/exiting water
		if depth > 0 and depth < bounds.y * 0.3:
			# Object just touching surface - create gentle ripples
			if speed > 1.0:
				_create_ripple(obj_pos, speed * 0.3, 3.0)
		
		# Object moving through water creates wake foam
		if depth > 0.1 and speed > 2.0:
			_create_wake_foam(obj_pos, obj_vel, speed)
		
		# Object splashing down
		if object_bottom < water_height and object_top > water_height:
			var entry_speed: float = abs(obj_vel.y)
			if entry_speed > 2.0:
				var splash_radius: float = entry_speed * 0.5
				var splash_intensity: float = entry_speed * 0.05 * splash_intensity_multiplier
				create_splash(obj_pos, splash_intensity, splash_radius)
		
		# Object leaving water
		if object_bottom > water_height and obj_vel.y > 1.0:
			_create_ripple(obj_pos, obj_vel.y * 0.2, 2.0)

func _create_ripple(position: Vector3, intensity: float, radius: float) -> void:
	var local: Vector3 = position - global_position
	var cx: int = int(local.x / cell_size)
	var cz: int = int(local.z / cell_size)
	var r: int = ceili(radius)
	
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var nx: int = cx + dx
			var nz: int = cz + dz
			if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
				var dist: float = sqrt(dx * dx + dz * dz)
				if dist <= radius:
					var falloff: float = 1.0 - smoothstep(0.0, radius, dist)
					# Gentle ripple - small height change
					height_map[nx][nz] += intensity * falloff * falloff * 0.1

func _create_wake_foam(position: Vector3, velocity: Vector3, speed: float) -> void:
	var local: Vector3 = position - global_position
	var cx: int = int(local.x / cell_size)
	var cz: int = int(local.z / cell_size)
	var direction: Vector3 = Vector3(velocity.x, 0, velocity.z).normalized()
	
	# Add foam behind the object
	for i in range(1, 5):
		var behind: Vector3 = position - direction * i * 0.5
		var bx: int = int((behind.x - global_position.x) / cell_size)
		var bz: int = int((behind.z - global_position.z) / cell_size)
		
		if bx >= 0 and bx <= grid_size.x and bz >= 0 and bz <= grid_size.y:
			foam_map[bx][bz] = min(foam_map[bx][bz] + speed * 0.05, 1.0)
			
			# Spread foam to neighbors
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var nx: int = bx + dx
					var nz: int = bz + dz
					if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
						foam_map[nx][nz] = min(foam_map[nx][nz] + speed * 0.02, 0.6)
						
						
						
# ============================================================
# GRID QUERIES
# ============================================================

func get_height_at_position(world_pos: Vector3) -> float:
	var local: Vector3 = world_pos - global_position
	var gx: float = local.x / cell_size
	var gz: float = local.z / cell_size
	var x0: int = clampi(int(floor(gx)), 0, grid_size.x)
	var z0: int = clampi(int(floor(gz)), 0, grid_size.y)
	var x1: int = clampi(x0 + 1, 0, grid_size.x)
	var z1: int = clampi(z0 + 1, 0, grid_size.y)
	var fx: float = clampf(gx - x0, 0.0, 1.0)
	var fz: float = clampf(gz - z0, 0.0, 1.0)
	return lerp(lerp(height_map[x0][z0], height_map[x1][z0], fx), lerp(height_map[x0][z1], height_map[x1][z1], fx), fz)

func get_water_velocity_at(world_pos: Vector3) -> Vector3:
	var local: Vector3 = world_pos - global_position
	var gx: int = clampi(int(local.x / cell_size), 1, grid_size.x - 1)
	var gz: int = clampi(int(local.z / cell_size), 1, grid_size.y - 1)
	var dhx: float = (height_map[gx+1][gz] - height_map[gx-1][gz]) / (2.0 * cell_size)
	var dhz: float = (height_map[gx][gz+1] - height_map[gx][gz-1]) / (2.0 * cell_size)
	var vel: Vector3 = Vector3(-dhx * wave_speed, velocity_map[gx][gz], -dhz * wave_speed)
	if enable_wind:
		var w: Vector3 = get_wind_at_position(world_pos)
		vel += Vector3(w.x, 0, w.z) * 0.03
	return vel

func get_water_state_at_position(world_pos: Vector3) -> Dictionary:
	var h: float = get_height_at_position(world_pos)
	var n: Vector3 = _get_water_normal_at(world_pos)
	var v: Vector3 = get_water_velocity_at(world_pos)
	var local: Vector3 = world_pos - global_position
	var gx: int = clampi(int(local.x / cell_size), 1, grid_size.x - 1)
	var gz: int = clampi(int(local.z / cell_size), 1, grid_size.y - 1)
	var steep: float = abs(height_map[gx+1][gz] - height_map[gx-1][gz]) + abs(height_map[gx][gz+1] - height_map[gx][gz-1])
	return {
		"surface_height": h,
		"normal": n,
		"velocity": v,
		"turbulence": min(steep*2.0, 1.0),
		"slip_multiplier": 1.0 - min(steep*2.0, 1.0) * 0.5,
		"wake_strength": foam_map[gx][gz] if gx <= grid_size.x and gz <= grid_size.y else 0.0
	}

func _get_water_normal_at(world_pos: Vector3) -> Vector3:
	var local: Vector3 = world_pos - global_position
	var gx: int = clampi(int(local.x/cell_size), 1, grid_size.x-1)
	var gz: int = clampi(int(local.z/cell_size), 1, grid_size.y-1)
	return Vector3(
		(height_map[max(gx-1,0)][gz] - height_map[min(gx+1,grid_size.x)][gz]) / (2.0*cell_size),
		1.0,
		(height_map[gx][max(gz-1,0)] - height_map[gx][min(gz+1,grid_size.y)]) / (2.0*cell_size)
	).normalized()

func get_water_height_at_position(world_pos: Vector3) -> float:
	return get_height_at_position(world_pos)

func get_water_height_global() -> float:
	return global_position.y + base_height

# ============================================================
# SPLASHES
# ============================================================

func create_splash(position: Vector3, intensity: float, radius: float = 2.0) -> void:
	var local: Vector3 = position - global_position
	var cx: int = int(local.x/cell_size)
	var cz: int = int(local.z/cell_size)
	var r: int = ceili(radius)
	for dx in range(-r, r+1):
		for dz in range(-r, r+1):
			var nx: int = cx+dx
			var nz: int = cz+dz
			if nx >= 0 and nx <= grid_size.x and nz >= 0 and nz <= grid_size.y:
				var dist: float = sqrt(dx*dx+dz*dz)
				if dist <= radius:
					height_map[nx][nz] += intensity * pow(1.0 - smoothstep(0.0, radius, dist), 2)
	splashes.append({
		"position": position,
		"intensity": intensity,
		"radius": radius,
		"lifetime": 2.0,
		"age": 0.0
	})

func add_disturbance(position: Vector3, intensity: float, radius: float, direction := Vector3.ZERO, velocity_strength := 0.0, turbulence := 0.0, slip := 1.0) -> void:
	create_splash(position, intensity, radius)

func _update_splashes(delta: float) -> void:
	var a: Array = []
	for s in splashes:
		s.age += delta
		if s.age < s.lifetime:
			a.append(s)
	splashes = a

# ============================================================
# OBJECT REGISTRATION
# ============================================================

func register_buoyant_object(object: RigidBody3D) -> void:
	if object not in buoyant_objects:
		buoyant_objects.append(object)

func unregister_buoyant_object(object: RigidBody3D) -> void:
	buoyant_objects.erase(object)

# ============================================================
# VISUAL MESH
# ============================================================

func _generate_visual_mesh() -> void:
	# Remove old mesh if it exists
	if mesh_instance:
		mesh_instance.queue_free()
		mesh_instance = null
	
	var vcx: int = int(grid_size.x * visual_scale_multiplier)
	var vcz: int = int(grid_size.y * visual_scale_multiplier)
	var vr: int = int(mesh_resolution * visual_scale_multiplier)
	var hx: float = vcx * cell_size * 0.5
	var hz: float = vcz * cell_size * 0.5
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var sx: float = float(vcx) / vr
	var sz: float = float(vcz) / vr
	
	# Generate vertices
	for x in range(vr + 1):
		for z in range(vr + 1):
			var lx: float = x * sx * cell_size - hx
			var lz: float = z * sz * cell_size - hz
			
			st.set_uv(Vector2(float(x) / vr, float(z) / vr))
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(lx, 0.0, lz))  # Store relative to mesh origin
	
	# Generate triangles (counter-clockwise for upward-facing normals)
	for x in range(vr):
		for z in range(vr):
			var i: int = x * (vr + 1) + z
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + vr + 2)
			st.add_index(i)
			st.add_index(i + vr + 2)
			st.add_index(i + vr + 1)
	
	st.generate_normals()
	
	# Create mesh instance
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "WaterMesh"
	mesh_instance.mesh = st.commit()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Create proper water material
	water_material = StandardMaterial3D.new()
	water_material.albedo_color = wave_color
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.05
	water_material.metallic = 0.1
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides
	water_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	
	mesh_instance.material_override = water_material
	
	# Position at water level
	mesh_instance.position = Vector3(0, base_height, 0)
	
	add_child(mesh_instance)
	
func _update_visual_mesh() -> void:
	if not mesh_instance:
		return
	
	# Follow camera if enabled
	if follow_camera:
		_follow_camera_position()
	
	var vcx: int = int(grid_size.x * visual_scale_multiplier)
	var vcz: int = int(grid_size.y * visual_scale_multiplier)
	var vr: int = int(mesh_resolution * visual_scale_multiplier)
	var hx: float = vcx * cell_size * 0.5
	var hz: float = vcz * cell_size * 0.5
	var mesh_center: Vector3 = mesh_instance.global_position
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var sx: float = float(vcx) / vr
	var sz: float = float(vcz) / vr
	
	for x in range(vr + 1):
		for z in range(vr + 1):
			var lx: float = x * sx * cell_size - hx
			var lz: float = z * sz * cell_size - hz
			var world_pos := Vector3(mesh_center.x + lx, 0.0, mesh_center.z + lz)
			
			# Get actual wave height at this world position
			var height: float = get_height_at_position(world_pos) - mesh_center.y
			var foam: float = _get_foam_at(world_pos)
			
			st.set_uv(Vector2(float(x) / vr, float(z) / vr))
			
			# Color with foam
			var c: Color = wave_color
			var height_factor: float = clamp((height + 1.0) * 0.3, 0.0, 1.0)
			c = c.lightened(height_factor * 0.2)
			c.a = 0.7 + foam * 0.3
			st.set_color(c)
			
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(lx, height, lz))
	
	# Triangles - proper winding order
	for x in range(vr):
		for z in range(vr):
			var i: int = x * (vr + 1) + z
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + vr + 2)
			st.add_index(i)
			st.add_index(i + vr + 2)
			st.add_index(i + vr + 1)
	
	st.generate_normals()
	mesh_instance.mesh = st.commit()
	
func _follow_camera_position() -> void:
	if not mesh_instance:
		return
	_find_camera()
	if not camera_node:
		return
	
	var cam: Vector3 = camera_node.global_position
	var gx: int = int(floor(cam.x / cell_size))
	var gz: int = int(floor(cam.z / cell_size))
	var gp := Vector2i(gx, gz)
	
	if gp == _last_camera_grid_pos:
		return
	_last_camera_grid_pos = gp
	
	# Move mesh to camera position, keeping Y at water level
	mesh_instance.global_position = Vector3(
		gx * cell_size,
		global_position.y + base_height,
		gz * cell_size
	)

func _get_foam_at(world_pos: Vector3) -> float:
	var local := world_pos - global_position
	var gx := clampi(int(local.x/cell_size), 0, grid_size.x)
	var gz := clampi(int(local.z/cell_size), 0, grid_size.y)
	if gx < foam_map.size() and gz < foam_map[gx].size():
		return foam_map[gx][gz]
	return 0.0

func smoothstep(e0: float, e1: float, x: float) -> float:
	var t = clampf((x - e0) / max(e1 - e0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
