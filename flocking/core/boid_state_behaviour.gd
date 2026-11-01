class_name BoidStateBehaviour
extends Resource
## Everything that defines how one species acts in one state.

@export var state: StringName = &"idle"
@export var max_speed := 4.0
@export var max_accel := 6.0
@export var influences: Array[BoidInfluenceEntry] = []
@export var transitions: Array[BoidTransition] = []