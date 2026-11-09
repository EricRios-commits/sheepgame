extends Node3D

@export_range(30.0, 360.0, 5.0) var rotation_speed_degrees: float = 120
@export_node_path("Node3D") var follow_target_path: NodePath = ^"../Player"
@export_range(0.0, 3.0, 0.1) var follow_height: float = 0.6
@export_range(0.0, 20.0, 0.1) var follow_speed: float = 8.0

@export var camera: Camera3D

var _follow_target: Node3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_follow_target = get_node_or_null(follow_target_path) as Node3D
	if _follow_target:
		global_position = _follow_target.global_position + Vector3.UP * follow_height


func _process(delta: float) -> void:
	var turn_input := Input.get_axis("camera_right", "camera_left")
	if turn_input != 0.0:
		rotation.y = wrapf(rotation.y + deg_to_rad(rotation_speed_degrees) * turn_input * delta, -PI, PI)

	if _follow_target:
		var destination := _follow_target.get_global_transform_interpolated().origin + Vector3.UP * follow_height
		global_position = global_position.lerp(destination, 1.0 - exp(-follow_speed * delta))
