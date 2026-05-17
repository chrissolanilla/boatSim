extends Node3D
#idk how many we need. However, using code to instantiate them will have a big slow down
# we should use object culling instead
# we probably wont need more than like 20.
# just like move the ones up to the ones they need and hide the rest.

@onready var buoy: Node3D = $Buoys/Buoy
@onready var buoys_parent_node: Node3D = $Buoys
@onready var n_buoy: LineEdit = $n_buoys/n_buoy

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	


func _on_n_buoy_editing_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.
