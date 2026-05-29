extends Node3D
#idk how many we need. However, using code to instantiate them will have a big slow down
# we should use object culling instead
# we probably wont need more than like 20.
# just like move the ones up to the ones they need and hide the rest.
@onready var n_buoys: CanvasLayer = $n_buoys
@onready var buoy_coordinates: CanvasLayer = $buoy_coordinates
@export var debug_load_buoys_from_file := true
@export var debug_buoy_file_path := "res://Level1/defaultCords.txt"
var debug_buoy_names: Array[String] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	n_buoys.buoy_count_submitted.connect(
		buoy_coordinates.show_coordinate_ui
	)
	#define the on receive method
	buoy_coordinates.cordinates_ready.connect(
		n_buoys.set_buoy_positions
	)

	#hide the uis at first 
	n_buoys.visible = true
	buoy_coordinates.visible = false
	var mesh_instance := $"528Feet/Cube"
	var aabb :AABB= mesh_instance.get_aabb()
	print("local size: ", aabb.size)
	print("global scale: ", mesh_instance.global_scale)
	print("THE THING IS: ", get_global_aabb_size(mesh_instance))
	if debug_load_buoys_from_file:
		load_debug_buoys()
		return


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func get_global_aabb_size(mesh_instance: MeshInstance3D) -> Vector3:
	var local_aabb := mesh_instance.get_aabb()
	var global_basis := mesh_instance.global_transform.basis

	var x_size := global_basis.x.length() * local_aabb.size.x
	var y_size := global_basis.y.length() * local_aabb.size.y
	var z_size := global_basis.z.length() * local_aabb.size.z

	return Vector3(x_size, y_size, z_size)
	
func load_debug_buoys() -> void:
	var coordinates := load_buoy_coordinates_from_file(debug_buoy_file_path)

	if coordinates.is_empty():
		print("no debug buoy coordinates loaded")
		return

	print("loaded debug buoy count: ", coordinates.size())

	n_buoys.visible = false
	buoy_coordinates.visible = false

	n_buoys.set_buoy_names(debug_buoy_names)
	n_buoys.spawn_buoys(coordinates.size())
	n_buoys.set_buoy_positions(coordinates)

	
func load_buoy_coordinates_from_file(path: String) -> Array[Vector2]:
	var coordinates: Array[Vector2] = []
	debug_buoy_names.clear()

	if not FileAccess.file_exists(path):
		print("debug buoy file does not exist: ", path)
		return coordinates

	var file := FileAccess.open(path, FileAccess.READ)

	while not file.eof_reached():
		var line := file.get_line().strip_edges()

		if line == "":
			continue

		if line.begins_with("#"):
			continue

		var parts := line.split(",", false)

		if parts.size() < 3:
			print("bad buoy line: ", line)
			continue

		var name := parts[0].strip_edges()
		var lat_text := parts[1].strip_edges()
		var lon_text := parts[2].strip_edges()

		var lat := parse_degree_decimal_minutes(lat_text)
		var lon := parse_degree_decimal_minutes(lon_text)

		if is_nan(lat) or is_nan(lon):
			print("bad coordinate for ", name, ": ", line)
			continue

		var coord := Vector2(lon, lat)

		debug_buoy_names.append(name)
		coordinates.append(coord)

		print(name, " -> lat: ", lat, " lon: ", lon)

	return coordinates
	
func parse_degree_decimal_minutes(text: String) -> float:
	var cleaned := text.strip_edges().to_upper()

	if cleaned.is_valid_float():
		return float(cleaned)

	var direction := ""

	if cleaned.begins_with("N") or cleaned.begins_with("S") or cleaned.begins_with("E") or cleaned.begins_with("W"):
		direction = cleaned.substr(0, 1)
		cleaned = cleaned.substr(1).strip_edges()
	else:
		return NAN

	cleaned = cleaned.replace("°", " ")
	cleaned = cleaned.replace("'", " ")
	cleaned = cleaned.replace(",", " ")

	var parts := cleaned.split(" ", false)

	if parts.size() < 2:
		return NAN

	if not parts[0].is_valid_float() or not parts[1].is_valid_float():
		return NAN

	var degrees := float(parts[0])
	var minutes := float(parts[1])

	var result := degrees + minutes / 60.0

	if direction == "S" or direction == "W":
		result *= -1.0

	return result
