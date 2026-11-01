class_name BoidGroundSourceWorld
extends BoidGroundSource

@export_flags_3d_physics var collision_mask := 1
## Rays run from max_height down to min_height (world y).
@export var max_height := 500.0
@export var min_height := -500.0


func needs_physics() -> bool:
	return true


func bake_ground(sys: BoidSystem, bounds: Rect2, cell: float) -> BoidHeightfield:
	var state := sys.get_world_3d().direct_space_state
	if state == null:
		push_error("BoidGroundSourceWorld: no physics space available.")
		return null
	var hf := BoidHeightfield.new()
	hf.setup_lattice(bounds, cell)
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = collision_mask
	var w := hf.width
	var hits := 0
	for i in hf.heights.size():
		var x := hf.origin.x + (i % w) * cell
		var z := hf.origin.y + (i / w) * cell
		var h := _cast(state, q, x, z)
		if is_nan(h):
			for off in NUDGES:
				h = _cast(state, q, x + off.x, z + off.y)
				if not is_nan(h):
					break
		hf.heights[i] = h
		if not is_nan(h):
			hits += 1
	if hits == 0:
		push_warning("BoidGroundSourceWorld: no ground found. Is anything on collision mask %d inside the world bounds, and has the physics space been updated?" % collision_mask)
	return hf


func _cast(state: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, x: float, z: float) -> float:
	q.from = Vector3(x, max_height, z)
	q.to = Vector3(x, min_height, z)
	var hit := state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else NAN