extends Node3D

@export_range(30.0, 360.0, 5.0) var rotation_speed_degrees: float = 120
@export_node_path("Node3D") var follow_target_path: NodePath = ^"../Player"
@export_range(0.0, 3.0, 0.1) var follow_height: float = 0.6
@export_range(0.0, 20.0, 0.1) var follow_speed: float = 8.0

var _follow_target: Node3D
var _q_held := false
var _e_held := false


func _ready() -> void:
	_follow_target = get_node_or_null(follow_target_path) as Node3D
	if _follow_target:
		global_position = _follow_target.global_position + Vector3.UP * follow_height


func _process(delta: float) -> void:
	var turn_input := 0.0
	if _q_held:
		turn_input += 1.0
	if _e_held:
		turn_input -= 1.0
	if turn_input != 0.0:
		rotation.y = wrapf(rotation.y + deg_to_rad(rotation_speed_degrees) * turn_input * delta, -PI, PI)

	if _follow_target:
		var destination := _follow_target.global_position + Vector3.UP * follow_height
		global_position = global_position.lerp(destination, 1.0 - exp(-follow_speed * delta))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return

	var key_event := event as InputEventKey
	if key_event.echo:
		return

	match key_event.physical_keycode:
		KEY_Q:
			_q_held = key_event.pressed
			get_viewport().set_input_as_handled()
		KEY_E:
			_e_held = key_event.pressed
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_q_held = false
		_e_held = false
