class_name BoidEmitter
extends Node3D
## External actor (dog, predator, lure) that boids react to

## Central BoidSystem to interact with
@export var system: BoidSystem
## Kind of emitter. Boids can be configured to react differently depending on kind
@export var kind: StringName = &"dog"
## Radius of effect
@export var radius := 20.0
## Baseline Strength
@export var strength := 1.0
## Curve to define strength effect
@export var curve: Curve
## Whether the emitter is active and interacts with the BoidSystem
@export var active := true
## Half-angle of the emitter's cone of effect, in degrees. 180 means a full circle (no cone).
@export_range(1.0, 180.0) var cone_half_angle_degrees := 180.0
## If true the cone points along the direction of travel (when moving), else along the node's
## Y rotation plus facing_degrees.
@export var face_velocity := true
## Extra yaw offset, in degrees, added to the node's Y rotation when the cone is not
## following velocity (or when the emitter is nearly stationary).
@export var facing_degrees := 0.0

## Index assigned to this emitter's kind. -1 until resolved.
var kind_id := -1
## Velocity on the ground (XZ) plane, in world units per second. Updated every physics frame.
var ground_velocity := Vector2.ZERO
var _previous_ground_position := Vector2.ZERO
var _has_previous_position := false


func _ready() -> void:
	if system != null:
		system.register_emitter(self)


func _exit_tree() -> void:
	if system != null and is_instance_valid(system):
		system.unregister_emitter(self)


func _physics_process(delta: float) -> void:
	var ground_position := xz()
	if _has_previous_position and delta > 0.0:
		ground_velocity = (ground_position - _previous_ground_position) / delta
	_previous_ground_position = ground_position
	_has_previous_position = true


func xz() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func dir_xz() -> Vector2:
	if face_velocity and ground_velocity.length_squared() > 0.01:
		return ground_velocity.normalized()
	var a := global_rotation.y + deg_to_rad(facing_degrees)
	return Vector2(sin(a), cos(a))
