extends Control

@onready var first_focus = $VBoxContainer/StartButton

func _ready():
	Global.audio_manager.next_bgm()
	first_focus.grab_focus()

func _on_start_button_pressed() -> void:
	# This cannot be a preload because that leads to a circular dependency
	var first_level = load("res://scenes/Levels/level_1.tscn")
	get_tree().change_scene_to_packed(first_level)
	

func _on_quit_button_pressed() -> void:
	get_tree().quit()
