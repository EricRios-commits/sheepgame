extends Control

var menu_music: AudioStream

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.audio_manager.next_bgm()
	menu_music = Global.audio_manager.bgm.stream
	var classic := $VBoxContainer/StartButton
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	classic.text = "Puzzle Game"
	var downhill := classic.duplicate() as Button
	downhill.name = "DownhillButton"
	downhill.text = "Downhill Challenge"
	# duplicate() also copies persistent signal connections.
	for connection in downhill.pressed.get_connections():
		downhill.pressed.disconnect(connection.callable)
	$VBoxContainer.add_child(downhill)
	$VBoxContainer.move_child(downhill, 1)
	downhill.pressed.connect(_on_downhill_pressed)
	classic.grab_focus()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func _on_start_button_pressed() -> void:
	# Load on demand to preserve upstream's circular-dependency fix.
	get_tree().change_scene_to_file("res://scenes/Levels/level_1.tscn")

func _on_downhill_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/downhill/downhill_level_01.tscn")

func _on_quit_button_pressed() -> void:
	_release_menu_music()
	# Let the audio mixer drop its playback reference before engine shutdown.
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func _exit_tree() -> void:
	_release_menu_music()

func _release_menu_music() -> void:
	# Only release this menu's cue, never a replacement started by another scene.
	if is_instance_valid(Global.audio_manager) and Global.audio_manager.bgm.stream == menu_music:
		Global.audio_manager.stop_bgm()
		Global.audio_manager.bgm.stream = null
	menu_music = null
