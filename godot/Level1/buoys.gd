extends Control

@onready var lat_input: LineEdit = $"../../buoy_coordinates/lat_input"
@onready var lon_input: LineEdit = $"../../buoy_coordinates/lon_input"
@onready var h_box_container: HBoxContainer = $"../../buoy_coordinates/HBoxContainer"
@onready var list_of_coordinates: RichTextLabel = $"../../buoy_coordinates/HBoxContainer/list_of_coordinates"
@onready var n_buoy: LineEdit = $"."
@onready var try_again: RichTextLabel = $"../../buoy_coordinates/try_again"
@onready var coord_unit_input: LineEdit = $"../../buoy_coordinates/coord_unit_input"
var coord_pairs = {}
var lat_list = []
var lon_list = []
var x = 0


func _ready() -> void:
	n_buoy.text_submitted.connect(_number_of_inputs)
	coord_unit_input.text_submitted.connect(_coordinate_normilization)
	lat_input.text_submitted.connect( _lat_text_submitted )
	_number_of_inputs()
	lon_input.text_submitted.connect( _lon_text_submitted )
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _coordinate_dict(key, value):
	coord_pairs[float(key)] = float(value)
	return coord_pairs
	
	
func _number_of_inputs(number_of_buoys = 2 ): # put two as a minimum number available there
	number_of_buoys = number_of_buoys.to_int()
	if number_of_buoys < 2:
		print("Not Enough Buoys to calculate data, Please input 2 or more to calculate distance")
	else:
		for i in number_of_buoys:
			if i < number_of_buoys:
				i += 1
		
	
func _lat_text_submitted(new_text: String): #takes lat input and is supposed to start converting it to floats instead of strings
	var x
	if new_text.is_valid_float():
		x = float(new_text)
		lat_list.append(new_text)
	else:
		print("Cannot return float, entry of data is wrong")
		return_try_again_message("Lattitude")
	
func _lon_text_submitted(new_text: String): #same thing but lon input
	var x
	if new_text.is_valid_float():
		x = float(new_text)
		lon_list.append(new_text)
	else:
		print("Cannot return float, entry of data is wrong")
		return_try_again_message("Longittude")
	
func _coordinate_normilization(unit, coord): #I started doing this so that we can have coordinates normalized to the format of decimal degrees as I think the harversine formula works with that unit
	if unit.strip_edges().to_lower() == "dmm": #decimal minutes 
		x = coord.strip_edges()
		
		
	else:
		if unit.strip_edges().to_lower() == "dms": # degrees, minutes, seconds format
			x = coord.strip_edges()
			
		else: #this was for if the unit is left blank, it should automatically choose the decimal degrees but I have not yet set that up
			if unit.strip_edges().to_lower() == "":
					pass
			pass
	
func return_try_again_message(error_type: String): #error message for the wrong input
	try_again.text = "Your input was wrong please do a new input for %s" %  [error_type]
	await get_tree().create_timer(3.0).timeout
	try_again.clear()
	
#func _split():
	


func _on_editing_toggled(toggled_on: bool) -> void: #this was to start allowing us to edit the rich text label to fix any mistakes made when entering data but it is just a functon from rich text labels
	pass # Replace with function body.
	
func _buoy_placement(): #I was going to put the harversine formula here to allow us to build a track based off of the first buoy
	pass
	
func _edit_list_of_coords(): #this was where the script for editing the 
	pass
