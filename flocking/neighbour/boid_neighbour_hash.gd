class_name BoidNeighbourHash
extends BoidNeighbourStrategy
## 2D (x-z) uniform grid built by counting sort each tick.

const MAX_CELLS := 1 << 16

var origin := Vector2.ZERO
var cell := 1.0
var dim_x := 1
var dim_z := 1

var _count := 0
var _pos := PackedVector2Array()
var _cell_start := PackedInt32Array()
var _cell_cursor := PackedInt32Array()
var _cell_of := PackedInt32Array()
var _items := PackedInt32Array()


func indexed_count() -> int:
	return _count


func rebuild(store: BoidStore, max_query_radius: float) -> void:
	_pos = store.pos
	_count = store.active_count
	var n := _count
	if n == 0:
		dim_x = 1
		dim_z = 1
		_cell_start.resize(2)
		_cell_start.fill(0)
		return
	var mn := _pos[0]
	var mx := _pos[0]
	for i in range(1, n):
		var p := _pos[i]
		mn = mn.min(p)
		mx = mx.max(p)
	var c := maxf(max_query_radius, 0.01)
	var ext := mx - mn
	var cells := (floorf(ext.x / c) + 1.0) * (floorf(ext.y / c) + 1.0)
	if cells > MAX_CELLS:
		c *= sqrt(cells / MAX_CELLS) * 1.02
	cell = c
	origin = mn
	dim_x = int(ext.x / c) + 1
	dim_z = int(ext.y / c) + 1
	var ncells := dim_x * dim_z
	while ncells > MAX_CELLS:
		c *= 1.05
		cell = c
		dim_x = int(ext.x / c) + 1
		dim_z = int(ext.y / c) + 1
		ncells = dim_x * dim_z
	_cell_start.resize(ncells + 1)
	_cell_start.fill(0)
	_cell_cursor.resize(ncells)
	_cell_of.resize(n)
	_items.resize(n)
	var inv := 1.0 / cell
	var dx := dim_x
	var mx_x := dim_x - 1
	var mx_z := dim_z - 1
	for i in n:
		var p := _pos[i]
		var cx := mini(int((p.x - origin.x) * inv), mx_x)
		var cz := mini(int((p.y - origin.y) * inv), mx_z)
		var idx := cz * dx + cx
		_cell_of[i] = idx
		_cell_start[idx + 1] += 1
	for k in ncells:
		_cell_start[k + 1] += _cell_start[k]
		_cell_cursor[k] = _cell_start[k]
	for i in n:
		var idx := _cell_of[i]
		var at := _cell_cursor[idx]
		_items[at] = i
		_cell_cursor[idx] = at + 1


func query(center: Vector2, radius: float, exclude_slot: int, out: PackedInt32Array) -> int:
	var cap := out.size()
	if _count == 0 or cap == 0:
		return 0
	var span := int(ceilf(radius / cell))
	var ccx := int(floorf((center.x - origin.x) / cell))
	var ccz := int(floorf((center.y - origin.y) / cell))
	var x0 := maxi(ccx - span, 0)
	var x1 := mini(ccx + span, dim_x - 1)
	var z0 := maxi(ccz - span, 0)
	var z1 := mini(ccz + span, dim_z - 1)
	if x0 > x1 or z0 > z1:
		return 0
	var r2 := radius * radius
	var n := 0
	for cz in range(z0, z1 + 1):
		var row := cz * dim_x
		var from := _cell_start[row + x0]
		var to := _cell_start[row + x1 + 1]
		for k in range(from, to):
			var s := _items[k]
			if s == exclude_slot:
				continue
			if (_pos[s] - center).length_squared() <= r2:
				out[n] = s
				n += 1
				if n >= cap:
					return n
	return n


## Debug only
func cell_window(center: Vector2, radius: float) -> Rect2i:
	var span := int(ceilf(radius / cell))
	var ccx := int(floorf((center.x - origin.x) / cell))
	var ccz := int(floorf((center.y - origin.y) / cell))
	var x0 := maxi(ccx - span, 0)
	var x1 := mini(ccx + span, dim_x - 1)
	var z0 := maxi(ccz - span, 0)
	var z1 := mini(ccz + span, dim_z - 1)
	if x0 > x1 or z0 > z1:
		return Rect2i()
	return Rect2i(x0, z0, x1 - x0 + 1, z1 - z0 + 1)