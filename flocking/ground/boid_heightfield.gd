class_name BoidHeightfield
extends BoidGround
## Baked height lattice with bilinear lookup 
## Limitation: this is a heightfield, so overhangs and tunnels are not representable.

@export var origin := Vector2.ZERO
@export var cell := 1.0
@export var width := 0
@export var depth := 0
@export var heights := PackedFloat32Array()

## Sizes the lattice for `bounds` (heights are left unset). Used by the ground sources.
func setup_lattice(bounds: Rect2, cell_size: float) -> void:
	origin = bounds.position
	cell = cell_size
	width = int(ceil(bounds.size.x / cell_size)) + 1
	depth = int(ceil(bounds.size.y / cell_size)) + 1
	heights.resize(width * depth)

func height_at(xz: Vector2) -> float:
	if width < 2 or depth < 2:
		return flat_height
	var fx := (xz.x - origin.x) / cell
	var fz := (xz.y - origin.y) / cell
	var ix := clampi(int(floor(fx)), 0, width - 2)
	var iz := clampi(int(floor(fz)), 0, depth - 2)
	var tx := clampf(fx - float(ix), 0.0, 1.0)
	var tz := clampf(fz - float(iz), 0.0, 1.0)
	var i := iz * width + ix
	var h00 := heights[i]
	var h10 := heights[i + 1]
	var h01 := heights[i + width]
	var h11 := heights[i + width + 1]
	if is_nan(h00) or is_nan(h10) or is_nan(h01) or is_nan(h11):
		var sum := 0.0
		var n := 0
		for h in [h00, h10, h01, h11]:
			if not is_nan(h):
				sum += h
				n += 1
		return sum / n if n > 0 else flat_height
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func is_over_ground(xz: Vector2) -> bool:
	if width < 2 or depth < 2:
		return false
	var fx := (xz.x - origin.x) / cell
	var fz := (xz.y - origin.y) / cell
	if fx < 0.0 or fz < 0.0 or fx > float(width - 1) or fz > float(depth - 1):
		return false
	var ix := mini(int(floor(fx)), width - 2)
	var iz := mini(int(floor(fz)), depth - 2)
	var i := iz * width + ix
	return not (is_nan(heights[i]) or is_nan(heights[i + 1]) or is_nan(heights[i + width]) or is_nan(heights[i + width + 1]))


func normal_at(xz: Vector2) -> Vector3:
	var e := cell * 0.5
	var dx := height_at(xz + Vector2(e, 0.0)) - height_at(xz - Vector2(e, 0.0))
	var dz := height_at(xz + Vector2(0.0, e)) - height_at(xz - Vector2(0.0, e))
	return Vector3(-dx, 2.0 * e, -dz).normalized()


func sample_batch(pos: PackedVector2Array, out: PackedFloat32Array, n: int) -> void:
	if width < 2 or depth < 2:
		return
	var inv := 1.0 / cell
	var w := width
	var wmax := width - 2
	var dmax := depth - 2
	var hs := heights
	for k in n:
		var p := pos[k]
		var fx := (p.x - origin.x) * inv
		var fz := (p.y - origin.y) * inv
		var ix := clampi(int(floor(fx)), 0, wmax)
		var iz := clampi(int(floor(fz)), 0, dmax)
		var tx := clampf(fx - float(ix), 0.0, 1.0)
		var tz := clampf(fz - float(iz), 0.0, 1.0)
		var i := iz * w + ix
		var h00 := hs[i]
		var h10 := hs[i + 1]
		var h01 := hs[i + w]
		var h11 := hs[i + w + 1]
		if is_nan(h00) or is_nan(h10) or is_nan(h01) or is_nan(h11):
			continue
		out[k] = lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)
		
		
func sample_normals(pos: PackedVector2Array, out: PackedVector3Array, from: int, to: int) -> void:
	if width < 2 or depth < 2:
		for i in range(from, to):
			out[i] = Vector3.UP
		return
	var inv := 1.0 / cell
	var wmax := width - 2
	var dmax := depth - 2
	var hs := heights
	for k in range(from, to):
		var p := pos[k]
		var fx := (p.x - origin.x) * inv
		var fz := (p.y - origin.y) * inv
		var ix := clampi(int(floor(fx)), 0, wmax)
		var iz := clampi(int(floor(fz)), 0, dmax)
		var tx := clampf(fx - float(ix), 0.0, 1.0)
		var tz := clampf(fz - float(iz), 0.0, 1.0)
		var i := iz * width + ix
		var h00 := hs[i]
		var h10 := hs[i + 1]
		var h01 := hs[i + width]
		var h11 := hs[i + width + 1]
		if is_nan(h00) or is_nan(h10) or is_nan(h01) or is_nan(h11):
			out[k] = Vector3.UP
			continue
		var dx := lerpf(h10 - h00, h11 - h01, tz) * inv
		var dz := lerpf(h01 - h00, h11 - h10, tx) * inv
		var il := 1.0 / sqrt(dx * dx + 1.0 + dz * dz)
		out[k] = Vector3(-dx * il, il, -dz * il)
