extends Node3D
@export var target: Node3D
@export var follow_speed := 5.0
@export var offset := Vector3(-7, 7, 7)
@onready var cam: Camera3D = $Pitch/Camera3D

var look_at: Vector3

func _ready():
	look_at = target.global_position

func _process(delta):
	if not target:
		return
	var desired = target.global_position + offset
	var t := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(desired, t)
	
