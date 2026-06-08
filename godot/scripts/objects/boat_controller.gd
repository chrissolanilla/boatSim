extends RigidBody3D

@export var engine_force: float = 500.0
@export var turn_torque: float = 800.0
@export var max_speed: float = 15.0
@export var reverse_force: float = 300.0

var throttle: float = 0.0
var steering: float = 0.0

func _ready():
	# Set up input mapping if not already done
	_setup_input_map()

func _setup_input_map():
	# Check if input actions exist, create them if not
	var input_map = InputMap
	if not InputMap.has_action("boat_forward"):
		InputMap.add_action("boat_forward")
		var event = InputEventKey.new()
		event.keycode = KEY_W
		InputMap.action_add_event("boat_forward", event)
	
	if not InputMap.has_action("boat_backward"):
		InputMap.add_action("boat_backward")
		var event = InputEventKey.new()
		event.keycode = KEY_S
		InputMap.action_add_event("boat_backward", event)
	
	if not InputMap.has_action("boat_left"):
		InputMap.add_action("boat_left")
		var event = InputEventKey.new()
		event.keycode = KEY_A
		InputMap.action_add_event("boat_left", event)
	
	if not InputMap.has_action("boat_right"):
		InputMap.add_action("boat_right")
		var event = InputEventKey.new()
		event.keycode = KEY_D
		InputMap.action_add_event("boat_right", event)

func _process(delta):
	# Get input
	throttle = 0.0
	if Input.is_action_pressed("boat_forward"):
		throttle = 1.0
	elif Input.is_action_pressed("boat_backward"):
		throttle = -0.6
	
	steering = 0.0
	if Input.is_action_pressed("boat_left"):
		steering = 1.0
	elif Input.is_action_pressed("boat_right"):
		steering = -1.0

func _integrate_forces(state: PhysicsDirectBodyState3D):
	# Apply engine force
	var forward_dir = -global_transform.basis.z
	var force = forward_dir * engine_force * throttle
	if throttle < 0:
		force = forward_dir * reverse_force * throttle
	state.apply_central_force(force)
	
	# Apply turning torque
	if abs(throttle) > 0.1:
		var torque = Vector3.UP * turn_torque * steering * throttle
		state.apply_torque(torque)
	
	# Limit speed
	if state.linear_velocity.length() > max_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_speed
