class_name BoidInfluenceWander
extends BoidInfluence
## Slow random steering for grazing / idle movement

@export var jitter := 2.0
@export_range(5.0, 180.0) var max_angle_degrees := 60.0


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


class Runtime extends BoidInfluenceRuntime:
	var jitter := 2.0
	var max_angle := 1.0

	func _init(res: BoidInfluenceWander) -> void:
		jitter = res.jitter
		max_angle = deg_to_rad(res.max_angle_degrees)

	func apply(sys: BoidSystem, order: PackedInt32Array, from: int, to: int, weight: float,
			_vmax: float, acc: PackedVector2Array) -> void:
		var st := sys.store
		var scratch := st.scratch
		var hdg := st.heading
		var rng := sys.rng
		var step := 2.0 * jitter * sqrt(sys.cur_dt)
		for k in range(from, to):
			var slot := order[k]
			var ang := clampf(scratch[slot] + (rng.randf() - 0.5) * step, -max_angle, max_angle)
			scratch[slot] = ang
			var h := hdg[slot] + ang
			acc[slot] += Vector2(sin(h), cos(h)) * weight