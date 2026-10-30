class_name BoidGround
extends Resource

@export var flat_height := 0.0


func height_at(_xz: Vector2) -> float:
	return flat_height


func is_over_ground(_xz: Vector2) -> bool:
	return true
