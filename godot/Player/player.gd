extends CharacterBody3D

@onready var camera_3d: Camera3D = $Camera3D
@onready var model: MeshInstance3D = $Object_2
@onready var model_collision: CollisionShape3D = $CollisionShape3D

const SPEED := 8.0
const SPRINT_SPEED := 20.0
const MOUSE_SENSITIVITY := 0.003
#not prop pitch lol
var pitch := 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#for no clip
	model_collision.disabled = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# rotate body left/right
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

		# rotate camera up/down
		pitch -= event.relative.y * MOUSE_SENSITIVITY
		pitch = clamp(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		camera_3d.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO

	# forward/back follows where the camera is looking
	if Input.is_action_pressed("move_forward"):
		direction += -camera_3d.global_transform.basis.z

	if Input.is_action_pressed("move_backward"):
		direction += camera_3d.global_transform.basis.z

	# left/right strafes relative to the player/camera yaw
	if Input.is_action_pressed("move_left"):
		direction += global_transform.basis.x

	if Input.is_action_pressed("move_right"):
		direction += -global_transform.basis.x

	# minecraft-style vertical movement
	if Input.is_action_pressed("move_up"):
		direction += Vector3.UP

	if Input.is_action_pressed("move_down"):
		direction += Vector3.DOWN

	direction = direction.normalized()

	var current_speed := SPEED

	if Input.is_action_pressed("sprint"):
		current_speed = SPRINT_SPEED

	velocity = direction * current_speed
	move_and_slide()
