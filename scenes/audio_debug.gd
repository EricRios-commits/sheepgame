extends Node

@export var audio_manager: AudioManager

var enabled = false

func _input(event: InputEvent) -> void:
	if enabled && event is InputEventKey:
		var key_event = event as InputEventKey
		if !key_event.pressed:
			return
		if key_event.keycode == KEY_SPACE:
			audio_manager.next_bgm()
		if key_event.keycode == KEY_BACKSPACE:
			audio_manager.stop_bgm()
		if key_event.keycode == KEY_S:
			audio_manager.trigger_sfx("sheep_baa")
		if key_event.keycode == KEY_A:
			audio_manager.trigger_sfx("star_achieved")
		if key_event.keycode == KEY_1:
			audio_manager.trigger_sfx("star_achieved",0)
		if key_event.keycode == KEY_2:
			audio_manager.trigger_sfx("star_achieved",1)
		if key_event.keycode == KEY_3:
			audio_manager.trigger_sfx("star_achieved",2)
		
