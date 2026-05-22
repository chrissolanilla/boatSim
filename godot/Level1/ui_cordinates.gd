extends CanvasLayer

@onready var lat_input: LineEdit = $lat_input
@onready var lon_input: LineEdit = $lon_input
@onready var loc_title: RichTextLabel = $loc_title
@onready var list_of_coordinates: RichTextLabel = $list_of_coordinates
@onready var try_again: RichTextLabel = $try_again

signal cordinates_ready(cordinates: Array[Vector2])

var num_buoys: int = 0
var current_buoy_index: int = 0
var coordinates: Array[Vector2] = []

func _ready() -> void:
	visible = false

func show_coordinate_ui(amount: int) -> void:
	num_buoys = amount
	current_buoy_index = 0
	coordinates.clear()
	
	for i in range(num_buoys):
		coordinates.append(Vector2.INF)
		
	visible = true
	_update_ui()

func _save_current_coordinate(show_error := true) -> bool:
	if not lat_input.text.is_valid_float():
		if show_error:
			_show_error("latitude must be a number")
		return false

	if not lon_input.text.is_valid_float():
		if show_error:
			_show_error("longitude must be a number")
		return false

	var lat := float(lat_input.text)
	var lon := float(lon_input.text)

	if lat < -90.0 or lat > 90.0:
		if show_error:
			_show_error("latitude must be between -90 and 90")
		return false

	if lon < -180.0 or lon > 180.0:
		if show_error:
			_show_error("longitude must be between -180 and 180")
		return false

	coordinates[current_buoy_index] = Vector2(lon, lat)
	_show_error("")
	_update_coordinate_list()

	return true

func _update_ui() -> void:
	loc_title.text = "Buoy %d of %d" % [current_buoy_index + 1, num_buoys]

	var saved_coord := coordinates[current_buoy_index]

	if saved_coord == Vector2.INF:
		lat_input.text = ""
		lon_input.text = ""
	else:
		lon_input.text = str(saved_coord.x)
		lat_input.text = str(saved_coord.y)

	_update_coordinate_list()

func _update_coordinate_list() -> void:
	list_of_coordinates.clear()
	for i in range(coordinates.size()):
		var coord := coordinates[i]
		if coord == Vector2.INF:
			list_of_coordinates.append_text("Buoy %d: not entered yet\n" % [i + 1])
		else:
			list_of_coordinates.append_text(
				"Buoy %d: lat %.6f, lon %.6f\n" % [i + 1, coord.y, coord.x]
			)

func _show_error(message: String) -> void:
	try_again.text = message

func _on_next_pressed() -> void:
	if not _save_current_coordinate():
		return

	if current_buoy_index < num_buoys - 1:
		current_buoy_index += 1
		_update_ui()
	else:
		print("all buoys entered")
		print(coordinates)
		cordinates_ready.emit(coordinates)

func _on_prev_pressed() -> void:
	_save_current_coordinate(false)
	if current_buoy_index > 0:
		current_buoy_index -= 1
		_update_ui()
