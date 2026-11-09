extends Control

@export var target_level: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	if target_level:
		get_tree().change_scene_to_packed(target_level)
	else:
		push_error("No target level assigned")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
