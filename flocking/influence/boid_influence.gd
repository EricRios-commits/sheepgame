class_name BoidInfluence
extends Resource
## Base class of an influence strategy. Resource holding parameters only 
## No mutable runtime data
##
## Layers give the combination policy its priorities (lower number = higher priority):
##   SAFETY  obstacles, bounds, pen gate
##   THREAT  dog, predators
##   SOCIAL  cohesion, alignment, separation
##   AMBIENT cruise speed, wander, lures

enum Layer { SAFETY, THREAT, SOCIAL, AMBIENT }
const LAYER_COUNT := 4

@export var layer: Layer = Layer.AMBIENT


func create_runtime() -> BoidInfluenceRuntime:
	return null


## Largest neighbour query radius this influence needs (0 if it does not query neighbours).
func neighbour_radius() -> float:
	return 0.0
