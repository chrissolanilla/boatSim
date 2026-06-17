extends Node
class_name BuoyancyComponent

# ============================================================
# This component handles ALL buoyancy-related physics:
# - Archimedes buoyancy force
# - Water drag (linear and angular)
# - Upright stabilization
# - Angular velocity clamping
# ============================================================

@export_group("Buoyancy Settings")
@export var flotation_multiplier: float = 1.35
@export var max_submersion_depth: float = 1.25
@export var buoyancy_damping: float = 10.0
@export var buoyancy_normal_influence: float = 0.3
@export var water_density: float = 1000.0

@export_group("Drag Settings")
@export var drag: float = 2.5
@export var side_drag_multiplier: float = 2.8
@export var angular_drag: float = 12.0

@export_group("Stability")
@export var upright_stiffness: float = 2800.0
@export var upright_damping: float = 320.0
@export var max_angular_velocity: float = 6.0
@export var upright_only_when_submerged_ratio: float = 0.10

@export_group("Object Dimensions")
@export var object_width: float = 3.0
@export var object_height: float = 1.5
@export var object_length: float = 5.0

@export var buoyancy_points: Array[Vector3] = []

var parent_body: RigidBody3D
var water_manager: Node3D
var current_submerged_ratio: float = 0.0

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	parent_body = get_parent() as RigidBody3D
	if not parent_body:
		push_error("BuoyancyComponent must be child of RigidBody3D")
		return
	
	if buoyancy_points.is_empty():
		_generate_default_buoyancy_points()
	
	_find_water_manager()

func _generate_default_buoyancy_points() -> void:
	var hw: float = object_width * 0.4
	var hh: float = object_height * 0.4
	var hl: float = object_length * 0.45
	
	buoyancy_points = [
		Vector3(-hw, -hh, -hl),
		Vector3( hw, -hh, -hl),
		Vector3(-hw, -hh,  hl),
		Vector3( hw, -hh,  hl),
		Vector3(0.0, -object_height * 0.45, 0.0)
	]

func _find_water_manager() -> void:
	water_manager = get_tree().get_first_node_in_group("water_manager")
	if not water_manager:
		water_manager = get_node_or_null("/root/Level1/Water")
	if not water_manager:
		water_manager = get_node_or_null("../Water")

# ============================================================
# PUBLIC API - Called by parent RigidBody3D in _integrate_forces
# ============================================================

func apply_buoyancy(state: PhysicsDirectBodyState3D) -> Dictionary:
	if not water_manager or not parent_body:
		return _empty_water_state()
	
	if water_manager.has_method("get_water_state_at_position"):
		return _calculate_buoyancy(state, true)
	else:
		return _calculate_buoyancy(state, false)

func apply_drag_forces(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	var submerged_ratio: float = float(water_state.get("submerged_ratio", 0.0))
	var scale: float = max(submerged_ratio, 0.08)
	
	var basis: Basis = state.transform.basis
	var local_vel: Vector3 = basis.inverse() * state.linear_velocity
	
	var drag_force: Vector3 = basis * Vector3(
		-local_vel.x * abs(local_vel.x) * drag * side_drag_multiplier,
		-local_vel.y * abs(local_vel.y) * drag * 0.35,
		-local_vel.z * abs(local_vel.z) * drag
	) * scale
	
	state.apply_central_force(drag_force)
	
	var local_ang: Vector3 = basis.inverse() * state.angular_velocity
	var ang_drag: Vector3 = basis * Vector3(
		-local_ang.x * angular_drag * 1.4,
		-local_ang.y * angular_drag * 0.45,
		-local_ang.z * angular_drag * 1.4
	) * scale
	
	state.apply_torque(ang_drag)

func apply_upright_stabilization(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	var submerged_ratio: float = float(water_state.get("submerged_ratio", 0.0))
	if submerged_ratio < upright_only_when_submerged_ratio or upright_stiffness <= 0.0:
		return
	
	var boat_up: Vector3 = state.transform.basis.y.normalized()
	var tilt_axis: Vector3 = boat_up.cross(Vector3.UP)
	var tilt_amount: float = tilt_axis.length()
	
	if tilt_amount <= 0.0001:
		return
	
	var axis: Vector3 = tilt_axis.normalized()
	var ang_vel: float = state.angular_velocity.dot(axis)
	
	state.apply_torque(axis * (tilt_amount * upright_stiffness * submerged_ratio))
	state.apply_torque(axis * (-ang_vel * upright_damping * submerged_ratio))

func clamp_angular_velocity(state: PhysicsDirectBodyState3D) -> void:
	if max_angular_velocity <= 0.0:
		return
	if state.angular_velocity.length() > max_angular_velocity:
		state.angular_velocity = state.angular_velocity.normalized() * max_angular_velocity

# ============================================================
# PRIVATE - Buoyancy calculation
# ============================================================

func _calculate_buoyancy(state: PhysicsDirectBodyState3D, use_water_state: bool) -> Dictionary:
	var sample_count: int = buoyancy_points.size()
	if sample_count <= 0:
		return _empty_water_state()
	
	var submerged_points: int = 0
	var average_slip: float = 1.0
	var average_turbulence: float = 0.0
	var average_wake: float = 0.0
	
	var gravity_strength: float = abs(ProjectSettings.get_setting("physics/3d/default_gravity", 9.81))
	var object_volume: float = object_width * object_height * object_length
	var volume_per_point: float = object_volume / float(sample_count)
	var mass: float = parent_body.mass
	
	for local_point in buoyancy_points:
		var world_point: Vector3 = state.transform * local_point
		
		# Get water data at this point
		var surface_height: float
		var normal: Vector3 = Vector3.UP
		var slip: float = 1.0
		var turbulence: float = 0.0
		var wake: float = 0.0
		
		if use_water_state and water_manager.has_method("get_water_state_at_position"):
			var point_state: Dictionary = water_manager.get_water_state_at_position(world_point)
			surface_height = float(point_state.get("surface_height", 0.0))
			normal = point_state.get("normal", Vector3.UP)
			slip = float(point_state.get("slip_multiplier", 1.0))
			turbulence = float(point_state.get("turbulence", 0.0))
			wake = float(point_state.get("wake_strength", 0.0))
		elif water_manager.has_method("get_height_at_position"):
			surface_height = water_manager.get_height_at_position(world_point)
		else:
			continue
		
		var depth: float = surface_height - world_point.y
		
		average_slip = min(average_slip, slip)
		average_turbulence += turbulence
		average_wake += wake
		
		if depth <= 0.0:
			continue
		
		submerged_points += 1
		
		# Calculate forces
		var clamped_depth: float = min(depth, max_submersion_depth)
		var submersion_ratio: float = clamp(clamped_depth / max_submersion_depth, 0.0, 1.0)
		var displaced_volume: float = volume_per_point * submersion_ratio
		var buoyancy_magnitude: float = water_density * gravity_strength * displaced_volume * flotation_multiplier
		
		var buoyancy_direction: Vector3 = Vector3.UP.lerp(normal, buoyancy_normal_influence).normalized()
		var lever_arm: Vector3 = world_point - state.transform.origin
		var point_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(lever_arm)
		
		var buoyancy_force: Vector3 = buoyancy_direction * buoyancy_magnitude
		var vertical_speed: float = point_velocity.dot(buoyancy_direction)
		var damping_force: Vector3 = buoyancy_direction * (-vertical_speed * buoyancy_damping * mass / float(sample_count) * submersion_ratio)
		
		state.apply_force(buoyancy_force + damping_force, lever_arm)
	
	var submerged_ratio: float = float(submerged_points) / float(sample_count)
	if sample_count > 0:
		average_turbulence /= float(sample_count)
		average_wake /= float(sample_count)
	
	current_submerged_ratio = submerged_ratio
	
	return {
		"submerged_ratio": submerged_ratio,
		"slip_multiplier": average_slip,
		"turbulence": average_turbulence,
		"wake_strength": average_wake
	}

func _empty_water_state() -> Dictionary:
	return {
		"submerged_ratio": 0.0,
		"slip_multiplier": 1.0,
		"turbulence": 0.0,
		"wake_strength": 0.0
	}
