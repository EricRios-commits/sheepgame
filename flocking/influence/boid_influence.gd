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

## Priority layer an influence contributes to. Layers are combined in this order.
enum Layer {
	## Highest priority: obstacles, bounds, pen gate.
	SAFETY,
	## Dog, predators.
	THREAT,
	## Cohesion, alignment, separation.
	SOCIAL,
	## Lowest priority: cruise speed, wander, lures.
	AMBIENT,
}
## Number of entries in Layer. Must be kept equal to the enum's size.
const LAYER_COUNT := 4

## Priority layer this influence adds its acceleration to. Layers are visited from SAFETY to
## AMBIENT and share each boid's max acceleration budget, so a lower-priority layer only gets
## whatever the higher-priority layers leave unused.
@export var layer: Layer = Layer.AMBIENT


## Creates the object that applies this influence each tick. The base class returns null;
## subclasses override this.
func create_runtime() -> BoidInfluenceRuntime:
	return null


## Largest neighbour query radius this influence needs (0 if it does not query neighbours).
func neighbour_radius() -> float:
	return 0.0