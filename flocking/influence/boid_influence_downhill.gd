class_name BoidInfluenceDownhill
extends BoidInfluence
## Velocity-target steering, subordinate to rocks, bark and local flocking.

@export var cruise_speed := 5.0
@export var response := 1.6
@export var lane_gain := 0.04
@export var max_lane_speed := 0.6

func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)

class Runtime extends BoidInfluenceRuntime:
	var source: BoidInfluenceDownhill

	func _init(config: BoidInfluenceDownhill) -> void:
		source = config

	func apply(sys: BoidSystem, order: PackedInt32Array, from: int, to: int,
			weight: float, _vmax: float, acc: PackedVector2Array) -> void:
		for k in range(from, to):
			var slot := order[k]
			var lateral := clampf(-sys.store.pos[slot].x * source.lane_gain,
				-source.max_lane_speed, source.max_lane_speed)
			var target := Vector2(lateral, source.cruise_speed)
			acc[slot] += (target - sys.store.vel[slot]) * source.response * weight
