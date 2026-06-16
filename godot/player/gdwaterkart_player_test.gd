extends Node3D

@onready var kart: Kart = $Kart
@onready var camera_pivot: Node3D = $CameraPivot

var ocean_node: Ocean


func _ready() -> void:
	ocean_node = get_tree().get_first_node_in_group("ocean")


func _process(_delta: float) -> void:
	camera_pivot.global_position = kart.visual_parent.global_position + Vector3(0, 5, 8)
	RenderingServer.global_shader_parameter_set("player_position", kart.global_position)

	if ocean_node:
		ocean_node.set_player_position(kart.global_position)
		if kart.water_buoyancy_sensor.is_on_water() and randf() < pow(kart.velocity.length() / max(kart.top_speed, 0.001), 2.0):
			var strength: float = clamp(0.2 * Vector2(kart.velocity.x, kart.velocity.z).length(), 0.0, 1.0)
			strength += clamp(2.0 * abs(kart.velocity.y), 0.0, 1.0)
			ocean_node.add_ripple(kart.global_position, 1.0, strength * 0.025)
