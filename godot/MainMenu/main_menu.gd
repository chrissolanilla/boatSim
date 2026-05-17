extends Control
@onready var button: Button = $Button



func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Level1/Level1.tscn")


func _escapeMenu(event):
	if event is InputEventKey and event.pressed():
		if event.keycode == KEY_ESCAPE:
			show()
	pass 
