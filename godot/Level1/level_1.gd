extends Node3D
#idk how many we need. However, using code to instantiate them will have a big slow down
# we should use object culling instead
# we probably wont need more than like 20.
# just like move the ones up to the ones they need and hide the rest.
@onready var n_buoys: CanvasLayer = $n_buoys
@onready var buoy_coordinates: CanvasLayer = $buoy_coordinates

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	n_buoys.buoy_count_submitted.connect(
		buoy_coordinates.show_coordinate_ui
	)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
