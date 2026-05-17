extends CanvasLayer

@onready var n_buoy: LineEdit = $n_buoy

var num_buoys: int
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_buoys = int(n_buoy.text)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_submit_n_buoys_pressed() -> void:
	num_buoys = int(n_buoy.text)
	print(num_buoys, " IS THE NUMB BUOYS")
	pass # Replace with function body.
