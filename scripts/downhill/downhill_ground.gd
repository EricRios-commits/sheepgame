extends BoidGround
## Analytic five-degree slope. Voids are deliberately not obstacle-field walls.

const GRADE := 0.0874886635
const Rules = preload("res://scripts/downhill/downhill_rules.gd")
const HALF_WIDTH := Rules.HALF_WIDTH

func height_at(xz: Vector2) -> float:
	return Rules.height(xz)

func is_over_ground(xz: Vector2) -> bool:
	return absf(xz.x) <= HALF_WIDTH and xz.y >= -12.0 and xz.y <= 324.0

func normal_at(xz: Vector2) -> Vector3:
	var dx := (height_at(xz + Vector2(0.05, 0)) - height_at(xz - Vector2(0.05, 0))) / 0.1
	var dz := (height_at(xz + Vector2(0, 0.05)) - height_at(xz - Vector2(0, 0.05))) / 0.1
	return Vector3(-dx, 1, -dz).normalized()
