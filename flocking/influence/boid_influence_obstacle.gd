class_name BoidInfluenceObstacle
extends BoidInfluence
## Steers away from baked obstacles (walls, rocks, unwalkable ground). SAFETY layer, so it
## wins the acceleration budget over threats and flocking

@export_range(0.5, 10.0, 0.1, "or_greater") var margin := 3.0
@export var slide := 0.6
@export var brake := 0.25


func _init() -> void:
	layer = Layer.SAFETY


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


class Runtime extends BoidInfluenceRuntime:
	var margin := 3.0
	var slide := 0.6
	var brake := 0.25

	func _init(res: BoidInfluenceObstacle) -> void:
		margin = res.margin
		slide = res.slide
		brake = res.brake

	func apply(sys: BoidSystem, order: PackedInt32Array, from: int, to: int, weight: float,
			_vmax: float, acc: PackedVector2Array) -> void:
		var f := sys.obstacles
		if f == null:
			return
		var pos := sys.store.pos
		var vel := sys.store.vel
		var r := sys.boid_radius
		var m := minf(margin, f.max_dist - r)
		var reach := r + m + f.cell
		var dist := f.dist
		var w := f.width
		var dd := f.depth
		var ox := f.origin.x
		var oz := f.origin.y
		var inv := 1.0 / f.cell
		for k in range(from, to):
			var slot := order[k]
			var p := pos[slot]
			var cx := clampi(int((p.x - ox) * inv), 0, w - 1)
			var cz := clampi(int((p.y - oz) * inv), 0, dd - 1)
			if dist[cz * w + cx] >= reach:
				continue
			var s := f.sample(p)
			var gap := s.x - r
			if gap >= m:
				continue
			var n := Vector2(s.y, s.z)
			if n.length_squared() < 1e-8:
				continue
			var t := 1.0 - maxf(gap, 0.0) / m
			t *= t
			var v := vel[slot]
			var tang := Vector2(-n.y, n.x)
			var side := 1.0 if v.dot(tang) >= 0.0 else -1.0
			acc[slot] += (n * (1.0 + maxf(-v.dot(n), 0.0) * brake) + tang * (side * slide)) * (t * weight)