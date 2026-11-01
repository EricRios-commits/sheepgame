class_name BoidObstacleField
extends Resource
## Baked 2D representation of everything boids must not enter

@export var origin := Vector2.ZERO
@export var cell := 0.5
@export var width := 0
@export var depth := 0
@export var max_dist := 5.0
@export var dist := PackedFloat32Array()
@export var normal := PackedVector2Array()


func setup(bounds: Rect2, cell_size: float, max_distance: float) -> void:
	origin = bounds.position
	cell = cell_size
	max_dist = max_distance
	width = int(ceil(bounds.size.x / cell_size))
	depth = int(ceil(bounds.size.y / cell_size))
	dist.resize(width * depth)
	dist.fill(max_dist)
	normal.resize(width * depth)
	normal.fill(Vector2.ZERO)


func add_disc(c: Vector2, r: float) -> void:
	_rasterize(c - Vector2(r, r), c + Vector2(r, r), func(p: Vector2) -> float:
		return p.distance_to(c) - r)


func add_segment(a: Vector2, b: Vector2, half_thickness: float) -> void:
	_rasterize(a.min(b) - Vector2(half_thickness, half_thickness), a.max(b) + Vector2(half_thickness, half_thickness),
			func(p: Vector2) -> float:
				return _segment_distance(p, a, b) - half_thickness)


func add_box(center: Vector2, half: Vector2, axis_x: Vector2, axis_z: Vector2) -> void:
	var ex := absf(axis_x.x) * half.x + absf(axis_z.x) * half.y
	var ez := absf(axis_x.y) * half.x + absf(axis_z.y) * half.y
	_rasterize(center - Vector2(ex, ez), center + Vector2(ex, ez), func(p: Vector2) -> float:
		var d := p - center
		var q := Vector2(absf(d.dot(axis_x)) - half.x, absf(d.dot(axis_z)) - half.y)
		return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0))


## Marks every cell whose centre is off the ground (or steeper than slope_limit_degrees when > 0)
## as unwalkable.
func apply_walkable(ground: BoidGround, slope_limit_degrees: float = 0.0) -> void:
	var n := width * depth
	var unwalk := PackedFloat32Array()
	unwalk.resize(n)
	unwalk.fill(INF)
	var any := false
	var max_tan := tan(deg_to_rad(slope_limit_degrees)) if slope_limit_degrees > 0.0 else INF
	for iz in depth:
		for ix in width:
			var p := origin + (Vector2(ix, iz) + Vector2(0.5, 0.5)) * cell
			var bad := not ground.is_over_ground(p)
			if not bad and slope_limit_degrees > 0.0:
				var ny: float = ground.normal_at(p).y
				bad = sqrt(maxf(1.0 - ny * ny, 0.0)) / maxf(ny, 1e-4) > max_tan
			if bad:
				unwalk[iz * width + ix] = 0.0
				any = true
	if not any:
		return
	_chamfer(unwalk)
	for i in n:
		dist[i] = minf(dist[i], unwalk[i])


func add_blocked_cells(blocked: PackedByteArray) -> void:
	var n := width * depth
	var u := PackedFloat32Array()
	u.resize(n)
	u.fill(INF)
	for i in n:
		if blocked[i] != 0:
			u[i] = 0.0
	_chamfer(u)
	for i in n:
		dist[i] = minf(dist[i], u[i])


func _chamfer(u: PackedFloat32Array) -> void:
	var c1 := cell
	var c2 := cell * 1.41421356
	var w := width
	for iz in depth:
		for ix in w:
			var i := iz * w + ix
			var v := u[i]
			if ix > 0:
				v = minf(v, u[i - 1] + c1)
			if iz > 0:
				v = minf(v, u[i - w] + c1)
				if ix > 0:
					v = minf(v, u[i - w - 1] + c2)
				if ix < w - 1:
					v = minf(v, u[i - w + 1] + c2)
			u[i] = v
	for iz in range(depth - 1, -1, -1):
		for ix in range(w - 1, -1, -1):
			var i := iz * w + ix
			var v := u[i]
			if ix < w - 1:
				v = minf(v, u[i + 1] + c1)
			if iz < depth - 1:
				v = minf(v, u[i + w] + c1)
				if ix < w - 1:
					v = minf(v, u[i + w + 1] + c2)
				if ix > 0:
					v = minf(v, u[i + w - 1] + c2)
			u[i] = v


## Call once after all shapes are added.
func compute_normals() -> void:
	var w := width
	for iz in depth:
		for ix in w:
			var i := iz * w + ix
			if dist[i] >= max_dist:
				continue
			var xl := dist[i - 1] if ix > 0 else dist[i]
			var xr := dist[i + 1] if ix < w - 1 else dist[i]
			var zl := dist[i - w] if iz > 0 else dist[i]
			var zr := dist[i + w] if iz < depth - 1 else dist[i]
			var g := Vector2(xr - xl, zr - zl)
			if g.length_squared() > 1e-10:
				normal[i] = g.normalized()


## x = distance to the nearest obstacle surface (clamped to max_dist), (y, z) = unit normal
## pointing away from it
func sample(p: Vector2) -> Vector3:
	var inv := 1.0 / cell
	var fx := (p.x - origin.x) * inv - 0.5
	var fz := (p.y - origin.y) * inv - 0.5
	if fx < -1.0 or fz < -1.0 or fx > float(width) or fz > float(depth):
		return Vector3(max_dist, 0.0, 0.0)
	var ix := clampi(int(floor(fx)), 0, width - 2)
	var iz := clampi(int(floor(fz)), 0, depth - 2)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)
	var i := iz * width + ix
	var d := lerpf(lerpf(dist[i], dist[i + 1], tx), lerpf(dist[i + width], dist[i + width + 1], tx), tz)
	var n := normal[i].lerp(normal[i + 1], tx).lerp(normal[i + width].lerp(normal[i + width + 1], tx), tz)
	var l := n.length()
	if l > 1e-6:
		n /= l
	return Vector3(d, n.x, n.y)


func _rasterize(lo: Vector2, hi: Vector2, f: Callable) -> void:
	var inv := 1.0 / cell
	var x0 := clampi(int(floor((lo.x - max_dist - origin.x) * inv)), 0, width - 1)
	var x1 := clampi(int(ceil((hi.x + max_dist - origin.x) * inv)), 0, width - 1)
	var z0 := clampi(int(floor((lo.y - max_dist - origin.y) * inv)), 0, depth - 1)
	var z1 := clampi(int(ceil((hi.y + max_dist - origin.y) * inv)), 0, depth - 1)
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var p := origin + (Vector2(ix, iz) + Vector2(0.5, 0.5)) * cell
			var d: float = f.call(p)
			var i := iz * width + ix
			if d < dist[i]:
				dist[i] = d


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-12:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
