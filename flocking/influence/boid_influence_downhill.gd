class_name BoidInfluenceDownhill
extends BoidInfluence
## Velocity-target steering, subordinate to rocks, bark and local flocking.

const Rules = preload("res://scripts/downhill/downhill_rules.gd")
@export var cruise_speed := Rules.CRUISE
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
			var motion = sys.get_meta(&"downhill_motion") if sys.has_meta(&"downhill_motion") else null
			var speed: float = motion.target_speed(sys.store.handle_at(slot)) if motion != null else source.cruise_speed
			var target := Vector2(lateral, speed)
			var steering := (target - sys.store.vel[slot]) * source.response
			var handle := sys.store.handle_at(slot)
			if motion != null and motion.states.has(handle) and motion.states[handle].boost > 0:
				# Punchy forward onset must not suppress lateral flock/bark steering.
				steering.y = (target.y - sys.store.vel[slot].y) * 8.0
			acc[slot] += steering * weight
