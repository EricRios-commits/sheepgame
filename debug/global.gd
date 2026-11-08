extends Node

var debug_panel: DebugPanel
var audio_manager: AudioManager

func _ready() -> void:
	var audio_scene = preload("res://scenes/audio_manager.tscn").instantiate()
	add_child(audio_scene)
	audio_manager = audio_scene
