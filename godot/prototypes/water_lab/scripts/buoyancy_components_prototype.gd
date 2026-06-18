extends Node
class_name BuoyancyComponent

# ============================================================
# REALISTIC BUOYANCY - Proper Archimedes + Critical Damping
# ============================================================

@export_group("Object Dimensions (REQUIRED)")
@export var object_width: float = 3.0
@export var object_height: float = 1.5
@export var object_length: float = 5.0

@export_group("Buoyancy Tuning")
@export var flotation_multiplier: float = 1.0  # 1.0 = realistic
@export var max_submersion_depth: float = 1.25
@export var buoyancy_damping: float = 3.0  # Higher = smoother ride
@export var buoyancy_normal_influence: float = 0.3

@export_group("Drag Settings")
@export var drag: float = 2.5
@export var side_drag_multiplier: float = 2.8
@export var angular_drag: float = 8.0

@export_group("Stability")
@export var upright_stiffness: float = 500.0
@export var upright_damping: float = 100.0
@export var max_angular_velocity: float = 6.0
@export var upright_only_when_submerged_ratio: float = 0.10

@export var buoyancy_points: Array[Vector3] = []

var parent_body: RigidBody3D
var water_manager: Node3D
var current_submerged_ratio: float = 0.0

func _ready():
	parent_body = get_parent() as RigidBody3D
	if not parent_body:
		push_error("BuoyancyComponent must be child of RigidBody3D")
		return
	
	if buoyancy_points.is_empty():
		_generate_default_buoyancy_points()
	
	parent_body.linear_damp = 0.0
	parent_body.angular_damp = 0.0
	parent_body.continuous_cd = true
	
	_find_water_manager()

func _generate_default_buoyancy_points():
	var hw = object_width * 0.35
	var hh = object_height * 0.3
	var hl = object_length * 0.4
	
	buoyancy_points = [
		Vector3(-hw, -hh, -hl),
		Vector3( hw, -hh, -hl),
		Vector3(-hw, -hh,  hl),
		Vector3( hw, -hh,  hl),
		Vector3(0.0, -object_height * 0.4, 0.0)
	]

func _find_water_manager():
	water_manager = get_tree().get_first_node_in_group("water_manager")
	if not water_manager:
		water_manager = get_node_or_null("/root/Level1/Water")
	if not water_manager:
		water_manager = get_node_or_null("../Water")

func apply_buoyancy(state: PhysicsDirectBodyState3D) -> Dictionary:
	if not water_manager or not parent_body:
		return _empty_water_state()
	
	if water_manager.has_method("get_water_state_at_position"):
		return _apply_buoyancy_with_water_state(state)
	elif water_manager.has_method("get_height_at_position"):
		return _apply_buoyancy_with_height_map(state)
	else:
		return _empty_water_state()

func _apply_buoyancy_with_water_state(state: PhysicsDirectBodyState3D) -> Dictionary:
	var sample_count: int = buoyancy_points.size()
	if sample_count <= 0:
		return _empty_water_state()
	
	var submerged_points: int = 0
	var average_slip: float = 1.0
	var average_turbulence: float = 0.0
	var average_wake: float = 0.0
	var total_depth: float = 0.0
	
	var gravity_strength: float = abs(ProjectSettings.get_setting("physics/3d/default_gravity", 9.81))
	var object_mass: float = parent_body.mass
	var object_volume: float = object_width * object_height * object_length
	var volume_per_point: float = object_volume / float(sample_count)
	var water_density: float = 1000.0
	
	for local_point in buoyancy_points:
		var world_point: Vector3 = state.transform * local_point
		var point_state: Dictionary = water_manager.get_water_state_at_position(world_point)
		
		var surface_height: float = float(point_state.get("surface_height", 0.0))
		var depth: float = surface_height - world_point.y
		
		average_slip = min(average_slip, float(point_state.get("slip_multiplier", 1.0)))
		average_turbulence += float(point_state.get("turbulence", 0.0))
		average_wake += float(point_state.get("wake_strength", 0.0))
		
		if depth <= 0.0:
			continue
		
		submerged_points += 1
		total_depth += depth
		
		var clamped_depth: float = min(depth, max_submersion_depth)
		var submersion_ratio: float = clamp(clamped_depth / max_submersion_depth, 0.0, 1.0)
		var displaced_volume: float = volume_per_point * submersion_ratio
		
		# ARCHIMEDES: buoyancy force at this point
		var buoyancy_force_magnitude: float = water_density * gravity_strength * displaced_volume * flotation_multiplier
		
		var normal: Vector3 = point_state.get("normal", Vector3.UP)
		var buoyancy_direction: Vector3 = Vector3.UP.lerp(normal, buoyancy_normal_influence).normalized()
		
		var lever_arm: Vector3 = world_point - state.transform.origin
		
		# VELOCITY DAMPING - critical for smooth riding
		# Damping force proportional to velocity through water
		var point_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(lever_arm)
		var velocity_in_buoyancy_dir: float = point_velocity.dot(buoyancy_direction)
		
		# Critical damping formula: damping = 2 * sqrt(mass * spring_constant)
		# Simplified: damp harder when moving faster through water
		var damping_force_magnitude: float = -velocity_in_buoyancy_dir * buoyancy_damping * object_mass * submersion_ratio
		
		var buoyancy_force: Vector3 = buoyancy_direction * buoyancy_force_magnitude
		var damping_force: Vector3 = buoyancy_direction * damping_force_magnitude
		
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

func _apply_buoyancy_with_height_map(state: PhysicsDirectBodyState3D) -> Dictionary:
	var sample_count: int = buoyancy_points.size()
	if sample_count <= 0:
		return _empty_water_state()
	
	var submerged_points: int = 0
	var total_depth: float = 0.0
	
	var gravity_strength: float = abs(ProjectSettings.get_setting("physics/3d/default_gravity", 9.81))
	var object_mass: float = parent_body.mass
	var object_volume: float = object_width * object_height * object_length
	var volume_per_point: float = object_volume / float(sample_count)
	var water_density: float = 1000.0
	
	for local_point in buoyancy_points:
		var world_point: Vector3 = state.transform * local_point
		var surface_height: float = water_manager.get_height_at_position(world_point)
		var depth: float = surface_height - world_point.y
		
		if depth <= 0.0:
			continue
		
		submerged_points += 1
		total_depth += depth
		
		var clamped_depth: float = min(depth, max_submersion_depth)
		var submersion_ratio: float = clamp(clamped_depth / max_submersion_depth, 0.0, 1.0)
		var displaced_volume: float = volume_per_point * submersion_ratio
		var buoyancy_force_magnitude: float = water_density * gravity_strength * displaced_volume * flotation_multiplier
		
		var lever_arm: Vector3 = world_point - state.transform.origin
		var point_velocity: Vector3 = state.linear_velocity + state.angular_velocity.cross(lever_arm)
		var vertical_velocity: float = point_velocity.y
		
		var buoyancy_force: Vector3 = Vector3.UP * buoyancy_force_magnitude
		var damping_force: Vector3 = Vector3.UP * (-vertical_velocity * buoyancy_damping * object_mass * submersion_ratio)
		
		state.apply_force(buoyancy_force + damping_force, lever_arm)
	
	var submerged_ratio: float = float(submerged_points) / float(sample_count)
	current_submerged_ratio = submerged_ratio
	
	return {
		"submerged_ratio": submerged_ratio,
		"slip_multiplier": 1.0,
		"turbulence": 0.0,
		"wake_strength": 0.0
	}

func apply_drag_forces(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	var submerged_ratio: float = float(water_state.get("submerged_ratio", 0.0))
	var submersion_scale: float = max(submerged_ratio, 0.08)
	
	var basis: Basis = state.transform.basis
	var local_velocity: Vector3 = basis.inverse() * state.linear_velocity
	
	var drag_local: Vector3 = Vector3(
		-local_velocity.x * abs(local_velocity.x) * drag * side_drag_multiplier,
		-local_velocity.y * abs(local_velocity.y) * drag * 0.35,
		-local_velocity.z * abs(local_velocity.z) * drag
	) * submersion_scale
	
	state.apply_central_force(basis * drag_local)
	
	var local_angular: Vector3 = basis.inverse() * state.angular_velocity
	var local_angular_drag: Vector3 = Vector3(
		-local_angular.x * angular_drag * 1.4,
		-local_angular.y * angular_drag * 0.45,
		-local_angular.z * angular_drag * 1.4
	) * submersion_scale
	
	state.apply_torque(basis * local_angular_drag)

func apply_upright_stabilization(state: PhysicsDirectBodyState3D, water_state: Dictionary) -> void:
	var submerged_ratio: float = float(water_state.get("submerged_ratio", 0.0))
	if submerged_ratio < upright_only_when_submerged_ratio:
		return
	
	if upright_stiffness <= 0.0:
		return
	
	var boat_up: Vector3 = state.transform.basis.y.normalized()
	var tilt_axis: Vector3 = boat_up.cross(Vector3.UP)
	var tilt_amount: float = tilt_axis.length()
	
	if tilt_amount <= 0.0001:
		return
	
	var corrective_axis: Vector3 = tilt_axis.normalized()
	var angular_velocity_along_axis: float = state.angular_velocity.dot(corrective_axis)
	
	var spring_torque: Vector3 = corrective_axis * (tilt_amount * upright_stiffness * submerged_ratio)
	var damping_torque: Vector3 = corrective_axis * (-angular_velocity_along_axis * upright_damping * submerged_ratio)
	
	state.apply_torque(spring_torque + damping_torque)

func clamp_angular_velocity(state: PhysicsDirectBodyState3D) -> void:
	if max_angular_velocity <= 0.0:
		return
	
	if state.angular_velocity.length() > max_angular_velocity:
		state.angular_velocity = state.angular_velocity.normalized() * max_angular_velocity

func _empty_water_state() -> Dictionary:
	return {
		"submerged_ratio": 0.0,
		"slip_multiplier": 1.0,
		"turbulence": 0.0,
		"wake_strength": 0.0
	}
