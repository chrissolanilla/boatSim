extends Node3D
#idk how many we need. However, using code to instantiate them will have a big slow down
# we should use object culling instead
# we probably wont need more than like 20.
# just like move the ones up to the ones they need and hide the rest.

@onready var buoys_parent_node: Node3D = $Buoys
var buoys_array := [Node3D]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
