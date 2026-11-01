class_name BoidInfluenceRuntime
extends RefCounted

## Called once when the behaviour table is built
func setup(_sys: BoidSystem) -> void:
	pass


## Add this influence's contribution, multiplied by `weight`, into `acc` for the boids
func apply(_sys: BoidSystem, _order: PackedInt32Array, _from: int, _to: int, _weight: float,
		_vmax: float, _acc: PackedVector2Array) -> void:
	pass
