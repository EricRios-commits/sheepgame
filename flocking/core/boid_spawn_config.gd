class_name BoidSpawnConfig
extends Resource

enum HeadingPolicy { RANDOM, FIXED, RADIAL_OUT, TOWARD_CENTER }

@export var species: StringName = &"sheep"
@export_range(0, 100000) var count := 100
@export var initial_state: StringName = &"idle"
@export var heading_policy: HeadingPolicy = HeadingPolicy.RANDOM
@export_range(-180.0, 180.0) var fixed_heading_degrees := 0.0
@export var initial_speed := 0.0
