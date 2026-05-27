extends CanvasLayer

@onready var lat_input: LineEdit = $lat_input
@onready var lon_input: LineEdit = $lon_input
@onready var coordinate_unit: LineEdit = $coordinate_unit
@onready var loc_title: RichTextLabel = $loc_title
@onready var list_of_coordinates: RichTextLabel = $list_of_coordinates
@onready var try_again: RichTextLabel = $try_again


signal cordinates_ready(cordinates: Array[Vector2])

var num_buoys: int = 0
var current_buoy_index: int = 0
var coordinates_float: Array[Vector2] = []
var coordinates_input = {}
const EARTH_RADIUS_KM := 6371.0

func _ready() -> void:
	visible = false

func dict_to_vector(dict):
	for key in dict:
		var value = dict[key]
		if value.is_valid_float() == true:
			pass
		#coordinates_float.append()



func show_coordinate_ui(amount: int) -> void:
	num_buoys = amount
	current_buoy_index = 0
	
	coordinates_float.clear()
	
	for i in range(num_buoys):
		coordinates_float.append(Vector2.INF)
		
	visible = true
	_update_ui()



func _save_current_coordinate(show_error := true) -> bool:
	if not lat_input.text.is_valid_float(): #must be fixed to allow for non floats, we need to be able to allow all formats of gps so that we don't have to manually convert them, and can just plug them in
		if show_error:						#I take it back, we have to float the converted coordinates, we can convert them and put them in here to simplify it 
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

	coordinates_float[current_buoy_index] = Vector2(lon, lat)
	_show_error("")
	_update_coordinate_list()

	return true



func _update_ui() -> void:
	loc_title.text = "Buoy %d of %d" % [current_buoy_index + 1, num_buoys]

	var saved_coord := coordinates_float[current_buoy_index]

	if saved_coord == Vector2.INF:
		lat_input.text = ""
		lon_input.text = ""
	else:
		lon_input.text = str(saved_coord.x)
		lat_input.text = str(saved_coord.y)

	_update_coordinate_list()



func _update_coordinate_list() -> void:
	list_of_coordinates.clear()
	for i in range(coordinates_float.size()):
		var coord := coordinates_float[i]
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
		print(coordinates_float)
		cordinates_ready.emit(coordinates_float)



func _on_prev_pressed() -> void:
	_save_current_coordinate(false)
	if current_buoy_index > 0:
		current_buoy_index -= 1
		_update_ui()



func coordinate_normalization(coord_string: String) -> Vector2:
	#Parse a coordinate string and convert to Decimal Degrees (DD)
	
	#Supported formats:
	#DD:  "45.5083, -120.2375" or "45.5083 -120.2375"
	#DM:  "45° 30.5' -120° 45.75'" or "45 30.5 -120 45.75"
	#DMS: "45° 30' 30\" -120° 45' 45\"" or "45 30 30 -120 45 45"
	
	coord_string = coord_string.strip_edges()
	
	var has_degree_symbol = coord_string.find("°") != -1
	var has_minute_symbol = coord_string.find("'") != -1
	var has_second_symbol = coord_string.find("\"") != -1 or coord_string.find("''") != -1
	
	# Detect format
	if has_second_symbol:
		return _parse_dms_string(coord_string)
	elif has_minute_symbol or has_degree_symbol:
		return _parse_dm_string(coord_string)
	else:
		return _parse_dd_string(coord_string)



func _parse_dd_string(coord_string: String) -> Vector2:
	#"""Parse Decimal Degrees format: '45.5083, -120.2375'"""
	# Remove any commas and split by whitespace
	coord_string = coord_string.replace(",", " ")
	var parts = coord_string.strip_edges().split(" ", false)
	
	if parts.size() >= 2:
		var lat = float(parts[0])
		var lon = float(parts[1])
		return Vector2(lat, lon)
	
	print("Error parsing DD string")
	return Vector2(0, 0)



func _parse_dm_string(coord_string: String) -> Vector2:
	#"""Parse Degrees Decimal Minutes format: '45° 30.5' -120° 45.75''"""
	# Split into latitude and longitude parts
	var parts = coord_string.split(" ", false)
	
	# Find where longitude starts (look for negative sign or second number)
	var lat_parts = []
	var lon_parts = []
	var is_latitude = true
	
	for i in range(parts.size()):
		var part = parts[i]
		
		# If we find a negative sign or we've already collected enough for lat
		if part.contains("-") and i > 0:
			is_latitude = false
		
		if is_latitude:
			lat_parts.append(part)
		else:
			lon_parts.append(part)
	
	# Parse latitude
	var lat = _parse_dm_value(lat_parts)
	var lon = _parse_dm_value(lon_parts)
	
	return Vector2(lat, lon)



func _parse_dm_value(parts: Array) -> float:
	#"""Parse a single DM value like '45° 30.5'' to decimal degrees"""
	var degrees = 0.0
	var minutes = 0.0
	var is_negative = false
	
	for part in parts:
		# Remove degree and minute symbols
		var clean_part = part.replace("°", "").replace("'", "").strip_edges()
		
		if clean_part == "":
			continue
			
		var value = float(clean_part)
		
		# Check for negative
		if value < 0:
			is_negative = true
			value = abs(value)
		
		# First number is degrees, second is minutes
		if degrees == 0:
			degrees = value
		else:
			minutes = value
	
	var result = degrees + (minutes / 60.0)
	if is_negative:
		result = -result
	
	return result



func _parse_dms_string(coord_string: String) -> Vector2:
	#Parse Degrees Minutes Seconds format: '45° 30' 30" -120° 45' 45"'
	# Split into latitude and longitude parts
	var parts = coord_string.split(" ", false)
	
	var lat_parts = []
	var lon_parts = []
	var is_latitude = true
	
	for i in range(parts.size()):
		var part = parts[i]
		
		# If we find a negative sign or we've already collected 3 parts for lat
		if part.contains("-") and i > 0:
			is_latitude = false
		
		if is_latitude:
			lat_parts.append(part)
		else:
			lon_parts.append(part)
	
	# Parse latitude and longitude
	var lat = _parse_dms_value(lat_parts)
	var lon = _parse_dms_value(lon_parts)
	
	return Vector2(lat, lon)



func _parse_dms_value(parts: Array) -> float:
	#"""Parse a single DMS value like '45° 30' 30"' to decimal degrees"""
	var degrees = 0.0
	var minutes = 0.0
	var seconds = 0.0
	var is_negative = false
	var part_index = 0
	
	for part in parts:
		# Remove symbols
		var clean_part = part.replace("°", "").replace("'", "").replace("\"", "").strip_edges()
		
		if clean_part == "":
			continue
			
		var value = float(clean_part)
		
		# Check for negative
		if value < 0:
			is_negative = true
			value = abs(value)
		
		# Assign to degrees, minutes, or seconds in order
		match part_index:
			0:
				degrees = value
			1:
				minutes = value
			2:
				seconds = value
		
		part_index += 1
	
	var result = degrees + (minutes / 60.0) + (seconds / 3600.0)
	if is_negative:
		result = -result
	
	return result



func deg_to_rad_custom(deg: float) -> float:
	return deg * PI / 180



func harversine_distance(coord1: Vector2, coord2: Vector2) -> float:
	var lon1 = deg_to_rad_custom(coord1.x)
	var lat1 = deg_to_rad_custom(coord1.y)
	
	var lon2 = deg_to_rad_custom(coord2.x)
	var lat2 = deg_to_rad_custom(coord2.y)
	
	var dlon = lon2 - lon1
	var dlat = lat2 - lat1
	
	var a = sin(dlat / 2.0) * sin(dlat / 2.0) + cos(lat1) * cos(lat2) * sin(dlon / 2.0) * sin(dlon / 2.0)
		
	var c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	
	return EARTH_RADIUS_KM * c	
		
	
