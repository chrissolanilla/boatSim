extends CanvasLayer
@onready var buoys: Node3D = $"../Buoys"

@onready var n_buoy: LineEdit = $n_buoy
signal buoy_count_submitted(num_buoys: int)
var num_buoys: int
var buoys_arr = []
@export var buoy_scene: PackedScene
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
		#spawn n number of buoy scences
		for i in range(num_buoys):
			var instance = buoy_scene.instantiate()
			buoys.add_child(instance)
			#change the position to the actual user entered position
			instance.position = Vector3(i, i, i)
			buoys_arr.append(instance)
			
func set_buoy_positions(coordinates: Array[Vector2]) -> void:
	for i in range(coordinates.size()):
		if i >= buoys_arr.size():
			break
		var coord := coordinates[i]
		# coord.x is longitude
		# coord.y is latitude
		var lon := coord.x
		var lat := coord.y
		# for now, directly map lon/lat into world x/z
		# later you may want to scale/convert these better
		buoys_arr[i].position = Vector3(lon, 0, lat)
		
	print("buoys positioned")
