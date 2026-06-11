extends Node3D
class_name WaterInteractionGrid

@export var enabled: bool = true
@export var cell_size: float = 5.0
@export var grid_extent: Vector2 = Vector2(200.0, 200.0)
@export var disturbance_decay_rate: float = 0.35

var disturbances: Array[Dictionary] = []

func _process(delta: float) -> void:
	for i in range(disturbances.size() - 1, -1, -1):
		var disturbance := disturbances[i]
		disturbance["age"] += delta
		disturbance["strength"] = max(0.0, disturbance["strength"] - disturbance_decay_rate * delta)
		disturbance["dirty_water"] = max(0.0, disturbance["dirty_water"] - disturbance_decay_rate * delta)
		disturbance["prop_wash"] = max(0.0, disturbance["prop_wash"] - disturbance_decay_rate * delta)
		disturbances[i] = disturbance

		if disturbance["strength"] <= 0.0 and disturbance["dirty_water"] <= 0.0 and disturbance["prop_wash"] <= 0.0:
			disturbances.remove_at(i)


func add_disturbance(world_position: Vector3, strength: float, radius: float, direction: Vector3 = Vector3.ZERO, dirty_water: float = 0.0, prop_wash: float = 0.0, slip_multiplier: float = 1.0) -> void:
	if not enabled:
		return

	disturbances.append({
		"position": world_position,
		"strength": max(0.0, strength),
		"radius": max(radius, 0.01),
		"direction": direction,
		"dirty_water": max(0.0, dirty_water),
		"prop_wash": max(0.0, prop_wash),
		"slip_multiplier": max(0.0, slip_multiplier),
		"age": 0.0,
	})


func get_interaction_state(world_position: Vector3) -> Dictionary:
	if not enabled:
		return _default_state()

	var state := _default_state()

	for disturbance in disturbances:
		var offset := world_position - disturbance["position"]
		var planar_distance := Vector2(offset.x, offset.z).length()
		var radius: float = disturbance["radius"]

		if planar_distance > radius:
			continue

		var falloff := 1.0 - (planar_distance / radius)
		state["wake_strength"] += disturbance["strength"] * falloff
		state["dirty_water"] += disturbance["dirty_water"] * falloff
		state["prop_wash"] += disturbance["prop_wash"] * falloff
		state["turbulence"] += disturbance["strength"] * 0.25 * falloff
		state["current_velocity"] += disturbance["direction"] * disturbance["strength"] * falloff
		state["slip_multiplier"] = min(state["slip_multiplier"], lerp(1.0, disturbance["slip_multiplier"], falloff))

	return state


func _default_state() -> Dictionary:
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
