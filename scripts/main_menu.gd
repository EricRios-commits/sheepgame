extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var classic := $VBoxContainer/StartButton
	classic.text = "Classic Puzzle"
	var downhill := classic.duplicate() as Button
	downhill.name = "DownhillButton"
	downhill.text = "Downhill Herd"
	# duplicate() also copies persistent signal connections.
	for connection in downhill.pressed.get_connections():
		downhill.pressed.disconnect(connection.callable)
	$VBoxContainer.add_child(downhill)
	$VBoxContainer.move_child(downhill, 0)
	downhill.pressed.connect(_on_downhill_pressed)
	downhill.grab_focus()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	# Load on demand to preserve upstream's circular-dependency fix.
	get_tree().change_scene_to_file("res://scenes/Levels/level_1.tscn")

func _on_downhill_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/downhill/downhill_level_01.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
