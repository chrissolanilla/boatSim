extends CanvasLayer
@onready var buoys: Node3D = $"../Buoys"

@onready var n_buoy: LineEdit = $n_buoy
signal buoy_count_submitted(num_buoys: int)
var num_buoys: int
var buoys_arr = []
@export var buoy_scene: PackedScene
const EARTH_RADIUS_METERS := 6371000.0
@export var meters_per_unit: float = 1.0
var buoy_names: Array[String] = []
var buoy_labels_arr: Array[Label3D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_buoys = int(n_buoy.text)
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func set_buoy_names(names: Array[String]) -> void:
	buoy_names = names
	
func add_buoy_label(label_text: String, world_pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = label_text
	
	label.position = world_pos + Vector3(0, 35, 0)

	label.font_size = 1000
	label.pixel_size = 0.08
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true

	if label_text.begins_with("LLB"):
		label.modulate = Color.CYAN
	elif label_text == "StartFinish" or label_text == "S/F":
		label.modulate = Color.GREEN
	else:
		label.modulate = Color.YELLOW

	buoys.add_child(label)
	return label
	
func spawn_buoys(amount: int) -> void:
	num_buoys = amount
	for buoy in buoys_arr:
		buoy.queue_free()
	for label in buoy_labels_arr:
		label.queue_free()

	buoys_arr.clear()
	buoy_labels_arr.clear()

	for i in range(num_buoys):
		var instance = buoy_scene.instantiate()
		buoys.add_child(instance)
		instance.position = Vector3(i * 5, 5, 0)
		instance.scale = Vector3(20, 20, 20)
		buoys_arr.append(instance)
		
func _on_submit_n_buoys_pressed() -> void:
	num_buoys = int(n_buoy.text)
	print(num_buoys, " IS THE NUMB BUOYS")

	if num_buoys >= 1:
		self.visible = false
		buoy_count_submitted.emit(num_buoys)
		spawn_buoys(num_buoys)
			
func set_buoy_positions(coordinates: Array[Vector2]) -> void:
	if coordinates.is_empty():
		return
		
	for label in buoy_labels_arr:
		label.queue_free()
		
	buoy_labels_arr.clear()
	var origin := coordinates[0]
	for i in range(coordinates.size()):
		if i >= buoys_arr.size():
			break

		var coord := coordinates[i]
		var world_pos := gps_to_world_position(origin, coord)
		buoys_arr[i].position = world_pos
		buoys_arr[i].scale = Vector3(20, 20, 20)
		buoys_arr[i].position.y = 5
		var label_text := "B" + str(i + 1)
		if i < buoy_names.size():
			label_text = buoy_names[i]

		var label := add_buoy_label(label_text, buoys_arr[i].position)
		buoy_labels_arr.append(label)
		print("buoy ", i + 1, " gps: ", coord, " world pos: ", world_pos)

	print("buoys positioned")


func gps_to_world_position(origin: Vector2, point: Vector2) -> Vector3:
	# Vector2.x = longitude
	# Vector2.y = latitude

	var origin_lat_rad := deg_to_rad(origin.y)
	var point_lat_rad := deg_to_rad(point.y)

	var delta_lat_rad := deg_to_rad(point.y - origin.y)
	var delta_lon_rad := deg_to_rad(point.x - origin.x)

	var north_meters := delta_lat_rad * EARTH_RADIUS_METERS

	var average_lat := (origin_lat_rad + point_lat_rad) / 2.0
	var east_meters := delta_lon_rad * EARTH_RADIUS_METERS * cos(average_lat)

	return Vector3(
		-east_meters / meters_per_unit,
		0,
		north_meters / meters_per_unit
	)

func deg_to_rad(degrees: float) -> float:
	return degrees * PI / 180.0
