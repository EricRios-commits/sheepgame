class_name BoidObstacleSource
extends Resource
## Where static obstacles come from (besides hand-authored ones)


func bake_obstacles(_sys: BoidSystem, _field: BoidObstacleField) -> void:
	pass


func needs_physics() -> bool:
	return false