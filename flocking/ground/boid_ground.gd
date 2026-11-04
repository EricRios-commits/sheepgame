class_name BoidGround
extends Resource
## Ground strategy

@export var flat_height := 0.0


func height_at(_xz: Vector2) -> float:
	return flat_height


func is_over_ground(_xz: Vector2) -> bool:
	return true


## Upward unit normal at xz (world space).
func normal_at(_xz: Vector2) -> Vector3:
	return Vector3.UP


## Write height_at(pos[i]) into out[i] for i in [0, n). Positions with no ground keep their
## previous value.
func sample_batch(pos: PackedVector2Array, out: PackedFloat32Array, n: int) -> void:
	for i in n:
		out[i] = height_at(pos[i])

func sample_normals(pos: PackedVector2Array, out: PackedVector3Array, from: int, to: int) -> void:
	for i in range(from, to):
		out[i] = normal_at(pos[i])
