class_name BoidHeightfield
extends BoidGround
## Baked height lattice with bilinear lookup 
## Limitation: this is a heightfield, so overhangs and tunnels are not representable.

## World-space ground position (x, z) of the lattice point at index 0.
@export var origin := Vector2.ZERO
## Distance between neighbouring lattice points, in world units.
@export var cell := 1.0
## Number of lattice points along x (not number of cells). Normally set by setup_lattice.
@export var width := 0
## Number of lattice points along z (not number of cells). Normally set by setup_lattice.
@export var depth := 0
## Ground height at each lattice point, stored row by row: index = z * width + x.
## NaN marks a point with no ground. Size should be width * depth.
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
	var lattice_x := (xz.x - origin.x) / cell
	var lattice_z := (xz.y - origin.y) / cell
	var cell_x := clampi(int(floor(lattice_x)), 0, width - 2)
	var cell_z := clampi(int(floor(lattice_z)), 0, depth - 2)
	var fraction_x := clampf(lattice_x - float(cell_x), 0.0, 1.0)
	var fraction_z := clampf(lattice_z - float(cell_z), 0.0, 1.0)
	var corner_index := cell_z * width + cell_x
	var h00 := heights[corner_index]
	var h10 := heights[corner_index + 1]
	var h01 := heights[corner_index + width]
	var h11 := heights[corner_index + width + 1]
	if is_nan(h00) or is_nan(h10) or is_nan(h01) or is_nan(h11):
		var height_sum := 0.0
		var valid_count := 0
		for corner_height in [h00, h10, h01, h11]:
			if not is_nan(corner_height):
				height_sum += corner_height
				valid_count += 1
		return height_sum / valid_count if valid_count > 0 else flat_height
	return lerpf(lerpf(h00, h10, fraction_x), lerpf(h01, h11, fraction_x), fraction_z)


func is_over_ground(ground_position: Vector2) -> bool:
	if width < 2 or depth < 2:
		return false
	var lattice_x := (ground_position.x - origin.x) / cell
	var lattice_z := (ground_position.y - origin.y) / cell
	if lattice_x < 0.0 or lattice_z < 0.0 or lattice_x > float(width - 1) or lattice_z > float(depth - 1):
		return false
	var cell_x := mini(int(floor(lattice_x)), width - 2)
	var cell_y := mini(int(floor(lattice_z)), depth - 2)
	var corner_index := cell_y * width + cell_x
	return not (is_nan(heights[corner_index]) or is_nan(heights[corner_index + 1]) or is_nan(heights[corner_index + width]) or is_nan(heights[corner_index + width + 1]))


func normal_at(ground_position: Vector2) -> Vector3:
	var half_cell := cell * 0.5
	var height_delta_x := height_at(ground_position + Vector2(half_cell, 0.0)) - height_at(ground_position - Vector2(half_cell, 0.0))
	var height_deltz_z := height_at(ground_position + Vector2(0.0, half_cell)) - height_at(ground_position - Vector2(0.0, half_cell))
	return Vector3(-height_delta_x, 2.0 * half_cell, -height_deltz_z).normalized()


func sample_batch(positions: PackedVector2Array, out_heights: PackedFloat32Array, count: int) -> void:
	if width < 2 or depth < 2:
		return
	var inv_cell := 1.0 / cell
	var lattice_width := width
	var max_cell_x := width - 2
	var max_cell_z := depth - 2
	var lattice_heights := heights
	for i in count:
		var position := positions[i]
		var lattice_x := (position.x - origin.x) * inv_cell
		var lattice_z := (position.y - origin.y) * inv_cell
		var cell_x := clampi(int(floor(lattice_x)), 0, max_cell_x)
		var cell_z := clampi(int(floor(lattice_z)), 0, max_cell_z)
		var fraction_x := clampf(lattice_x - float(cell_x), 0.0, 1.0)
		var fraction_z := clampf(lattice_z - float(cell_z), 0.0, 1.0)
		var corner_index := cell_z * lattice_width + cell_x
		var h00 := lattice_heights[corner_index]
		var h10 := lattice_heights[corner_index + 1]
		var h01 := lattice_heights[corner_index + lattice_width]
		var h11 := lattice_heights[corner_index + lattice_width + 1]
		if is_nan(h00) or is_nan(h10) or is_nan(h01) or is_nan(h11):
			continue
		out_heights[i] = lerpf(lerpf(h00, h10, fraction_x), lerpf(h01, h11, fraction_x), fraction_z)
		
		
func sample_normals(positions: PackedVector2Array, out_normals: PackedVector3Array, from_index: int, to_index: int) -> void:
	if width < 2 or depth < 2:
		for i in range(from_index, to_index):
			out_normals[i] = Vector3.UP
		return
	var inverse_cell := 1.0 / cell
	var max_cell_x := width - 2
	var max_cell_z := depth - 2
	var lattice_heights := heights
	for i in range(from_index, to_index):
		var position := positions[i]
		var lattice_x := (position.x - origin.x) * inverse_cell
		var lattice_z := (position.y - origin.y) * inverse_cell
		var cell_x := clampi(int(floor(lattice_x)), 0, max_cell_x)
		var cell_z := clampi(int(floor(lattice_z)), 0, max_cell_z)
		var fraction_x := clampf(lattice_x - float(cell_x), 0.0, 1.0)
		var fraction_z := clampf(lattice_z - float(cell_z), 0.0, 1.0)
		var corner_index := cell_z * width + cell_x
		var height_x0z0 := lattice_heights[corner_index]
		var height_x1z0 := lattice_heights[corner_index + 1]
		var height_x0z1 := lattice_heights[corner_index + width]
		var height_x1z1 := lattice_heights[corner_index + width + 1]
		if is_nan(height_x0z0) or is_nan(height_x1z0) or is_nan(height_x0z1) or is_nan(height_x1z1):
			out_normals[i] = Vector3.UP
			continue
		var slope_x := lerpf(height_x1z0 - height_x0z0, height_x1z1 - height_x0z1, fraction_z) * inverse_cell
		var slope_z := lerpf(height_x0z1 - height_x0z0, height_x1z1 - height_x1z0, fraction_x) * inverse_cell
		var inverse_length := 1.0 / sqrt(slope_x * slope_x + 1.0 + slope_z * slope_z)
		out_normals[i] = Vector3(-slope_x * inverse_length, inverse_length, -slope_z * inverse_length)
