extends BuoyantObject

@export var bobbing_amplitude: float = 0.1
@export var bobbing_speed: float = 2.0

var time: float = 0.0

func _process(delta: float):
	time += delta
	
	# Add visual bobbing (physics handles actual buoyancy)
	var bob = sin(time * bobbing_speed) * bobbing_amplitude
	position.y += bob * delta  # Subtle visual effect

func _ready():
	super._ready()
	# Set random rotation for variety
	rotation.y = randf() * PI * 2
