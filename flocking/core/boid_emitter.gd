class_name BoidEmitter
extends Node3D
## External actor (dog, predator, lure) that boids react to

@export var system: BoidSystem
@export var kind: StringName = &"dog"
@export var radius := 20.0
@export var strength := 1.0
@export var curve: Curve
@export var active := true
@export_range(1.0, 180.0) var cone_half_angle_degrees := 180.0
## If true the cone points along the direction of travel (when moving), else along the node's
## Y rotation plus facing_degrees.
@export var face_velocity := true
@export var facing_degrees := 0.0

var kind_id := -1
var vel := Vector2.ZERO
var _last_xz := Vector2.ZERO
var _have_last := false


func _ready() -> void:
	if system != null:
		system.register_emitter(self)


func _exit_tree() -> void:
	if system != null and is_instance_valid(system):
		system.unregister_emitter(self)


func _physics_process(delta: float) -> void:
	var p := xz()
	if _have_last and delta > 0.0:
		vel = (p - _last_xz) / delta
	_last_xz = p
	_have_last = true


func xz() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func dir_xz() -> Vector2:
	if face_velocity and vel.length_squared() > 0.01:
		return vel.normalized()
	var a := global_rotation.y + deg_to_rad(facing_degrees)
	return Vector2(sin(a), cos(a))