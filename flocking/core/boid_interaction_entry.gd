class_name BoidInteractionEntry
extends Resource
## How species A treats neighbours of species B inside the flock influence.

@export var species_a: StringName = &"sheep"
@export var species_b: StringName = &"goat"
@export var cohesion := 1.0
@export var alignment := 1.0
@export var separation := 1.0