class_name BoidGroundSource
extends Resource
## Where the ground comes from. Baking is source-specific and happens once at startup (or in a
## tool, with the result saved as a resource)


## Returns a baked heightfield covering `bounds` with lattice spacing `cell`, or null on failure.
## `sys` provides the scene context (world, node lookup). NaN heights mean "no ground".
func bake_ground(_sys: BoidSystem, _bounds: Rect2, _cell: float) -> BoidHeightfield:
	return null


## True if the source queries the physics space
func needs_physics() -> bool:
	return false


const NUDGE := 0.001
const NUDGES: Array[Vector2] = [Vector2(NUDGE, 0.0), Vector2(-NUDGE, 0.0), Vector2(0.0, NUDGE), Vector2(0.0, -NUDGE)]