class_name BoidInfluenceBounds
extends BoidInfluence
## Soft boundary influence. Boids are pushed back into the world bounds when they get too close to the edge.
@export_range(0.1, 100.0, 0.1, "or_greater") var margin := 15.0


func _init() -> void:
	layer = Layer.SAFETY


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


class Runtime extends BoidInfluenceRuntime:
	var margin := 15.0

	func _init(res: BoidInfluenceBounds) -> void:
		margin = res.margin

	func apply(sys: BoidSystem, order: PackedInt32Array, from: int, to: int, weight: float,
			_vmax: float, acc: PackedVector2Array) -> void:
		if not sys.use_world_bounds:
			return
		var pos := sys.store.pos
		var b_min := sys.world_bounds.position
		var b_max := sys.world_bounds.end
		var inv := 1.0 / margin
		for k in range(from, to):
			var slot := order[k]
			var p := pos[slot]
			var push := Vector2(
				clampf(1.0 - (p.x - b_min.x) * inv, 0.0, 1.0) - clampf(1.0 - (b_max.x - p.x) * inv, 0.0, 1.0),
				clampf(1.0 - (p.y - b_min.y) * inv, 0.0, 1.0) - clampf(1.0 - (b_max.y - p.y) * inv, 0.0, 1.0))
			acc[slot] += push * weight