extends Camera3D

@export var move_speed: float = 25.0
@export var mouse_sensitivity: float = 0.002

var mouse_captured: bool = false
var yaw: float = 0.0
var pitch: float = 0.0

func _ready():
	capture_mouse()
	# Store initial rotation
	yaw = rotation.y
	pitch = rotation.x

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_mouse_capture()
	
	if event is InputEventMouseMotion and mouse_captured:
		# Update yaw and pitch (horizontal and vertical look)
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		
		# Limit pitch to prevent flipping over
		pitch = clamp(pitch, -1.4, 1.4)
		
		# Apply rotations (yaw around Y axis, pitch around X axis)
		rotation.y = yaw
		rotation.x = pitch

func _process(delta):
	if not mouse_captured:
		return
	
	var speed = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed = move_speed * 2.0
	
	var move_dir = Vector3.ZERO
	
	# Get input
	if Input.is_key_pressed(KEY_W):
		move_dir.z += 1
	if Input.is_key_pressed(KEY_S):
		move_dir.z -= 1
	if Input.is_key_pressed(KEY_A):
		move_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		move_dir.x += 1
	if Input.is_key_pressed(KEY_Q):
		move_dir.y += 1
	if Input.is_key_pressed(KEY_E):
		move_dir.y -= 1
	
	# Normalize diagonal movement
	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
	
	# Calculate movement based on yaw only (camera direction on XZ plane)
	var forward = Vector3(-sin(yaw), 0, -cos(yaw))
	var right = Vector3(cos(yaw), 0, -sin(yaw))
	var up = Vector3(0, 1, 0)
	
	var movement = forward * move_dir.z + right * move_dir.x + up * move_dir.y
	position += movement * speed * delta

func capture_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func release_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false

func toggle_mouse_capture():
	if mouse_captured:
		release_mouse()
	else:
		capture_mouse()
