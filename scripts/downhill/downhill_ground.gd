extends BoidGround
## Analytic five-degree slope. Voids are deliberately not obstacle-field walls.

const GRADE := 0.0874886635
const HALF_WIDTH := 12.0

func height_at(xz: Vector2) -> float:
	return -xz.y * GRADE

func is_over_ground(xz: Vector2) -> bool:
	return absf(xz.x) <= HALF_WIDTH and xz.y >= -12.0 and xz.y <= 324.0

func normal_at(_xz: Vector2) -> Vector3:
	return Vector3(0, 1, GRADE).normalized()
