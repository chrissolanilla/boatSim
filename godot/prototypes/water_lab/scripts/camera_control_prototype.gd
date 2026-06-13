extends Camera3D

@export var target: Node3D
@export var follow_speed := 5.0
@export var rotation_speed := 3.0
@export var distance := 10.0
@export var height := 5.0
@export var look_ahead := 3.0
@export var water_clip_margin := 0.5

var current_rotation := Vector3.ZERO
var mouse_sensitivity := 0.002
var water_manager: Node3D

func _ready():
	if target:
		current_rotation = rotation
	water_manager = get_tree().get_first_node_in_group("water_manager")

func _physics_process(delta):
	if not target:
		return
	
	# Calculate desired position
	var target_velocity = Vector3.ZERO
	if target is RigidBody3D:
		target_velocity = target.linear_velocity
	
	var look_target = target.global_position + target_velocity.normalized() * look_ahead
	look_target.y = target.global_position.y
	
	# Rotate around target
	var cam_offset = Vector3(
		distance * sin(current_rotation.y) * cos(current_rotation.x),
		height + distance * sin(current_rotation.x),
		distance * cos(current_rotation.y) * cos(current_rotation.x)
	)
	
	var desired_position = look_target + cam_offset
	
	# Ensure camera stays above water
	if water_manager and water_manager.has_method("get_height_at_position"):
		var water_height = water_manager.get_height_at_position(desired_position)
		desired_position.y = max(desired_position.y, water_height + water_clip_margin)
	
	# Smooth interpolation
	global_position = global_position.lerp(desired_position, follow_speed * delta)
	look_at(look_target)

func _input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		current_rotation.y -= event.relative.x * mouse_sensitivity
		current_rotation.x -= event.relative.y * mouse_sensitivity
		current_rotation.x = clamp(current_rotation.x, -PI/4, PI/4)
