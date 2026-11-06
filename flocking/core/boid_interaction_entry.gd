class_name BoidInteractionEntry
extends Resource
## How species A treats neighbours of species B inside the flock influence.

## Species being influenced (the boid whose steering is affected by this entry).
@export var species_a: StringName = &"sheep"
## Species of the neighbours that species A reacts to.
@export var species_b: StringName = &"goat"
## Cohesion weight: how strongly species A is pulled toward the center of nearby species B
## neighbours. 1.0 is the baseline, 0.0 ignores them.
@export var cohesion := 1.0
## Alignment weight: how strongly species A matches the heading/velocity of nearby species B
## neighbours. 1.0 is the baseline, 0.0 ignores them.
@export var alignment := 1.0
## Separation weight: how strongly species A steers away from nearby species B neighbours to
## avoid crowding. 1.0 is the baseline, 0.0 ignores them.
@export var separation := 1.0