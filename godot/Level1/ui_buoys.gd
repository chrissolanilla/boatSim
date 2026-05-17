extends CanvasLayer

@onready var n_buoy: LineEdit = $n_buoy
signal buoy_count_submitted(num_buoys: int)
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
	if num_buoys >= 1:
		#hide the ui and show the cordinates ui
		self.visible = false
		buoy_count_submitted.emit(num_buoys)
