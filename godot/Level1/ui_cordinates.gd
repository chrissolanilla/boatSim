extends CanvasLayer

var num_buoys: int = 0

func _ready() -> void:
	visible = false

func show_coordinate_ui(amount: int) -> void:
	num_buoys = amount
	visible = true
	print("coordinate ui opened for ", num_buoys, " buoys")
