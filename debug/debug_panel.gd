class_name DebugPanel extends PanelContainer

@onready var property_list := $MarginContainer/VBoxContainer

func _ready() -> void:
	Global.debug_panel = self
	visible = false
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		visible = not visible
		
func _process(_delta: float) -> void:
	if visible:
		var framerate := Engine.get_frames_per_second()
		add_debug_property("FPS", str(framerate))
		var ms := 1000.0 / maxf(framerate, 1)
		ms = round(ms * 10000.0) / 10000.0		
		add_debug_property("MS per frame", str(ms))
		
func add_debug_property(title: String, value: String) -> void:
	var target := property_list.get_node_or_null(title)
	## check if label and treat as such
	if target != null and target is Label:
		var label := target as Label
		label.text = title + ": " + value
	else:
		var label := Label.new()
		label.name = title
		label.text = title + ": " + value
		property_list.add_child(label)
